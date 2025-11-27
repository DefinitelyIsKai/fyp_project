import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
      'email': userEmail, // Email from authentication
      'createdAt': FieldValue.serverTimestamp(), // Account creation timestamp
      'emailVerified': false, // Track email verification status in Firestore
      // Used to gate first-time profile setup flow
      'profileCompleted': false,
      // Default role for new users
      'role': 'jobseeker',
      // Account status fields - auto created
      'status': 'Active', // Options: Active, Suspend, Inactive
      'isActive': true, // Boolean flag for active status
      // Optional fields for the onboarding flow. They may be filled later.
      'phoneNumber': null,
      'location': null,
      'professionalProfile': null,
      'professionalSummary': null,
      'workExperience': null,
    });

    // Send verification email
    await credential.user!.sendEmailVerification();

    return credential;
  }

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    
    // Sync emailVerified status to Firestore after sign in
    if (credential.user != null) {
      await credential.user!.reload();
      final isVerified = credential.user!.emailVerified;
      try {
        await _firestore.collection('users').doc(credential.user!.uid).update({
          'emailVerified': isVerified,
        });
      } catch (e) {
        // Ignore errors - this is a sync operation, shouldn't block login
      }
    }
    
    return credential;
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> resendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  /// Check if email exists by querying Firestore.
  /// Note: fetchSignInMethodsForEmail was removed in Firebase Auth 6.x due to
  /// Email Enumeration Protection. We use Firestore as an alternative.
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
      // If Firestore query fails, return false to be safe
      return false;
    }
  }

  /// Checks if password reset should be allowed for the given email.
  /// Returns true if allowed, false if the account exists but is unverified.
  /// Throws if email doesn't exist.
  Future<bool> canSendPasswordReset(String email) async {
    final trimmedEmail = email.trim();
    
    // Check if email exists
    final exists = await doesEmailExist(trimmedEmail);
    if (!exists) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No account found with this email.',
      );
    }

    // Try to find user document in Firestore to check verification status
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: trimmedEmail)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final userData = querySnapshot.docs.first.data();
        
        // Check if emailVerified status is stored in Firestore
        final emailVerified = userData['emailVerified'];
        if (emailVerified != null) {
          // If explicitly set to false, block password reset
          if (emailVerified == false) {
            return false;
          }
          // If explicitly set to true, allow password reset
          if (emailVerified == true) {
            return true;
          }
        }
        
        // Fallback: Check account age for new accounts
        // For accounts less than 24 hours old without verification status, assume unverified
        final createdAt = userData['createdAt'] as Timestamp?;
        if (createdAt != null) {
          final accountAge = DateTime.now().difference(createdAt.toDate());
          if (accountAge.inHours < 24) {
            return false; // Likely unverified, block password reset
          }
        }
      }
    } catch (e) {
      // If we can't check, allow the reset (fail open for existing accounts)
      // This prevents blocking legitimate password resets
    }

    return true;
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    // Check if password reset should be allowed
    final canReset = await canSendPasswordReset(email);
    if (!canReset) {
      throw FirebaseAuthException(
        code: 'email-not-verified',
        message: 'Please verify your email before resetting your password. Check your inbox for the verification email.',
      );
    }
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<bool> refreshAndCheckEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    
    try {
      await user.reload();
    } on FirebaseAuthException catch (e) {
      // Handle network errors gracefully - don't crash the app
      // Return false so polling can continue when network is restored
      if (e.code == 'network-request-failed') {
        return false;
      }
      // Re-throw other auth exceptions
      rethrow;
    } catch (e) {
      // Handle any other unexpected errors
      return false;
    }
    
    final isVerified = _auth.currentUser?.emailVerified ?? false;
    
    // Sync emailVerified status to Firestore
    if (isVerified && user.uid.isNotEmpty) {
      try {
        await _firestore.collection('users').doc(user.uid).update({
          'emailVerified': true,
        });
      } catch (e) {
        // Ignore errors - this is a sync operation
      }
    }
    
    return isVerified;
  }

  // Returns current user id or throws if not signed in
  String get currentUserId {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user');
    }
    return user.uid;
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getUserDoc() async {
    // Force a server read to avoid stale cached values after console edits
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
      // Tolerate string values set manually in the console
      return raw.toLowerCase() == 'true';
    }
    return false;
  }

  Future<void> updateUserProfile(Map<String, dynamic> data) async {
    // Remove createdAt to prevent overwriting the original account creation timestamp
    final dataToUpdate = Map<String, dynamic>.from(data);
    dataToUpdate.remove('createdAt');
    await _firestore.collection('users').doc(currentUserId).set(dataToUpdate, SetOptions(merge: true));
  }
}



