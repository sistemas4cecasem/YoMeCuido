import 'dart:async';

import 'package:demo_yomecuido/app/app_strings.dart';
import 'package:demo_yomecuido/core/theme/app_theme.dart';
import 'package:demo_yomecuido/data/models/auth_user.dart';
import 'package:demo_yomecuido/data/repositories/auth_repository.dart';
import 'package:demo_yomecuido/features/auth/email_verification_screen.dart';
import 'package:demo_yomecuido/shared/services/connectivity_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('offline check does not reload the Firebase user', (
    tester,
  ) async {
    final repository = _FakeAuthRepository();
    final connectivity = _offlineConnectivityService();
    addTearDown(connectivity.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data(),
        home: EmailVerificationScreen(
          authRepository: repository,
          connectivityService: connectivity,
          onVerificationChecked: (_) {},
        ),
      ),
    );

    await tester.tap(find.text(AppStrings.emailVerificationCheck));
    await tester.pumpAndSettle();

    expect(repository.reloadCallCount, 0);
    expect(
      find.text(AppStrings.emailVerificationConnectionError),
      findsWidgets,
    );
  });

  testWidgets('offline resend does not send a verification email', (
    tester,
  ) async {
    final repository = _FakeAuthRepository();
    final connectivity = _offlineConnectivityService();
    addTearDown(connectivity.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data(),
        home: EmailVerificationScreen(
          authRepository: repository,
          connectivityService: connectivity,
          onVerificationChecked: (_) {},
        ),
      ),
    );

    await tester.tap(find.text(AppStrings.emailVerificationResend));
    await tester.pumpAndSettle();

    expect(repository.sendVerificationCallCount, 0);
    expect(
      find.text(AppStrings.emailVerificationResendConnectionError),
      findsWidgets,
    );
  });
}

ConnectivityService _offlineConnectivityService() {
  return ConnectivityService(
    networkMonitor: _FakeNetworkInterfaceMonitor(),
    backendProbe: _FakeBackendConnectivityProbe(),
  );
}

class _FakeNetworkInterfaceMonitor implements NetworkInterfaceMonitor {
  final _controller = StreamController<bool>.broadcast();

  @override
  Future<bool> hasNetworkInterface() async => false;

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
  int reloadCallCount = 0;
  int sendVerificationCallCount = 0;

  @override
  AuthUser? get currentUser {
    return const AuthUser(uid: 'uid-123', email: 'persona@example.com');
  }

  @override
  Stream<AuthUser?> authStateChanges() => Stream<AuthUser?>.value(currentUser);

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
  Future<void> sendEmailVerification() async {
    sendVerificationCallCount += 1;
  }

  @override
  Future<AuthUser?> reloadCurrentUser() async {
    reloadCallCount += 1;
    return currentUser;
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
