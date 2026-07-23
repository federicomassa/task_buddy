import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_buddy/core/auth_error_messages.dart';

void main() {
  test('invalid-email', () {
    expect(
      messageForAuthError(FirebaseAuthException(code: 'invalid-email')),
      'That email address looks invalid.',
    );
  });

  test('user-disabled', () {
    expect(
      messageForAuthError(FirebaseAuthException(code: 'user-disabled')),
      'This account has been disabled.',
    );
  });

  test('user-not-found / wrong-password / invalid-credential all map to the same message', () {
    for (final code in ['user-not-found', 'wrong-password', 'invalid-credential']) {
      expect(messageForAuthError(FirebaseAuthException(code: code)), 'Incorrect email or password.');
    }
  });

  test('email-already-in-use', () {
    expect(
      messageForAuthError(FirebaseAuthException(code: 'email-already-in-use')),
      'An account already exists for that email.',
    );
  });

  test('weak-password', () {
    expect(
      messageForAuthError(FirebaseAuthException(code: 'weak-password')),
      'Choose a stronger password (at least 6 characters).',
    );
  });

  test('unknown code falls back to e.message', () {
    expect(
      messageForAuthError(FirebaseAuthException(code: 'some-other-code', message: 'Custom message')),
      'Custom message',
    );
  });

  test('unknown code with no message falls back to generic text', () {
    expect(
      messageForAuthError(FirebaseAuthException(code: 'some-other-code')),
      'Something went wrong. Please try again.',
    );
  });
}
