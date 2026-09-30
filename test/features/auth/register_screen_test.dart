import 'dart:async';

import 'package:demo_yomecuido/app/app_strings.dart';
import 'package:demo_yomecuido/core/theme/app_theme.dart';
import 'package:demo_yomecuido/data/models/auth_user.dart';
import 'package:demo_yomecuido/data/repositories/auth_repository.dart';
import 'package:demo_yomecuido/features/auth/register_screen.dart';
import 'package:demo_yomecuido/features/privacy/privacy_notice_screen.dart';
import 'package:demo_yomecuido/shared/services/connectivity_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('registration opens the reusable privacy notice', (tester) async {
    final connectivity = _onlineConnectivityService();
    addTearDown(connectivity.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data(),
        home: RegisterScreen(
          authRepository: _FakeAuthRepository(),
          connectivityService: connectivity,
        ),
      ),
    );
    await tester.ensureVisible(find.text(AppStrings.privacyTitle));
    await tester.tap(find.text(AppStrings.privacyTitle));
    await tester.pumpAndSettle();
    expect(find.byType(PrivacyNoticeScreen), findsOneWidget);
    expect(find.textContaining('CECASEM'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Qué se ve en el Ranking'), 180);
    expect(find.text('Qué se ve en el Ranking'), findsOneWidget);
    expect(find.textContaining('El correo, las respuestas'), findsOneWidget);
  });

  testWidgets('creates an account through AuthRepository and shows success', (
    tester,
  ) async {
    final repository = _FakeAuthRepository();
    final connectivity = _onlineConnectivityService();
    addTearDown(connectivity.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data(),
        home: RegisterScreen(
          authRepository: repository,
          connectivityService: connectivity,
        ),
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.usernameLabel),
      ' DiegoNais ',
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
    expect(repository.lastUsername, 'DiegoNais');
    expect(repository.lastEmail, 'persona@example.com');
    expect(find.text(AppStrings.registerSuccessMessage), findsOneWidget);
  });
}

ConnectivityService _onlineConnectivityService() {
  return ConnectivityService(
    networkMonitor: _FakeNetworkInterfaceMonitor(),
    backendProbe: _FakeBackendConnectivityProbe(),
  );
}

class _FakeNetworkInterfaceMonitor implements NetworkInterfaceMonitor {
  final _controller = StreamController<bool>.broadcast();

  @override
  Future<bool> hasNetworkInterface() async => true;

  @override
  Stream<bool> get onNetworkInterfaceChanged => _controller.stream;

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}

class _FakeBackendConnectivityProbe implements BackendConnectivityProbe {
  @override
  Future<bool> canReachBackend({required Duration timeout}) async => true;
}

class _FakeAuthRepository implements AuthRepository {
  int registerCallCount = 0;
  int sendVerificationCallCount = 0;
  String? lastUsername;
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
  }) async {
    registerCallCount += 1;
    lastUsername = username;
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
