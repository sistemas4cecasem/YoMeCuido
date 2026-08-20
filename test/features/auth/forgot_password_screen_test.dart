import 'package:demo_yomecuido/app/app_strings.dart';
import 'package:demo_yomecuido/core/theme/app_theme.dart';
import 'package:demo_yomecuido/data/models/auth_user.dart';
import 'package:demo_yomecuido/data/repositories/auth_repository.dart';
import 'package:demo_yomecuido/features/auth/forgot_password_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'requests password reset through AuthRepository and shows success',
    (tester) async {
      final repository = _FakeAuthRepository();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.data(),
          home: ForgotPasswordScreen(authRepository: repository),
        ),
      );

      await tester.enterText(
        find.widgetWithText(TextField, AppStrings.emailLabel),
        ' persona@example.com ',
      );
      await tester.tap(
        find.widgetWithText(ElevatedButton, AppStrings.requestPasswordReset),
      );
      await tester.pumpAndSettle();

      expect(repository.resetCallCount, 1);
      expect(repository.lastEmail, 'persona@example.com');
      expect(
        find.text(AppStrings.forgotPasswordSuccessMessage),
        findsOneWidget,
      );
    },
  );
}

class _FakeAuthRepository implements AuthRepository {
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
  Future<void> sendPasswordResetEmail({required String email}) async {
    resetCallCount += 1;
    lastEmail = email;
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
