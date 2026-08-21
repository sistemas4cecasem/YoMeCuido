import 'dart:async';

import 'package:demo_yomecuido/app/app_router.dart';
import 'package:demo_yomecuido/app/app_strings.dart';
import 'package:demo_yomecuido/app/category_progress_controller.dart';
import 'package:demo_yomecuido/core/theme/app_theme.dart';
import 'package:demo_yomecuido/data/models/auth_user.dart';
import 'package:demo_yomecuido/data/models/category.dart';
import 'package:demo_yomecuido/data/models/lesson_page.dart';
import 'package:demo_yomecuido/data/models/quiz_question.dart';
import 'package:demo_yomecuido/data/repositories/auth_repository.dart';
import 'package:demo_yomecuido/data/repositories/content_repository.dart';
import 'package:demo_yomecuido/features/auth/auth_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows access welcome when Authentication has no user', (
    tester,
  ) async {
    final authRepository = _ControllableAuthRepository();

    await _pumpGate(tester, authRepository);
    expect(find.text(AppStrings.checkingSession), findsOneWidget);

    authRepository.emit(null);
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.loginTitle), findsOneWidget);
    expect(find.text(AppStrings.addAccount), findsOneWidget);
    expect(find.byKey(const Key('welcome_logo')), findsOneWidget);
    expect(find.text(AppStrings.start), findsNothing);
  });

  testWidgets('shows high-level categories when Authentication has a user', (
    tester,
  ) async {
    final authRepository = _ControllableAuthRepository();

    await _pumpGate(tester, authRepository);
    authRepository.emit(
      const AuthUser(
        uid: 'uid-123',
        email: 'persona@example.com',
        isEmailVerified: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.traffickingTitle), findsOneWidget);
    expect(find.text(AppStrings.digitalSecurityTitle), findsOneWidget);
    expect(find.byTooltip(AppStrings.profileTitle), findsOneWidget);
    expect(find.byTooltip(AppStrings.signOut), findsNothing);
    expect(find.text(AppStrings.start), findsNothing);
    expect(find.text(AppStrings.loginTitle), findsNothing);
    expect(find.text(AppStrings.addAccount), findsNothing);
  });

  testWidgets('moves from login to high-level categories after auth changes', (
    tester,
  ) async {
    final authRepository = _ControllableAuthRepository();

    await _pumpGate(tester, authRepository);
    authRepository.emit(null);
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.loginTitle));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.loginAction), findsOneWidget);
    expect(find.text(AppStrings.loginIntroTitle), findsNothing);

    authRepository.emit(
      const AuthUser(
        uid: 'uid-123',
        email: 'persona@example.com',
        isEmailVerified: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.traffickingTitle), findsOneWidget);
    expect(find.text(AppStrings.digitalSecurityTitle), findsOneWidget);
    expect(find.text(AppStrings.start), findsNothing);
    expect(find.text(AppStrings.loginTitle), findsNothing);
  });

  testWidgets('clears register route after a successful registration state', (
    tester,
  ) async {
    final authRepository = _ControllableAuthRepository();

    await _pumpGate(tester, authRepository);
    authRepository.emit(null);
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.addAccount));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.registerTitle), findsWidgets);

    authRepository.emit(
      const AuthUser(
        uid: 'uid-123',
        email: 'persona@example.com',
        isEmailVerified: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.traffickingTitle), findsOneWidget);
    expect(find.text(AppStrings.digitalSecurityTitle), findsOneWidget);
    expect(find.text(AppStrings.start), findsNothing);
    expect(find.text(AppStrings.registerTitle), findsNothing);
  });

  testWidgets('signs out and returns to login through auth state', (
    tester,
  ) async {
    final authRepository = _ControllableAuthRepository();

    await _pumpGate(tester, authRepository);
    authRepository.emit(
      const AuthUser(
        uid: 'uid-123',
        email: 'persona@example.com',
        isEmailVerified: true,
      ),
    );
    await tester.pumpAndSettle();

    await _openUserMenu(tester);
    await tester.tap(find.text(AppStrings.signOut));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text(AppStrings.signOutTitle), findsOneWidget);

    await tester.tap(find.text(AppStrings.signOut).last);
    await tester.pumpAndSettle();

    expect(authRepository.signOutCallCount, 1);
    expect(find.text(AppStrings.loginTitle), findsOneWidget);
    expect(find.text(AppStrings.addAccount), findsOneWidget);
    expect(find.text(AppStrings.start), findsNothing);
  });

  testWidgets('keeps the user signed in when signOut fails', (tester) async {
    final authRepository = _ControllableAuthRepository()
      ..shouldFailSignOut = true;

    await _pumpGate(tester, authRepository);
    authRepository.emit(
      const AuthUser(
        uid: 'uid-123',
        email: 'persona@example.com',
        isEmailVerified: true,
      ),
    );
    await tester.pumpAndSettle();

    await _openUserMenu(tester);
    await tester.tap(find.text(AppStrings.signOut));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text(AppStrings.signOut).last);
    await tester.pumpAndSettle();

    expect(authRepository.signOutCallCount, 1);
    expect(find.text(AppStrings.traffickingTitle), findsOneWidget);
    expect(find.text(AppStrings.digitalSecurityTitle), findsOneWidget);
    expect(find.text(AppStrings.start), findsNothing);
    expect(find.text(AppStrings.loginTitle), findsNothing);
    expect(find.text(AppStrings.signOutError), findsOneWidget);
  });

  testWidgets(
    'opens user profile and keeps menu available after canceling sign out',
    (tester) async {
      final authRepository = _ControllableAuthRepository();

      await _pumpGate(tester, authRepository);
      authRepository.emit(
        const AuthUser(
          uid: 'uid-123',
          email: 'persona@example.com',
          isEmailVerified: true,
        ),
      );
      await tester.pumpAndSettle();

      await _openUserMenu(tester);
      await tester.tap(find.text(AppStrings.viewProfile));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.profileTitle), findsOneWidget);
      expect(find.text('persona@example.com'), findsOneWidget);
      expect(find.text(AppStrings.profileVerifiedEmail), findsOneWidget);

      await tester.tap(find.text(AppStrings.close));
      await tester.pumpAndSettle();

      await _openUserMenu(tester);
      await tester.tap(find.text(AppStrings.signOut));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text(AppStrings.signOutTitle), findsOneWidget);

      await tester.tap(find.text(AppStrings.cancel));
      await tester.pumpAndSettle();

      expect(find.byTooltip(AppStrings.profileTitle), findsOneWidget);
      expect(authRepository.signOutCallCount, 0);
    },
  );

  testWidgets('blocks high-level categories until email is verified', (
    tester,
  ) async {
    final authRepository = _ControllableAuthRepository();

    await _pumpGate(tester, authRepository);
    authRepository.emit(
      const AuthUser(uid: 'uid-123', email: 'persona@example.com'),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.emailVerificationTitle), findsOneWidget);
    expect(find.text(AppStrings.digitalSecurityTitle), findsNothing);

    authRepository.nextReloadedUser = const AuthUser(
      uid: 'uid-123',
      email: 'persona@example.com',
      isEmailVerified: true,
    );
    await tester.tap(find.text(AppStrings.emailVerificationCheck));
    await tester.pumpAndSettle();

    expect(authRepository.reloadCallCount, 1);
    expect(find.text(AppStrings.digitalSecurityTitle), findsOneWidget);
    expect(find.text(AppStrings.emailVerificationTitle), findsNothing);
  });

  testWidgets(
    'shows a pending verification message when email is not verified',
    (tester) async {
      final authRepository = _ControllableAuthRepository();

      await _pumpGate(tester, authRepository);
      authRepository.emit(
        const AuthUser(uid: 'uid-123', email: 'persona@example.com'),
      );
      await tester.pumpAndSettle();

      authRepository.nextReloadedUser = const AuthUser(
        uid: 'uid-123',
        email: 'persona@example.com',
      );
      await tester.tap(find.text(AppStrings.emailVerificationCheck));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(authRepository.reloadCallCount, 1);
      expect(find.text(AppStrings.emailVerificationTitle), findsOneWidget);
      expect(find.text(AppStrings.digitalSecurityTitle), findsNothing);
      expect(find.text(AppStrings.emailVerificationPending), findsWidgets);
    },
  );
}

