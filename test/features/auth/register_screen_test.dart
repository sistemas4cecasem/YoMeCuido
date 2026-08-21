import 'package:demo_yomecuido/app/app_strings.dart';
import 'package:demo_yomecuido/core/theme/app_theme.dart';
import 'package:demo_yomecuido/data/models/auth_user.dart';
import 'package:demo_yomecuido/data/repositories/auth_repository.dart';
import 'package:demo_yomecuido/features/auth/register_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('creates an account through AuthRepository and shows success', (
    tester,
  ) async {
    final repository = _FakeAuthRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data(),
        home: RegisterScreen(authRepository: repository),
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
    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.confirmPasswordLabel),
      '123456',
    );
    await tester.tap(
      find.widgetWithText(ElevatedButton, AppStrings.createAccount),
    );
    await tester.pumpAndSettle();

    expect(repository.registerCallCount, 1);
    expect(repository.sendVerificationCallCount, 1);
    expect(repository.lastEmail, 'persona@example.com');
    expect(find.text(AppStrings.registerSuccessMessage), findsOneWidget);
  });
}

class _FakeAuthRepository implements AuthRepository {
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
  }) async {
    registerCallCount += 1;
    lastEmail = email;
    return AuthUser(uid: 'uid-123', email: email);
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
