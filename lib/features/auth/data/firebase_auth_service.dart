import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FirebaseAuthService {
  FirebaseAuthService(this._auth);

  final FirebaseAuth _auth;

  Stream<User?> get userChanges => _auth.userChanges();

  Future<void> signInWithGoogle() async {
    final provider = GoogleAuthProvider()
      ..setCustomParameters({'prompt': 'select_account'});
    if (kIsWeb) {
      await _auth.signInWithPopup(provider);
    } else {
      await _auth.signInWithProvider(provider);
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> register({
    required String displayName,
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await credential.user?.updateDisplayName(displayName.trim());
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  Future<void> reloadCurrentUser() async {
    await _auth.currentUser?.reload();
  }

  Future<void> signOut() => _auth.signOut();
}

String authenticationErrorMessage(FirebaseAuthException error) {
  return switch (error.code) {
    'invalid-email' => 'Enter a valid email address.',
    'user-not-found' =>
      'No account exists for this email. Tap "New here? Create an account" '
          'below, or use "Continue with Google".',
    'wrong-password' ||
    'invalid-credential' =>
      'The email or password is incorrect. If you haven’t created an '
          'account yet or usually sign in with Google, tap '
          '"New here? Create an account" or "Continue with Google".',
    'email-already-in-use' => 'An account already exists for this email.',
    'weak-password' => 'Choose a stronger password with at least 8 characters.',
    'too-many-requests' => 'Too many attempts. Please wait and try again.',
    'network-request-failed' =>
      'Could not connect. Check your internet connection and try again.',
    'user-disabled' => 'This account has been disabled.',
    'popup-blocked' =>
      'Sign-in popup was blocked by your browser. Allow popups and try again.',
    'popup-closed-by-user' ||
    'cancelled-popup-request' =>
      'Google sign-in was cancelled before completion.',
    'unauthorized-domain' => kIsWeb && Uri.base.host.isNotEmpty
        ? 'This domain (${Uri.base.host}) is not authorized in Firebase '
            'Authentication settings. Add it under Authentication → Settings '
            '→ Authorized domains in Firebase Console.'
        : 'This domain is not authorized in Firebase Authentication settings.',
    'operation-not-allowed' =>
      'Email and password sign-in is not enabled yet in Firebase Console. '
          'Use "Continue with Google" above, or enable Email/Password under '
          'Authentication → Sign-in method.',
    _ => 'Authentication failed (${error.code}). Please try again.',
  };
}
