import 'package:firebase_auth/firebase_auth.dart';

String messageForAuthError(FirebaseAuthException e) {
  switch (e.code) {
    case 'invalid-email':
      return 'That email address looks invalid.';
    case 'user-disabled':
      return 'This account has been disabled.';
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
      return 'Incorrect email or password.';
    case 'email-already-in-use':
      return 'An account already exists for that email.';
    case 'weak-password':
      return 'Choose a stronger password (at least 6 characters).';
    default:
      return e.message ?? 'Something went wrong. Please try again.';
  }
}
