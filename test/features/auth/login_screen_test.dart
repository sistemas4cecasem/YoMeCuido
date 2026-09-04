import 'package:demo_yomecuido/app/app_router.dart';
import 'package:demo_yomecuido/app/app_strings.dart';
import 'package:demo_yomecuido/core/theme/app_theme.dart';
import 'package:demo_yomecuido/data/models/auth_user.dart';
import 'package:demo_yomecuido/data/repositories/auth_repository.dart';
import 'package:demo_yomecuido/features/auth/forgot_password_screen.dart';
import 'package:demo_yomecuido/features/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('signs in through AuthRepository and shows success', (
    tester,
  ) async {
    final repository = _FakeAuthRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data(),
        home: LoginScreen(authRepository: repository),
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.emailLabel),
      ' persona@example.com ',
    );
    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.passwordLabel),
      '123456',
    );
    await tester.tap(
      find.widgetWithText(ElevatedButton, AppStrings.loginAction),
    );
    await tester.pumpAndSettle();

    expect(repository.signInCallCount, 1);
    expect(repository.lastEmail, 'persona@example.com');
    expect(find.text(AppStrings.loginSuccessMessage), findsOneWidget);
  });

  testWidgets('opens password recovery from login', (tester) async {
    final repository = _FakeAuthRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data(),
        home: LoginScreen(authRepository: repository),
        routes: {
          AppRoutes.forgotPassword: (_) {
            return ForgotPasswordScreen(authRepository: repository);
          },
        },
      ),
    );

    await tester.tap(find.text(AppStrings.forgotPasswordPrompt));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.forgotPasswordTitle), findsOneWidget);
  });
}

class _FakeAuthRepository implements AuthRepository {
  int signInCallCount = 0;
  String? lastEmail;

  @override
  AuthUser? get currentUser => null;

  @override
  Stream<AuthUser?> authStateChanges() => const Stream.empty();

  @override
  Future<AuthUser> registerWithEmailAndPassword({
    required String username,
    required String email,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {}

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<AuthUser?> reloadCurrentUser() async => currentUser;

  @override
  Future<AuthUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    signInCallCount += 1;
    lastEmail = email;
    return AuthUser(uid: 'uid-123', email: email);
  }

  @override
  Future<void> signOut() async {}
}
