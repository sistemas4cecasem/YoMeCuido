import 'dart:async';

import 'package:demo_yomecuido/data/models/auth_user.dart';
import 'package:demo_yomecuido/data/repositories/auth_repository.dart';
import 'package:demo_yomecuido/features/auth/login_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LoginController', () {
    test('validates an empty email before calling the repository', () async {
      final repository = _FakeAuthRepository();
      final controller = LoginController(authRepository: repository);

      final user = await controller.submit(email: ' ', password: '123456');

      expect(user, isNull);
      expect(controller.emailError, 'Ingresa tu correo electrónico.');
      expect(repository.signInCallCount, 0);
    });

    test('validates an invalid email before calling the repository', () async {
      final repository = _FakeAuthRepository();
      final controller = LoginController(authRepository: repository);

      final user = await controller.submit(
        email: 'correo-invalido',
        password: '123456',
      );

      expect(user, isNull);
      expect(controller.emailError, 'Ingresa un correo electrónico válido.');
      expect(repository.signInCallCount, 0);
    });

    test('validates an empty password before calling the repository', () async {
      final repository = _FakeAuthRepository();
      final controller = LoginController(authRepository: repository);

      final user = await controller.submit(
        email: 'persona@example.com',
        password: '',
      );

      expect(user, isNull);
      expect(controller.passwordError, 'Ingresa tu contraseña.');
      expect(repository.signInCallCount, 0);
    });

    test('sets loading state while the repository signs in', () async {
      final completer = Completer<AuthUser>();
      final repository = _FakeAuthRepository(resultFuture: completer.future);
      final controller = LoginController(authRepository: repository);

      final submitFuture = controller.submit(
        email: ' persona@example.com ',
        password: '123456',
      );

      expect(controller.isLoading, isTrue);
      expect(repository.lastEmail, 'persona@example.com');

      completer.complete(
        const AuthUser(uid: 'uid-123', email: 'persona@example.com'),
      );
      final user = await submitFuture;

      expect(controller.isLoading, isFalse);
      expect(user?.uid, 'uid-123');
    });

    test('prevents multiple submissions while loading', () async {
      final completer = Completer<AuthUser>();
      final repository = _FakeAuthRepository(resultFuture: completer.future);
      final controller = LoginController(authRepository: repository);

      final firstSubmit = controller.submit(
        email: 'persona@example.com',
        password: '123456',
      );
      final secondSubmit = await controller.submit(
        email: 'persona@example.com',
        password: '123456',
      );

      expect(secondSubmit, isNull);
      expect(repository.signInCallCount, 1);

      completer.complete(
        const AuthUser(uid: 'uid-123', email: 'persona@example.com'),
      );
      await firstSubmit;
    });

    test('stores the authenticated user after a successful login', () async {
      final repository = _FakeAuthRepository(
        resultFuture: Future.value(
          const AuthUser(uid: 'uid-123', email: 'persona@example.com'),
        ),
      );
      final controller = LoginController(authRepository: repository);

      await controller.submit(email: 'persona@example.com', password: '123456');

      expect(controller.hasSignedInSuccessfully, isTrue);
      expect(controller.signedInUser?.uid, 'uid-123');
      expect(controller.submitError, isNull);
    });

    test('shows invalid credentials errors from the repository', () async {
      final repository = _FakeAuthRepository(
        exception: const AuthException(AuthFailureReason.invalidCredentials),
      );
      final controller = LoginController(authRepository: repository);

      final user = await controller.submit(
        email: 'persona@example.com',
        password: '123456',
      );

      expect(user, isNull);
      expect(controller.isLoading, isFalse);
      expect(
        controller.submitError,
        'Las credenciales ingresadas no son válidas.',
      );
    });

    test('shows network errors from the repository', () async {
      final repository = _FakeAuthRepository(
        exception: const AuthException(AuthFailureReason.networkRequestFailed),
      );
      final controller = LoginController(authRepository: repository);

      await controller.submit(email: 'persona@example.com', password: '123456');

      expect(
        controller.submitError,
        'No pudimos conectar con el servicio. Revisa tu conexión.',
      );
    });
  });
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.resultFuture, this.exception});

  final Future<AuthUser>? resultFuture;
  final AuthException? exception;
  int signInCallCount = 0;
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
  Future<void> sendPasswordResetEmail({required String email}) async {}

  @override
  Future<AuthUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    signInCallCount += 1;
    lastEmail = email;
    final exception = this.exception;
    if (exception != null) {
      throw exception;
    }

    return resultFuture ?? Future.value(AuthUser(uid: 'uid-123', email: email));
  }

  @override
  Future<void> signOut() async {}
}
