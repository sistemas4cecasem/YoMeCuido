import 'dart:async';

import 'package:demo_yomecuido/data/models/auth_user.dart';
import 'package:demo_yomecuido/data/repositories/auth_repository.dart';
import 'package:demo_yomecuido/features/auth/forgot_password_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ForgotPasswordController', () {
    test('validates an empty email before calling the repository', () async {
      final repository = _FakeAuthRepository();
      final controller = ForgotPasswordController(authRepository: repository);

      final submitted = await controller.submit(email: ' ');

      expect(submitted, isFalse);
      expect(controller.emailError, 'Ingresa tu correo electrónico.');
      expect(repository.resetCallCount, 0);
    });

    test('validates an invalid email before calling the repository', () async {
      final repository = _FakeAuthRepository();
      final controller = ForgotPasswordController(authRepository: repository);

      final submitted = await controller.submit(email: 'correo-invalido');

      expect(submitted, isFalse);
      expect(controller.emailError, 'Ingresa un correo electrónico válido.');
      expect(repository.resetCallCount, 0);
    });

    test('sets loading state while requesting password reset', () async {
      final completer = Completer<void>();
      final repository = _FakeAuthRepository(resultFuture: completer.future);
      final controller = ForgotPasswordController(authRepository: repository);

      final submitFuture = controller.submit(email: ' persona@example.com ');

      expect(controller.isLoading, isTrue);
      expect(repository.lastEmail, 'persona@example.com');

      completer.complete();
      final submitted = await submitFuture;

      expect(submitted, isTrue);
      expect(controller.isLoading, isFalse);
      expect(controller.hasSubmittedSuccessfully, isTrue);
    });

    test('prevents multiple submissions while loading', () async {
      final completer = Completer<void>();
      final repository = _FakeAuthRepository(resultFuture: completer.future);
      final controller = ForgotPasswordController(authRepository: repository);

      final firstSubmit = controller.submit(email: 'persona@example.com');
      final secondSubmit = await controller.submit(
        email: 'persona@example.com',
      );

      expect(secondSubmit, isFalse);
      expect(repository.resetCallCount, 1);

      completer.complete();
      await firstSubmit;
    });

    test('stores success after a valid request', () async {
      final repository = _FakeAuthRepository();
      final controller = ForgotPasswordController(authRepository: repository);

      final submitted = await controller.submit(email: 'persona@example.com');

      expect(submitted, isTrue);
      expect(controller.hasSubmittedSuccessfully, isTrue);
      expect(controller.submitError, isNull);
    });

    test(
      'treats user-not-found as success to avoid account enumeration',
      () async {
        final repository = _FakeAuthRepository(
          exception: const AuthException(AuthFailureReason.userNotFound),
        );
        final controller = ForgotPasswordController(authRepository: repository);

        final submitted = await controller.submit(email: 'persona@example.com');

        expect(submitted, isTrue);
        expect(controller.hasSubmittedSuccessfully, isTrue);
        expect(controller.submitError, isNull);
      },
    );

    test('shows own authentication errors from the repository', () async {
      final repository = _FakeAuthRepository(
        exception: const AuthException(AuthFailureReason.networkRequestFailed),
      );
      final controller = ForgotPasswordController(authRepository: repository);

      final submitted = await controller.submit(email: 'persona@example.com');

      expect(submitted, isFalse);
      expect(controller.isLoading, isFalse);
      expect(
        controller.submitError,
        'No pudimos conectar con el servicio. Revisa tu conexión.',
      );
    });
  });
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.resultFuture, this.exception});

  final Future<void>? resultFuture;
  final AuthException? exception;
  int resetCallCount = 0;
  String? lastEmail;

  @override
  AuthUser? get currentUser => null;

  @override
  Stream<AuthUser?> authStateChanges() => const Stream.empty();

  @override
  Future<AuthUser> registerWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) {
    resetCallCount += 1;
    lastEmail = email;
    final exception = this.exception;
    if (exception != null) {
      throw exception;
    }

    return resultFuture ?? Future.value();
  }

  @override
  Future<AuthUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> signOut() async {}
}
