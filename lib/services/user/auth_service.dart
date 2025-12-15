import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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

  Future<void> updateUserProfile(Map<String, dynamic> data) async {
    final dataToUpdate = Map<String, dynamic>.from(data);
    dataToUpdate.remove('createdAt');

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



