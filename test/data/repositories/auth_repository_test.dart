import 'package:demo_yomecuido/data/repositories/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthException.fromFirebaseCode', () {
    test('maps known Firebase Auth error codes', () {
      const expectedReasons = <String, AuthFailureReason>{
        'invalid-email': AuthFailureReason.invalidEmail,
        'user-not-found': AuthFailureReason.userNotFound,
        'wrong-password': AuthFailureReason.wrongPassword,
        'invalid-credential': AuthFailureReason.invalidCredentials,
        'email-already-in-use': AuthFailureReason.emailAlreadyInUse,
        'weak-password': AuthFailureReason.weakPassword,
        'user-disabled': AuthFailureReason.userDisabled,
        'operation-not-allowed': AuthFailureReason.operationNotAllowed,
        'too-many-requests': AuthFailureReason.tooManyRequests,
        'network-request-failed': AuthFailureReason.networkRequestFailed,
      };

      for (final entry in expectedReasons.entries) {
        expect(
          AuthException.fromFirebaseCode(entry.key).reason,
          entry.value,
          reason: 'Expected ${entry.key} to map to ${entry.value}.',
        );
      }
    });

    test('maps unknown Firebase Auth error codes to unknown', () {
      final exception = AuthException.fromFirebaseCode('unexpected-code');

      expect(exception.reason, AuthFailureReason.unknown);
      expect(exception.userMessage, isNotEmpty);
    });
  });
}