Future<void> _openUserMenu(WidgetTester tester) async {
  await tester.tap(find.byTooltip(AppStrings.profileTitle));
  await tester.pumpAndSettle();
}

Future<void> _pumpGate(
  WidgetTester tester,
  _ControllableAuthRepository authRepository,
) async {
  final router = AppRouter(
    contentRepository: const _EmptyContentRepository(),
    authRepository: authRepository,
    progressController: CategoryProgressController(),
  );

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.data(),
      home: AuthGate(authRepository: authRepository),
      onGenerateRoute: router.onGenerateRoute,
    ),
  );
}

class _ControllableAuthRepository implements AuthRepository {
  final StreamController<AuthUser?> _controller =
      StreamController<AuthUser?>.broadcast();

  AuthUser? _currentUser;
  bool shouldFailSignOut = false;
  int signOutCallCount = 0;
  int sendVerificationCallCount = 0;
  int reloadCallCount = 0;
  AuthUser? nextReloadedUser;

  void emit(AuthUser? user) {
    _currentUser = user;
    _controller.add(user);
  }

  @override
  AuthUser? get currentUser => _currentUser;

  @override
  Stream<AuthUser?> authStateChanges() => _controller.stream;

  @override
  Future<AuthUser> registerWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    final user = AuthUser(uid: 'uid-123', email: email);
    emit(user);
    return Future.value(user);
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
    final user = nextReloadedUser ?? _currentUser;
    _currentUser = user;
    return user;
  }

  @override
  Future<AuthUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    final user = AuthUser(uid: 'uid-123', email: email);
    emit(user);
    return Future.value(user);
  }

  @override
  Future<void> signOut() async {
    signOutCallCount += 1;
    if (shouldFailSignOut) {
      throw const AuthException(AuthFailureReason.unknown);
    }
    emit(null);
  }
}

class _EmptyContentRepository implements ContentRepository {
  const _EmptyContentRepository();

  @override
  Future<List<Category>> loadCategories() async => const <Category>[];

  @override
  Future<List<LessonPage>> loadLessonPages(String categoryId) async {
    return const <LessonPage>[];
  }

  @override
  Future<List<QuizQuestion>> loadQuizQuestions(String categoryId) async {
    return const <QuizQuestion>[];
  }
}
