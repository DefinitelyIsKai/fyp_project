import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Future<UserCredential> registerUser({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final uid = credential.user!.uid;
    final userEmail = credential.user!.email ?? email.trim();
    await _firestore.collection('users').doc(uid).set({
      'fullName': fullName.trim(),
      'email': userEmail, 
      'createdAt': FieldValue.serverTimestamp(), 
      'emailVerified': false, 
      'profileCompleted': false,
      'role': 'jobseeker',
      'status': 'Active',
      'isActive': true, 
      'login': false, 
      'phoneNumber': null,
      'location': null,
      'professionalProfile': null,
      'professionalSummary': null,
      'workExperience': null,
    });

    await credential.user!.sendEmailVerification();

    return credential;
  }

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim();
    
    final credential = await _auth.signInWithEmailAndPassword(
      email: trimmedEmail,
      password: password,
    );
    
    //check if user is already logged in on another device
    if (credential.user != null) {
      try {
        final userId = credential.user!.uid;
        final userDoc = await _firestore.collection('users').doc(userId).get();
        
        if (userDoc.exists) {
          final userData = userDoc.data();
          final loginValue = userData?['login'];
          
          bool isLoggedIn = false;
          if (loginValue is bool) {
            isLoggedIn = loginValue;
          } else if (loginValue == null) {
            isLoggedIn = false;
            debugPrint('Login check: login field is null, treating as false');
          } else if (loginValue is String) {
            isLoggedIn = loginValue.toLowerCase() == 'true';
            debugPrint('Login check: login field is string "$loginValue", converted to $isLoggedIn');
          } else {
            debugPrint('Login check: login field is unexpected type: ${loginValue.runtimeType}, value=$loginValue');
          }
          
          debugPrint('Login check: userId=$userId, login field=$loginValue (type: ${loginValue.runtimeType}), isLoggedIn=$isLoggedIn');
          
          if (isLoggedIn == true) {
            debugPrint('BLOCKING LOGIN: User is already logged in on another device (login=$loginValue)');
            await _auth.signOut(); 
            throw FirebaseAuthException(
              code: 'already-logged-in',
              message: 'This account is already logged in on another device. Please logout from the other device first.',
            );
          } else {
            debugPrint('Login check: User is not logged in (login=$loginValue), allowing login');
          }
        } else {
          debugPrint('Login check: User document not found for userId=$userId');
        }
      } on FirebaseAuthException {
        debugPrint('Login check: Re-throwing FirebaseAuthException');
        rethrow;
      } catch (e) {
        debugPrint('Warning: Could not check login status: $e');
        debugPrint('Warning: Proceeding with login despite check failure');
      }
    }
    
    if (credential.user != null) {
      await credential.user!.reload();
      final isVerified = credential.user!.emailVerified;
      try {
        await _firestore.collection('users').doc(credential.user!.uid).update({
          'emailVerified': isVerified,
        });
      } catch (e) {
      }
    }
    
    return credential;
  }

  Future<void> signOut() async {
    //check user id before signing out
    final userId = _auth.currentUser?.uid;
    
    debugPrint('SignOut: userId=$userId');
    
 
    if (userId != null && userId.isNotEmpty) {
      try {
        await _firestore.collection('users').doc(userId).update({
          'login': false, 
        });
        debugPrint('SignOut: Successfully set login=false for userId=$userId');
      } catch (e) {
        debugPrint('Error updating login status during signOut: $e');
      }
    } else {
      debugPrint('SignOut: No userId found, skipping login status update');
    }
    
    //ssign out firebase Auth
    await _auth.signOut();
    debugPrint('SignOut: Firebase Auth signOut completed');
  }

  Future<void> resendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }


  Future<bool> doesEmailExist(String email) async {
    final trimmedEmail = email.trim();
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: trimmedEmail)
          .limit(1)
          .get();
      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }


  Future<Map<String, dynamic>> checkEmailStatus(String email) async {
    final trimmedEmail = email.trim();
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: trimmedEmail)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isEmpty) {
        return {'exists': false, 'verified': false};
      }
      
      final userData = querySnapshot.docs.first.data();
      final emailVerified = userData['emailVerified'] ?? false;
      
      return {
        'exists': true,
        'verified': emailVerified is bool ? emailVerified : (emailVerified.toString().toLowerCase() == 'true'),
        'userId': querySnapshot.docs.first.id,
      };
    } catch (e) {
      return {'exists': false, 'verified': false};
    }
  }


  Future<bool> isEmailVerified(String email) async {
    try {
      final status = await checkEmailStatus(email);
      return status['exists'] == true && status['verified'] == true;
    } catch (e) {
      debugPrint('Error checking email verification: $e');
      return false;
    }
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    final trimmedEmail = email.trim();
    
    try {
      final status = await checkEmailStatus(trimmedEmail);
      
      if (status['exists'] == false) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'No account found with this email address.',
        );
      }
      
      if (status['verified'] == false) {
        throw FirebaseAuthException(
          code: 'email-not-verified',
          message: 'Please verify your email before resetting your password. Check your inbox for the verification email.',
        );
      }
      

      await _auth.sendPasswordResetEmail(email: trimmedEmail);
    } catch (e) {

      if (e is FirebaseAuthException && 
          (e.code == 'user-not-found' || e.code == 'email-not-verified')) {
        rethrow;
      }
      
      debugPrint('Firestore check failed, falling back to direct reset: $e');
      await _auth.sendPasswordResetEmail(email: trimmedEmail);
    }
  }

  Future<bool> refreshAndCheckEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    
    try {
      await user.reload();
    } on FirebaseAuthException catch (e) {

      if (e.code == 'network-request-failed') {
        return false;
      }

      rethrow;
    } catch (e) {
      return false;
    }
    
    final isVerified = _auth.currentUser?.emailVerified ?? false;
    

    if (isVerified && user.uid.isNotEmpty) {
      try {
        await _firestore.collection('users').doc(user.uid).update({
          'emailVerified': true,
        });
      } catch (e) {
       
      }
    }
    
    return isVerified;
  }


  String get currentUserId {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user');
    }
    return user.uid;
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getUserDoc() async {
    return _firestore
        .collection('users')
        .doc(currentUserId)
        .get(const GetOptions(source: Source.server));
  }

  Future<bool> isProfileCompleted() async {
    final doc = await getUserDoc();
    final data = doc.data();
    if (data == null) return false;
    final dynamic raw = data['profileCompleted'];
    if (raw is bool) return raw;
    if (raw is String) {
      return raw.toLowerCase() == 'true';
    }
    return false;
  }

  //set login status 
  Future<void> setLoginStatus(bool isLoggedIn) async {
    try {
      final userId = currentUserId;
      if (userId.isEmpty) {
        debugPrint('setLoginStatus: ERROR - currentUserId is empty!');
        throw Exception('Cannot set login status: user ID is empty');
      }
      debugPrint('setLoginStatus: userId=$userId, isLoggedIn=$isLoggedIn');
      await _firestore.collection('users').doc(userId).update({
        'login': isLoggedIn,
      });
      debugPrint('setLoginStatus: Successfully updated login status to $isLoggedIn for user $userId');
    } catch (e) {
     
      debugPrint('Error setting login status: $e');
      rethrow;
    }
  }

  Future<void> updateUserProfile(Map<String, dynamic> data) async {
    //prevent overwriting 
    final dataToUpdate = Map<String, dynamic>.from(data);
    dataToUpdate.remove('createdAt');
    
    //clean up
    if (dataToUpdate['resume'] is Map) {
      final resumeData = Map<String, dynamic>.from(dataToUpdate['resume'] as Map);
      resumeData.remove('base64');
      if (resumeData.containsKey('downloadUrl') && resumeData['downloadUrl'] != null) {
        dataToUpdate['resume'] = resumeData;
      } else if (resumeData.isEmpty || (resumeData.length == 1 && resumeData.containsKey('uploadedAt'))) {
        dataToUpdate.remove('resume');
      } else {
        dataToUpdate['resume'] = resumeData;
      }
    }
    
    if (dataToUpdate['image'] is Map) {
      final imageData = Map<String, dynamic>.from(dataToUpdate['image'] as Map);
      imageData.remove('base64');
      if (imageData.containsKey('downloadUrl') && imageData['downloadUrl'] != null) {
        dataToUpdate['image'] = imageData;
      } else if (imageData.isEmpty || (imageData.length == 1 && imageData.containsKey('uploadedAt'))) {
        dataToUpdate.remove('image');
      } else {
        dataToUpdate['image'] = imageData;
      }
    }
    
    await _firestore.collection('users').doc(currentUserId).set(dataToUpdate, SetOptions(merge: true));
  }
}



