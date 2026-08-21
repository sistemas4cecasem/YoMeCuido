import 'dart:async';

import 'package:demo_yomecuido/data/models/auth_user.dart';
import 'package:demo_yomecuido/data/repositories/auth_repository.dart';
import 'package:demo_yomecuido/features/auth/register_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RegisterController', () {
    test('validates an empty email before calling the repository', () async {
      final repository = _FakeAuthRepository();
      final controller = RegisterController(authRepository: repository);

      final user = await controller.submit(
        email: ' ',
        password: '123456',
        confirmPassword: '123456',
      );

      expect(user, isNull);
      expect(controller.emailError, 'Ingresa tu correo electrónico.');
      expect(repository.registerCallCount, 0);
    });

    test('validates an invalid email before calling the repository', () async {
      final repository = _FakeAuthRepository();
      final controller = RegisterController(authRepository: repository);

      final user = await controller.submit(
        email: 'correo-invalido',
        password: '123456',
        confirmPassword: '123456',
      );

      expect(user, isNull);
      expect(controller.emailError, 'Ingresa un correo electrónico válido.');
      expect(repository.registerCallCount, 0);
    });

    test('validates an empty password before calling the repository', () async {
      final repository = _FakeAuthRepository();
      final controller = RegisterController(authRepository: repository);

      final user = await controller.submit(
        email: 'persona@example.com',
        password: '',
        confirmPassword: '',
      );

      expect(user, isNull);
      expect(controller.passwordError, 'Ingresa una contraseña.');
      expect(repository.registerCallCount, 0);
    });

    test('validates a short password before calling the repository', () async {
      final repository = _FakeAuthRepository();
      final controller = RegisterController(authRepository: repository);

      final user = await controller.submit(
        email: 'persona@example.com',
        password: '12345',
        confirmPassword: '12345',
      );

      expect(user, isNull);
      expect(
        controller.passwordError,
        'La contraseña debe tener al menos 6 caracteres.',
      );
      expect(repository.registerCallCount, 0);
    });

    test(
      'validates an empty confirmation before calling the repository',
      () async {
        final repository = _FakeAuthRepository();
        final controller = RegisterController(authRepository: repository);

        final user = await controller.submit(
          email: 'persona@example.com',
          password: '123456',
          confirmPassword: '',
        );

        expect(user, isNull);
        expect(controller.confirmPasswordError, 'Confirma tu contraseña.');
        expect(repository.registerCallCount, 0);
      },
    );

    test(
      'validates different passwords before calling the repository',
      () async {
        final repository = _FakeAuthRepository();
        final controller = RegisterController(authRepository: repository);

        final user = await controller.submit(
          email: 'persona@example.com',
          password: '123456',
          confirmPassword: '654321',
        );

        expect(user, isNull);
        expect(
          controller.confirmPasswordError,
          'Las contraseñas no coinciden.',
        );
        expect(repository.registerCallCount, 0);
      },
    );

    test(
      'sets loading state while the repository creates the account',
      () async {
        final completer = Completer<AuthUser>();
        final repository = _FakeAuthRepository(resultFuture: completer.future);
        final controller = RegisterController(authRepository: repository);

        final submitFuture = controller.submit(
          email: ' persona@example.com ',
          password: '123456',
          confirmPassword: '123456',
        );

        expect(controller.isLoading, isTrue);
        expect(repository.lastEmail, 'persona@example.com');

        completer.complete(
          const AuthUser(uid: 'uid-123', email: 'persona@example.com'),
        );
        final user = await submitFuture;

        expect(controller.isLoading, isFalse);
        expect(user?.uid, 'uid-123');
      },
    );

    test(
      'stores the authenticated user after a successful registration',
      () async {
        final repository = _FakeAuthRepository(
          resultFuture: Future.value(
            const AuthUser(uid: 'uid-123', email: 'persona@example.com'),
          ),
        );
        final controller = RegisterController(authRepository: repository);

        await controller.submit(
          email: 'persona@example.com',
          password: '123456',
          confirmPassword: '123456',
        );

        expect(controller.hasRegisteredSuccessfully, isTrue);
        expect(controller.registeredUser?.uid, 'uid-123');
        expect(repository.sendVerificationCallCount, 1);
        expect(controller.submitError, isNull);
      },
    );

    test('shows own authentication errors from the repository', () async {
      final repository = _FakeAuthRepository(
        exception: const AuthException(AuthFailureReason.emailAlreadyInUse),
      );
      final controller = RegisterController(authRepository: repository);

      final user = await controller.submit(
        email: 'persona@example.com',
        password: '123456',
        confirmPassword: '123456',
      );

      expect(user, isNull);
      expect(controller.isLoading, isFalse);
      expect(controller.submitError, 'Este correo ya está registrado.');
    });
  });
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.resultFuture, this.exception});

  final Future<AuthUser>? resultFuture;
  final AuthException? exception;
  int registerCallCount = 0;
  int sendVerificationCallCount = 0;
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
    registerCallCount += 1;
    lastEmail = email;
    final exception = this.exception;
    if (exception != null) {
      throw exception;
    }

    return resultFuture ?? Future.value(AuthUser(uid: 'uid-123', email: email));
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {}

  @override
  Future<void> sendEmailVerification() async {
    sendVerificationCallCount += 1;
  }

  @override
  Future<AuthUser?> reloadCurrentUser() async => currentUser;

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
