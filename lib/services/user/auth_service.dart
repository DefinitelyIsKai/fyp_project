import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService extends WidgetsBindingObserver {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance {
    // Register as observer for app lifecycle changes
    WidgetsBinding.instance.addObserver(this);
  }

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // Session management
  String? _localSessionToken;
  StreamSubscription<DocumentSnapshot>? _sessionListener;
  bool _isAppActive = true;
  bool _isListening = false;

  // Get local session token
  String? get localSessionToken => _localSessionToken;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    _isAppActive = state == AppLifecycleState.resumed;
    
    if (!_isAppActive) {
      // App went to background or was paused
      _updateLastActive();
    }
  }

  // Update lastActive timestamp when app goes to background/crashes
  Future<void> _updateLastActive() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null || userId.isEmpty) return;

      debugPrint('AuthService: Updating lastActive for user $userId');
      
      final callable = _functions.httpsCallable('updateLastActive');
      await callable.call();
      
      debugPrint('AuthService: Successfully updated lastActive');
    } catch (e) {
      debugPrint('AuthService: Error updating lastActive: $e');
    }
  }

  // Load session token from local storage
  Future<void> _loadSessionToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _localSessionToken = prefs.getString('sessionToken');
      debugPrint('AuthService: Loaded session token from local storage');
    } catch (e) {
      debugPrint('AuthService: Error loading session token: $e');
    }
  }

  // Save session token to local storage
  Future<void> _saveSessionToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('sessionToken', token);
      _localSessionToken = token;
      debugPrint('AuthService: Saved session token to local storage');
    } catch (e) {
      debugPrint('AuthService: Error saving session token: $e');
    }
  }

  // Clear session token from local storage
  Future<void> _clearSessionToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('sessionToken');
      _localSessionToken = null;
      debugPrint('AuthService: Cleared session token from local storage');
    } catch (e) {
      debugPrint('AuthService: Error clearing session token: $e');
    }
  }

  // Start real-time listener on user's session document
  void _startSessionListener(String userId) {
    if (_isListening) {
      debugPrint('AuthService: Session listener already active');
      return;
    }

    debugPrint('AuthService: Starting real-time listener on session document for user $userId');
    
    _sessionListener = _firestore
        .collection('sessions')
        .doc(userId)
        .snapshots()
        .listen(
      (DocumentSnapshot snapshot) {
        if (!snapshot.exists) {
          debugPrint('AuthService: Session document deleted, forcing logout');
          _handleForceLogout();
          return;
        }

        final sessionData = snapshot.data() as Map<String, dynamic>?;
        if (sessionData == null) {
          debugPrint('AuthService: Session data is null, forcing logout');
          _handleForceLogout();
          return;
        }

        final firestoreToken = sessionData['sessionToken'] as String?;
        
        if (firestoreToken == null) {
          debugPrint('AuthService: No session token in Firestore, forcing logout');
          _handleForceLogout();
          return;
        }

        // Check for token mismatch (multi-device login detected)
        if (_localSessionToken != null && firestoreToken != _localSessionToken) {
          debugPrint('AuthService: Token mismatch detected! Local: ${_localSessionToken?.substring(0, 8)}..., Firestore: ${firestoreToken.substring(0, 8)}...');
          debugPrint('AuthService: Another device logged in, forcing logout');
          _handleForceLogout();
          return;
        }

        // If app is active, listener stays active and checks for token mismatch
        if (_isAppActive) {
          debugPrint('AuthService: App is active, listener checking for token mismatch');
          // Token matches, session is valid
        } else {
          debugPrint('AuthService: App is not active, listener will continue monitoring');
        }
      },
      onError: (error) {
        debugPrint('AuthService: Error in session listener: $error');
      },
    );

    _isListening = true;
  }

  // Stop session listener
  void _stopSessionListener() {
    if (_sessionListener != null) {
      debugPrint('AuthService: Stopping session listener');
      _sessionListener?.cancel();
      _sessionListener = null;
      _isListening = false;
    }
  }

  // Handle force logout when token mismatch is detected
  Future<void> _handleForceLogout() async {
    debugPrint('AuthService: Handling force logout due to token mismatch');
    
    _stopSessionListener();
    await _clearSessionToken();
    
    // Sign out from Firebase Auth
    try {
      await _auth.signOut();
      debugPrint('AuthService: Force logout completed');
    } catch (e) {
      debugPrint('AuthService: Error during force logout: $e');
    }
  }

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

  // New login function following the flowchart
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim();
    
    debugPrint('AuthService: Starting login process for $trimmedEmail');
    
    // Step 1: Authenticate with Firebase Auth
    final credential = await _auth.signInWithEmailAndPassword(
      email: trimmedEmail,
      password: password,
    );

    if (credential.user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'Authentication failed',
      );
    }

    final userId = credential.user!.uid;
    debugPrint('AuthService: Firebase Auth successful for user $userId');

    // Step 2: Call Cloud Function to generate session token and update Firestore
    try {
      debugPrint('AuthService: Calling userLogin Cloud Function');
      final callable = _functions.httpsCallable('userLogin');
      final result = await callable.call();
      
      final data = result.data as Map<String, dynamic>?;
      if (data == null || data['success'] != true) {
        throw Exception('Login failed: ${data?['message'] ?? 'Unknown error'}');
      }

      final sessionToken = data['sessionToken'] as String?;
      if (sessionToken == null || sessionToken.isEmpty) {
        throw Exception('No session token received');
      }

      debugPrint('AuthService: Session token generated successfully');

      // Step 3: Store token locally
      await _saveSessionToken(sessionToken);
      debugPrint('AuthService: Session token stored locally');

      // Step 4: Start real-time listener on user's session document
      _startSessionListener(userId);
      debugPrint('AuthService: Real-time listener started');

      // Update email verification status
      await credential.user!.reload();
      final isVerified = credential.user!.emailVerified;
      try {
        await _firestore.collection('users').doc(userId).update({
          'emailVerified': isVerified,
        });
      } catch (e) {
        debugPrint('AuthService: Error updating email verification status: $e');
      }

      debugPrint('AuthService: Login process completed successfully');
      return credential;
    } catch (e) {
      debugPrint('AuthService: Error during login process: $e');
      // Sign out if Cloud Function call failed
      await _auth.signOut();
      rethrow;
    }
  }

  Future<void> signOut() async {
    final userId = _auth.currentUser?.uid;
    
    debugPrint('AuthService: Starting sign out process for user $userId');

    // Stop session listener
    _stopSessionListener();

    // Clear local session token
    await _clearSessionToken();

    // Call Cloud Function to clear session
    if (userId != null && userId.isNotEmpty) {
      try {
        debugPrint('AuthService: Calling userLogout Cloud Function');
        final callable = _functions.httpsCallable('userLogout');
        await callable.call();
        debugPrint('AuthService: Session cleared in Firestore');
      } catch (e) {
        debugPrint('AuthService: Error calling userLogout: $e');
        // Still try to update user document directly as fallback
        try {
          await _firestore.collection('users').doc(userId).update({
            'login': false,
          });
        } catch (e2) {
          debugPrint('AuthService: Error updating user document: $e2');
        }
      }
    }

    // Sign out from Firebase Auth
    await _auth.signOut();
    debugPrint('AuthService: Sign out completed');
  }

  // Initialize session listener if user is already logged in
  Future<void> initializeSession() async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('AuthService: No current user, skipping session initialization');
      return;
    }

    await _loadSessionToken();
    
    if (_localSessionToken != null && _localSessionToken!.isNotEmpty) {
      debugPrint('AuthService: Found existing session token, starting listener');
      _startSessionListener(user.uid);
    } else {
      debugPrint('AuthService: No existing session token found');
    }
  }

  // Cleanup when service is disposed
  void dispose() {
    _stopSessionListener();
    WidgetsBinding.instance.removeObserver(this);
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
        // Ignore error
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

  // DEPRECATED: Login status is now managed by session tokens
  // This method is kept for backward compatibility but should not be used
  @Deprecated('Login status is now managed by session tokens in sessions collection')
  Future<void> setLoginStatus(bool isLoggedIn) async {
    // No-op: Login status is managed by session tokens
    debugPrint('setLoginStatus: DEPRECATED - Login status is now managed by session tokens');
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
