import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../firebase_options.dart';
import 'firestore_service.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;

  /// True when firebase_options.dart contains real values.
  static bool get isFirebaseConfigured => !_hasPlaceholderConfig();

  /// Currently signed-in Firebase user (null if logged out).
  static User? get currentUser => _auth.currentUser;

  /// Stream of auth state changes.
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ─── Sign Up ──────────────────────────────────────────────────────────────

  /// Creates a new user with [email] and [password], then saves the profile to
  /// Firestore.
  static Future<UserCredential> signUp({
    required String name,
    required String email,
    required String password,
    String role = 'patient',
    String phone = '',
    String age = '',
    String gender = '',
  }) async {
    _ensureFirebaseConfigured();
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Update Firebase display name
    await cred.user!.updateDisplayName(name);

    // Store extended profile in Firestore users collection
    await FirestoreService.saveUserProfile(
      uid: cred.user!.uid,
      name: name,
      email: email,
      role: role,
      phone: phone,
      age: age,
      gender: gender,
    );

    return cred;
  }

  // ─── Login ────────────────────────────────────────────────────────────────

  static Future<UserCredential> login({
    required String email,
    required String password,
    String? expectedRole,
  }) async {
    _ensureFirebaseConfigured();
    final cred =
        await _auth.signInWithEmailAndPassword(email: email, password: password);
    if (expectedRole != null) {
      final role = await FirestoreService.getCurrentUserRole();
      if (role != expectedRole) {
        await _auth.signOut();
        throw FirebaseAuthException(
          code: 'role-mismatch',
          message: 'This account is not registered as a $expectedRole.',
        );
      }
    }
    return cred;
  }

  static Future<UserCredential> signUpDoctor({
    required String name,
    required String email,
    required String password,
    required String specialty,
    String qualification = '',
    String hospital = '',
    String location = '',
    String phone = '',
    String bio = '',
  }) async {
    _ensureFirebaseConfigured();
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    await cred.user!.updateDisplayName(name);

    await FirestoreService.saveUserProfile(
      uid: cred.user!.uid,
      name: name,
      email: email,
      role: 'doctor',
      phone: phone,
    );

    await FirestoreService.saveDoctorProfile(
      uid: cred.user!.uid,
      name: name,
      email: email,
      specialty: specialty,
      qualification: qualification,
      hospital: hospital,
      location: location,
      phone: phone,
      bio: bio,
    );

    return cred;
  }

  /// One-tap demo login for QA/preview flow.
  ///
  /// Behavior:
  /// 1) Try to sign in with a fixed demo account
  /// 2) If account doesn't exist, create it
  /// 3) Ensure demo profile exists in Firestore
  static Future<UserCredential> loginWithDemoAccount() async {
    _ensureFirebaseConfigured();
    const demoName = 'Demo User';
    const demoEmail = 'demo.user@smartmind.app';
    const demoPassword = 'Demo@123456';

    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: demoEmail,
        password: demoPassword,
      );
      await _saveProfileIfNeeded(cred.user, fallbackName: demoName);
      return cred;
    } on FirebaseAuthException catch (e) {
      if (e.code != 'user-not-found') rethrow;

      final cred = await _auth.createUserWithEmailAndPassword(
        email: demoEmail,
        password: demoPassword,
      );
      await cred.user?.updateDisplayName(demoName);
      await FirestoreService.saveUserProfile(
        uid: cred.user!.uid,
        name: demoName,
        email: demoEmail,
        phone: '+1 000-000-0000',
        age: '27',
        gender: 'Prefer not to say',
      );
      return cred;
    }
  }

  static Future<UserCredential> signInWithGoogle() async {
    _ensureFirebaseConfigured();
    if (kIsWeb) {
      final userCred = await _auth.signInWithPopup(GoogleAuthProvider());
      await _saveProfileIfNeeded(userCred.user);
      return userCred;
    }

    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      throw FirebaseAuthException(
        code: 'google-signin-unsupported-platform',
        message: 'Google sign-in is supported on Android, iOS, and Web.',
      );
    }

    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      throw FirebaseAuthException(
        code: 'google-signin-cancelled',
        message: 'Google sign-in was cancelled.',
      );
    }

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCred = await _auth.signInWithCredential(credential);
    await _saveProfileIfNeeded(userCred.user);
    return userCred;
  }

  static Future<UserCredential> signInWithFacebook() async {
    _ensureFirebaseConfigured();
    if (kIsWeb) {
      final userCred = await _auth.signInWithPopup(FacebookAuthProvider());
      await _saveProfileIfNeeded(userCred.user);
      return userCred;
    }

    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      throw FirebaseAuthException(
        code: 'facebook-signin-unsupported-platform',
        message: 'Facebook sign-in is supported on Android, iOS, and Web.',
      );
    }

    final result = await FacebookAuth.instance.login();
    if (result.status != LoginStatus.success || result.accessToken == null) {
      throw FirebaseAuthException(
        code: 'facebook-signin-failed',
        message: result.message ?? 'Facebook sign-in failed.',
      );
    }

    final credential = FacebookAuthProvider.credential(
      result.accessToken!.tokenString,
    );
    final userCred = await _auth.signInWithCredential(credential);
    await _saveProfileIfNeeded(userCred.user);
    return userCred;
  }

  static Future<UserCredential> signInWithApple() async {
    _ensureFirebaseConfigured();
    
    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.macOS &&
        !kIsWeb) {
      throw FirebaseAuthException(
        code: 'apple-signin-unsupported-platform',
        message: 'Apple sign-in is supported on iOS, macOS, and Web.',
      );
    }

    try {
      // Request Apple Sign-In credential
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      // Use the credential to sign in with Firebase
      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: credential.identityToken,
        accessToken: credential.authorizationCode,
      );

      final userCred = await _auth.signInWithCredential(oauthCredential);
      
      // Update user display name if available (first sign-in only)
      if (userCred.user?.displayName == null && credential.givenName != null) {
        final fullName =
            '${credential.givenName ?? ''} ${credential.familyName ?? ''}'
                .trim();
        if (fullName.isNotEmpty) {
          await userCred.user?.updateDisplayName(fullName);
        }
      }

      await _saveProfileIfNeeded(
        userCred.user,
        fallbackName: credential.givenName ?? 'User',
      );
      
      return userCred;
    } catch (e) {
      // Handle user-cancelled or other errors
      if (e.toString().contains('PlatformException')) {
        throw FirebaseAuthException(
          code: 'apple-signin-cancelled',
          message: 'Apple sign-in was cancelled by user.',
        );
      }
      throw FirebaseAuthException(
        code: 'apple-signin-failed',
        message: 'Apple sign-in failed: ${e.toString()}',
      );
    }
  }

  static Future<void> _saveProfileIfNeeded(
    User? user, {
    String fallbackName = 'User',
  }) async {
    if (user == null) return;
    await FirestoreService.saveUserProfile(
      uid: user.uid,
      name: user.displayName ?? fallbackName,
      email: user.email ?? '',
      photoUrl: user.photoURL ?? '',
    );
  }

  // ─── Logout ───────────────────────────────────────────────────────────────

  static Future<void> logout() async => _auth.signOut();

  // ─── Password Reset ───────────────────────────────────────────────────────

  static Future<void> sendPasswordReset(String email) async {
    _ensureFirebaseConfigured();
    return _auth.sendPasswordResetEmail(email: email);
  }

  static void _ensureFirebaseConfigured() {
    if (_hasPlaceholderConfig()) {
      throw FirebaseAuthException(
        code: 'firebase-not-configured',
        message:
            'Firebase is not configured. Replace placeholder values in lib/firebase_options.dart (or run flutterfire configure).',
      );
    }
  }

  static bool _hasPlaceholderConfig() {
    final options = DefaultFirebaseOptions.currentPlatform;
    final badApiKey =
        options.apiKey.isEmpty || options.apiKey.startsWith('YOUR_');
    final badProjectId =
        options.projectId.isEmpty || options.projectId.startsWith('YOUR_');
    final badAppId =
        options.appId.isEmpty || options.appId.startsWith('YOUR_');
    // On Web, allow auth attempts even if appId is still placeholder.
    // Some projects only have Android/iOS configs initially.
    // Keep strict checks for API key and project ID.
    if (kIsWeb) {
      return badApiKey || badProjectId;
    }
    return badApiKey || badProjectId || badAppId;
  }
}
