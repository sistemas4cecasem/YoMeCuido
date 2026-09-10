import 'dart:async';

import 'package:demo_yomecuido/app/app_router.dart';
import 'package:demo_yomecuido/app/app_strings.dart';
import 'package:demo_yomecuido/app/category_progress_controller.dart';
import 'package:demo_yomecuido/core/theme/app_theme.dart';
import 'package:demo_yomecuido/data/models/auth_user.dart';
import 'package:demo_yomecuido/data/models/category.dart';
import 'package:demo_yomecuido/data/models/category_progress.dart';
import 'package:demo_yomecuido/data/models/final_exam.dart';
import 'package:demo_yomecuido/data/models/learning_activity.dart';
import 'package:demo_yomecuido/data/models/lesson_page.dart';
import 'package:demo_yomecuido/data/models/quiz_question.dart';
import 'package:demo_yomecuido/data/models/user_profile.dart';
import 'package:demo_yomecuido/data/repositories/auth_repository.dart';
import 'package:demo_yomecuido/data/repositories/category_progress_repository.dart';
import 'package:demo_yomecuido/data/repositories/content_repository.dart';
import 'package:demo_yomecuido/data/repositories/user_profile_repository.dart';
import 'package:demo_yomecuido/features/auth/auth_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renames own profile and preserves it when reopened', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = _ControllableAuthRepository();
    final profiles = _FakeUserProfileRepository();
    await _pumpGate(tester, auth, userProfileRepository: profiles);
    auth.emit(
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
    await tester.tap(find.byTooltip(AppStrings.changeUsername));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'NuevoNombre');
    await tester.tap(find.text(AppStrings.saveUsername));
    await tester.pumpAndSettle();
    expect(profiles.changedUid, 'uid-123');
    expect(find.text('NuevoNombre'), findsOneWidget);
    await tester.tap(find.text(AppStrings.close));
    await tester.pumpAndSettle();
    await _openUserMenu(tester);
    await tester.tap(find.text(AppStrings.viewProfile));
    await tester.pumpAndSettle();
    expect(find.text('NuevoNombre'), findsOneWidget);
    expect(find.text('diegonais'), findsNothing);
  });

  testWidgets('occupied username can be corrected and cancel keeps old name', (
    tester,
  ) async {
    final auth = _ControllableAuthRepository();
    final profiles = _FakeUserProfileRepository()..failRename = true;
    await _pumpGate(tester, auth, userProfileRepository: profiles);
    auth.emit(
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
    await tester.tap(find.byTooltip(AppStrings.changeUsername));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ocupado');
    await tester.tap(find.text(AppStrings.saveUsername));
    await tester.pumpAndSettle();
    expect(find.text('Este nombre de usuario ya está en uso.'), findsOneWidget);
    await tester.tap(find.text(AppStrings.cancel));
    await tester.pumpAndSettle();
    expect(find.text('diegonais'), findsOneWidget);
    profiles.failRename = false;
    await tester.tap(find.byTooltip(AppStrings.changeUsername));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'disponible');
    await tester.tap(find.text(AppStrings.saveUsername));
    await tester.pumpAndSettle();
    expect(find.text('disponible'), findsOneWidget);
  });

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

  testWidgets('does not show zero progress when progress hydration fails', (
    tester,
  ) async {
    final authRepository = _ControllableAuthRepository();
    final progressPersistence = _FakeProgressPersistence()..failFetch = true;
    final progressController = CategoryProgressController(
      persistence: progressPersistence,
      currentUserIdProvider: () => authRepository.currentUser?.uid,
    );

    await _pumpGate(
      tester,
      authRepository,
      progressController: progressController,
    );
    authRepository.emit(
      const AuthUser(
        uid: 'uid-123',
        email: 'persona@example.com',
        isEmailVerified: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.progressLoadError), findsOneWidget);
    expect(find.text(AppStrings.digitalSecurityTitle), findsNothing);
    expect(progressController.hydrationStatus, ProgressHydrationStatus.error);
    expect(progressController.hasResolvedProgressFor('uid-123'), isFalse);
  });

  testWidgets('retries progress hydration before entering the app', (
    tester,
  ) async {
    final authRepository = _ControllableAuthRepository();
    final progressPersistence = _FakeProgressPersistence()..failFetch = true;
    final progressController = CategoryProgressController(
      persistence: progressPersistence,
      currentUserIdProvider: () => authRepository.currentUser?.uid,
    );

    await _pumpGate(
      tester,
      authRepository,
      progressController: progressController,
    );
    authRepository.emit(
      const AuthUser(
        uid: 'uid-123',
        email: 'persona@example.com',
        isEmailVerified: true,
      ),
    );
    await tester.pumpAndSettle();

    progressPersistence.failFetch = false;
    await tester.tap(find.text(AppStrings.retry));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.digitalSecurityTitle), findsOneWidget);
    expect(find.text(AppStrings.progressLoadError), findsNothing);
    expect(progressController.hydrationStatus, ProgressHydrationStatus.loaded);
    expect(progressPersistence.fetchCalls, <String>['uid-123', 'uid-123']);
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
      expect(find.text(AppStrings.profileUsername), findsOneWidget);
      expect(find.text('diegonais'), findsOneWidget);
      expect(find.text('persona@example.com'), findsOneWidget);
      expect(find.text(AppStrings.profileRole), findsOneWidget);
      expect(find.text(AppStrings.profileUserRole), findsOneWidget);
      expect(find.text(AppStrings.profileTotalPoints), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
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

  testWidgets('asks verified legacy users to complete username', (
    tester,
  ) async {
    final authRepository = _ControllableAuthRepository();
    final userProfileRepository = _FakeUserProfileRepository(
      profile: const UserProfile(
        username: null,
        usernameNormalized: null,
        email: 'persona@example.com',
        role: UserProfileRole.user,
        createdAt: null,
        updatedAt: null,
      ),
    );

    await _pumpGate(
      tester,
      authRepository,
      userProfileRepository: userProfileRepository,
    );
    authRepository.emit(
      const AuthUser(
        uid: 'uid-123',
        email: 'persona@example.com',
        isEmailVerified: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.completeProfileTitle), findsOneWidget);
    expect(find.text(AppStrings.digitalSecurityTitle), findsNothing);
  });

  testWidgets('completes legacy profile and continues to app', (tester) async {
    final authRepository = _ControllableAuthRepository();
    final userProfileRepository = _FakeUserProfileRepository(
      profile: const UserProfile(
        username: null,
        usernameNormalized: null,
        email: 'persona@example.com',
        role: UserProfileRole.user,
        createdAt: null,
        updatedAt: null,
      ),
    );

    await _pumpGate(
      tester,
      authRepository,
      userProfileRepository: userProfileRepository,
    );
    authRepository.emit(
      const AuthUser(
        uid: 'uid-123',
        email: 'persona@example.com',
        isEmailVerified: true,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.usernameLabel),
      'DiegoNais',
    );
    await tester.tap(find.text(AppStrings.saveUsername));
    await tester.pumpAndSettle();

    expect(userProfileRepository.completedUsername, 'DiegoNais');
    expect(find.text(AppStrings.digitalSecurityTitle), findsOneWidget);
    expect(find.text(AppStrings.completeProfileTitle), findsNothing);
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

  testWidgets('hydrates personal total points from profile after login', (
    tester,
  ) async {
    final authRepository = _ControllableAuthRepository();
    final progressController = CategoryProgressController(
      currentUserIdProvider: () => authRepository.currentUser?.uid,
    );
    final userProfileRepository = _FakeUserProfileRepository(
      profilesByUid: {
        'uid-123': const UserProfile(
          username: 'diegonais',
          usernameNormalized: 'diegonais',
          email: 'persona@example.com',
          role: UserProfileRole.user,
          totalPoints: 241,
          createdAt: null,
          updatedAt: null,
        ),
      },
    );

    await _pumpGate(
      tester,
      authRepository,
      userProfileRepository: userProfileRepository,
      progressController: progressController,
    );
    authRepository.emit(
      const AuthUser(
        uid: 'uid-123',
        email: 'persona@example.com',
        isEmailVerified: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(progressController.totalPointsForUser('uid-123'), 241);
    await _openUserMenu(tester);
    await tester.tap(find.text(AppStrings.viewProfile));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.profileTotalPoints), findsOneWidget);
    expect(find.text('241'), findsOneWidget);
  });

  testWidgets('sign out clears local total points but keeps remote value', (
    tester,
  ) async {
    final authRepository = _ControllableAuthRepository();
    final progressController = CategoryProgressController(
      currentUserIdProvider: () => authRepository.currentUser?.uid,
    );
    final userProfileRepository = _FakeUserProfileRepository(
      profilesByUid: {
        'uid-123': const UserProfile(
          username: 'diegonais',
          usernameNormalized: 'diegonais',
          email: 'persona@example.com',
          role: UserProfileRole.user,
          totalPoints: 241,
          createdAt: null,
          updatedAt: null,
        ),
      },
    );

    await _pumpGate(
      tester,
      authRepository,
      userProfileRepository: userProfileRepository,
      progressController: progressController,
    );
    authRepository.emit(
      const AuthUser(
        uid: 'uid-123',
        email: 'persona@example.com',
        isEmailVerified: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(progressController.currentTotalPoints, 241);

    authRepository.emit(null);
    await tester.pumpAndSettle();
    expect(progressController.currentTotalPoints, isNull);
    expect(userProfileRepository.profilesByUid['uid-123']?.totalPoints, 241);

    authRepository.emit(
      const AuthUser(
        uid: 'uid-123',
        email: 'persona@example.com',
        isEmailVerified: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(progressController.currentTotalPoints, 241);
  });

  testWidgets('switching users shows the active user total points', (
    tester,
  ) async {
    final authRepository = _ControllableAuthRepository();
    final progressController = CategoryProgressController(
      currentUserIdProvider: () => authRepository.currentUser?.uid,
    );
    final userProfileRepository = _FakeUserProfileRepository(
      profilesByUid: {
        'uid-a': const UserProfile(
          username: 'usuarioa',
          usernameNormalized: 'usuarioa',
          email: 'a@example.com',
          role: UserProfileRole.user,
          totalPoints: 241,
          createdAt: null,
          updatedAt: null,
        ),
        'uid-b': const UserProfile(
          username: 'usuariob',
          usernameNormalized: 'usuariob',
          email: 'b@example.com',
          role: UserProfileRole.user,
          totalPoints: 80,
          createdAt: null,
          updatedAt: null,
        ),
      },
    );

    await _pumpGate(
      tester,
      authRepository,
      userProfileRepository: userProfileRepository,
      progressController: progressController,
    );
    authRepository.emit(
      const AuthUser(
        uid: 'uid-a',
        email: 'a@example.com',
        isEmailVerified: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(progressController.currentTotalPoints, 241);

    authRepository.emit(
      const AuthUser(
        uid: 'uid-b',
        email: 'b@example.com',
        isEmailVerified: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(progressController.totalPointsForUser('uid-a'), isNull);
    expect(progressController.totalPointsForUser('uid-b'), 80);
    await _openUserMenu(tester);
    await tester.tap(find.text(AppStrings.viewProfile));
    await tester.pumpAndSettle();

    expect(find.text('80'), findsOneWidget);
    expect(find.text('241'), findsNothing);
  });
}

Future<void> _openUserMenu(WidgetTester tester) async {
  await tester.tap(find.byTooltip(AppStrings.profileTitle));
  await tester.pumpAndSettle();
}

Future<void> _pumpGate(
  WidgetTester tester,
  _ControllableAuthRepository authRepository, {
  UserProfileRepository? userProfileRepository,
  CategoryProgressController? progressController,
}) async {
  final resolvedProgressController =
      progressController ?? CategoryProgressController();
  final router = AppRouter(
    contentRepository: const _EmptyContentRepository(),
    authRepository: authRepository,
    progressController: resolvedProgressController,
  );

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.data(),
      home: AuthGate(
        authRepository: authRepository,
        userProfileRepository:
            userProfileRepository ?? _FakeUserProfileRepository(),
        progressController: resolvedProgressController,
      ),
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
    required String username,
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

class _FakeUserProfileRepository extends UserProfileRepository {
  _FakeUserProfileRepository({
    this.profile,
    Map<String, UserProfile>? profilesByUid,
  }) : profilesByUid = profilesByUid ?? <String, UserProfile>{},
       super.testing();

  UserProfile? profile;
  final Map<String, UserProfile> profilesByUid;
  String? completedUsername;
  String? changedUid;
  bool failRename = false;

  @override
  Future<UserProfile> changeUsername({
    required String uid,
    required String? email,
    required String username,
  }) async {
    changedUid = uid;
    if (failRename) {
      throw const UserProfileException(
        UserProfileFailureReason.usernameAlreadyInUse,
        operation: UserProfileFailureOperation.changeUsername,
      );
    }
    return completeProfile(uid: uid, email: email, username: username);
  }

  @override
  Future<UserProfile?> fetchProfile(String uid) async {
    final uidProfile = profilesByUid[uid];
    if (uidProfile != null) {
      return uidProfile;
    }
    return profile ??
        const UserProfile(
          username: 'diegonais',
          usernameNormalized: 'diegonais',
          email: 'persona@example.com',
          role: UserProfileRole.user,
          createdAt: null,
          updatedAt: null,
        );
  }

  @override
  Future<UserProfile> completeProfile({
    required String uid,
    required String? email,
    required String username,
  }) async {
    completedUsername = username;
    profile = UserProfile(
      username: username,
      usernameNormalized: username.toLowerCase(),
      email: email ?? 'persona@example.com',
      role: UserProfileRole.user,
      totalPoints: profile?.totalPoints ?? profilesByUid[uid]?.totalPoints ?? 0,
      createdAt: null,
      updatedAt: null,
    );
    profilesByUid[uid] = profile!;
    return profile!;
  }
}

class _FakeProgressPersistence implements CategoryProgressPersistence {
  final fetchCalls = <String>[];
  bool failFetch = false;

  @override
  Future<List<CategoryProgressRecord>> fetchAllProgress({required String uid}) {
    fetchCalls.add(uid);
    if (failFetch) {
      throw const CategoryProgressException(
        CategoryProgressFailureReason.unavailable,
        operation: CategoryProgressFailureOperation.fetchAllProgress,
      );
    }

    return Future<List<CategoryProgressRecord>>.value(
      const <CategoryProgressRecord>[],
    );
  }

  @override
  Future<void> markTheoryPageViewed({
    required String uid,
    required String categoryId,
    required String lessonId,
    required String pageId,
    required int totalLessonPages,
    required int totalActivities,
  }) async {}

  @override
  Future<CompletedQuizAttemptPersistenceResult> completeActivityAttempt({
    required String uid,
    required String categoryId,
    required String lessonId,
    required String activityId,
    required String attemptId,
    required DateTime startedAt,
    required List<String> questionIds,
    required Iterable<CategoryProgressAnswer> answers,
    required int totalLessonPages,
    required int totalActivities,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<CompletedQuizAttemptPersistenceResult> completeExamAttempt({
    required String uid,
    required String categoryId,
    required String lessonId,
    required String examId,
    required String attemptId,
    required DateTime startedAt,
    required List<String> questionIds,
    required Iterable<CategoryProgressAnswer> answers,
    required int correctAnswers,
    required int totalQuestions,
    required int percentage,
    required int totalLessonPages,
    required int totalActivities,
  }) {
    throw UnimplementedError();
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
  Future<List<LearningActivity>> loadActivities(String categoryId) async {
    return const <LearningActivity>[];
  }

  @override
  Future<List<QuizQuestion>> loadQuizQuestions(
    String categoryId, {
    String? activityId,
  }) async {
    return const <QuizQuestion>[];
  }

  @override
  Future<FinalExamConfig?> loadFinalExamConfig(String categoryId) async {
    return null;
  }
}
