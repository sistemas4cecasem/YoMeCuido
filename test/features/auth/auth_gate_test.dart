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
import 'package:demo_yomecuido/data/models/leaderboard_entry.dart';
import 'package:demo_yomecuido/data/models/quiz_question.dart';
import 'package:demo_yomecuido/data/models/user_profile.dart';
import 'package:demo_yomecuido/data/repositories/auth_repository.dart';
import 'package:demo_yomecuido/data/repositories/category_progress_repository.dart';
import 'package:demo_yomecuido/data/repositories/content_repository.dart';
import 'package:demo_yomecuido/data/repositories/leaderboard_repository.dart';
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
    await _openProfileTab(tester);
    await tester.ensureVisible(find.byTooltip(AppStrings.changeUsername));
    await tester.tap(find.byTooltip(AppStrings.changeUsername));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'NuevoNombre');
    await tester.tap(find.text(AppStrings.saveUsername));
    await tester.pumpAndSettle();
    expect(profiles.changedUid, 'uid-123');
    expect(find.text('NuevoNombre'), findsWidgets);
    await tester.tap(find.byKey(const Key('main_nav_home')));
    await tester.pumpAndSettle();
    await _openProfileTab(tester);
    expect(find.text('NuevoNombre'), findsWidgets);
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
    await _openProfileTab(tester);
    await tester.ensureVisible(find.byTooltip(AppStrings.changeUsername));
    await tester.tap(find.byTooltip(AppStrings.changeUsername));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ocupado');
    await tester.tap(find.text(AppStrings.saveUsername));
    await tester.pumpAndSettle();
    expect(find.text('Este nombre de usuario ya está en uso.'), findsOneWidget);
    await tester.tap(find.text(AppStrings.cancel));
    await tester.pumpAndSettle();
    expect(find.text('diegonais'), findsWidgets);
    profiles.failRename = false;
    await tester.ensureVisible(find.byTooltip(AppStrings.changeUsername));
    await tester.tap(find.byTooltip(AppStrings.changeUsername));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'disponible');
    await tester.tap(find.text(AppStrings.saveUsername));
    await tester.pumpAndSettle();
    expect(find.text('disponible'), findsWidgets);
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
    expect(find.byKey(const Key('main_nav_profile')), findsOneWidget);
    expect(find.byTooltip(AppStrings.signOut), findsNothing);
    expect(find.text(AppStrings.start), findsNothing);
    expect(find.text(AppStrings.loginTitle), findsNothing);
    expect(find.text(AppStrings.addAccount), findsNothing);
  });

  testWidgets('authenticated shell starts on home with visible navigation', (
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
    expect(find.byIcon(Icons.home), findsOneWidget);
    expect(find.text(AppStrings.homeTitle), findsOneWidget);
    expect(find.text(AppStrings.rankingTitle), findsOneWidget);
    expect(find.text(AppStrings.profileTitle), findsOneWidget);
    expect(find.byTooltip(AppStrings.hideNavigation), findsOneWidget);
  });

  testWidgets('switches main sections without pushing Navigator routes', (
    tester,
  ) async {
    final authRepository = _ControllableAuthRepository();
    final observer = _CountingNavigatorObserver();

    await _pumpGate(tester, authRepository, navigatorObserver: observer);
    authRepository.emit(
      const AuthUser(
        uid: 'uid-123',
        email: 'persona@example.com',
        isEmailVerified: true,
      ),
    );
    await tester.pumpAndSettle();
    final pushesAfterLogin = observer.pushCount;

    await tester.tap(find.byKey(const Key('main_nav_ranking')));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.generalRankingTitle), findsOneWidget);
    expect(find.text(AppStrings.emptyRankingTitle), findsOneWidget);
    expect(find.text(AppStrings.comingSoon), findsNothing);
    expect(find.byIcon(Icons.leaderboard), findsOneWidget);
    expect(observer.pushCount, pushesAfterLogin);

    await tester.tap(find.byKey(const Key('main_nav_ranking')));
    await tester.pumpAndSettle();
    expect(observer.pushCount, pushesAfterLogin);

    await tester.tap(find.byKey(const Key('main_nav_profile')));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.myProfileTitle), findsOneWidget);
    expect(find.text(AppStrings.profileTotalPoints), findsOneWidget);
    expect(observer.pushCount, pushesAfterLogin);

    await tester.tap(find.byKey(const Key('main_nav_home')));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.traffickingTitle), findsOneWidget);
    expect(find.byIcon(Icons.home), findsOneWidget);
    expect(observer.pushCount, pushesAfterLogin);
  });

  testWidgets('collapsing navigation keeps the selected section', (
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

    await tester.tap(find.byKey(const Key('main_nav_ranking')));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.leaderboard), findsOneWidget);

    await tester.tap(find.byTooltip(AppStrings.hideNavigation));
    await tester.pumpAndSettle();

    expect(find.byTooltip(AppStrings.showNavigation), findsOneWidget);
    expect(find.text(AppStrings.generalRankingTitle), findsOneWidget);
    expect(find.text(AppStrings.emptyRankingTitle), findsOneWidget);
    expect(find.text(AppStrings.homeTitle), findsNothing);

    await tester.drag(
      find.byKey(const Key('main_nav_toggle')),
      const Offset(0, -80),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip(AppStrings.showNavigation), findsOneWidget);

    await tester.tap(find.byTooltip(AppStrings.showNavigation));
    await tester.pumpAndSettle();

    expect(find.byTooltip(AppStrings.hideNavigation), findsOneWidget);
    expect(find.byIcon(Icons.leaderboard), findsOneWidget);
    expect(find.text(AppStrings.rankingTitle), findsWidgets);
  });

  testWidgets('existing educational routes still use Navigator from home', (
    tester,
  ) async {
    final authRepository = _ControllableAuthRepository();
    final observer = _CountingNavigatorObserver();

    await _pumpGate(tester, authRepository, navigatorObserver: observer);
    authRepository.emit(
      const AuthUser(
        uid: 'uid-123',
        email: 'persona@example.com',
        isEmailVerified: true,
      ),
    );
    await tester.pumpAndSettle();
    final pushesAfterLogin = observer.pushCount;

    await tester.tap(find.text(AppStrings.digitalSecurityTitle));
    await tester.pumpAndSettle();

    expect(observer.pushCount, greaterThan(pushesAfterLogin));
    expect(find.text(AppStrings.emptyCategoryGroup), findsOneWidget);
  });

  testWidgets('profile tab shows real profile data and category progress', (
    tester,
  ) async {
    final authRepository = _ControllableAuthRepository();
    final progressController = CategoryProgressController()
      ..hydrateTotalPointsFromProfile(uid: 'uid-123', totalPoints: 540)
      ..hydrateFromRecords(
        uid: 'uid-123',
        records: <CategoryProgressRecord>[
          _progressRecord(
            categoryId: 'relations_violence_digital',
            completedActivityIds: const <String>['a1', 'a2', 'a3'],
            viewedLessonPageIds: const <String>['p1', 'p2'],
          ),
        ],
      );

    await _pumpGate(
      tester,
      authRepository,
      userProfileRepository: _FakeUserProfileRepository(
        profile: const UserProfile(
          username: 'diegonais',
          usernameNormalized: 'diegonais',
          email: 'persona@example.com',
          role: UserProfileRole.user,
          totalPoints: 540,
          createdAt: null,
          updatedAt: null,
        ),
      ),
      progressController: progressController,
      contentRepository: const _ProfileContentRepository(),
    );
    authRepository.emit(
      const AuthUser(
        uid: 'uid-123',
        email: 'persona@example.com',
        isEmailVerified: true,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('main_nav_profile')));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.myProfileTitle), findsOneWidget);
    expect(find.text('diegonais'), findsWidgets);
    expect(find.text('persona@example.com'), findsOneWidget);
    expect(find.text(AppStrings.profileVerifiedEmail), findsOneWidget);
    expect(find.text(AppStrings.profileUserRole), findsNothing);
    expect(find.byTooltip(AppStrings.changeUsername), findsOneWidget);
    expect(find.text(AppStrings.profileTotalPoints), findsOneWidget);
    expect(find.text('540'), findsOneWidget);
    expect(find.text(AppStrings.myProgressTitle), findsOneWidget);
    expect(find.text(AppStrings.profileOverallProgress), findsOneWidget);
    expect(find.text('3%'), findsOneWidget);
    expect(find.text('3 / 12'), findsOneWidget);
    expect(find.text('2 / 8'), findsOneWidget);
    expect(find.text('Relaciones y violencia digital'), findsNothing);

    await tester.ensureVisible(
      find.byTooltip(AppStrings.profileChooseCategoryHint),
    );
    await tester.tap(find.byTooltip(AppStrings.profileChooseCategoryHint));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.digitalSecurityTitle).last);
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.profileCategoryBreakdown), findsOneWidget);
    expect(find.text('5%'), findsOneWidget);
    expect(find.text('3 / 6'), findsOneWidget);
    expect(find.text('2 / 4'), findsOneWidget);
    expect(find.text('Relaciones y violencia digital'), findsOneWidget);
    expect(find.text('Protección de cuentas y autenticación'), findsOneWidget);

    await tester.tap(find.byTooltip(AppStrings.profileClearCategoryFilter));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.profileCategoryBreakdown), findsNothing);
    expect(find.text('Relaciones y violencia digital'), findsNothing);
  });

  testWidgets('profile username editor updates the profile tab immediately', (
    tester,
  ) async {
    final authRepository = _ControllableAuthRepository();
    final profiles = _FakeUserProfileRepository();

    await _pumpGate(
      tester,
      authRepository,
      userProfileRepository: profiles,
      contentRepository: const _ProfileContentRepository(),
    );
    authRepository.emit(
      const AuthUser(
        uid: 'uid-123',
        email: 'persona@example.com',
        isEmailVerified: true,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('main_nav_profile')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byTooltip(AppStrings.changeUsername),
      120,
    );
    await tester.tap(find.byTooltip(AppStrings.changeUsername));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'NuevoNombre');
    await tester.tap(find.text(AppStrings.saveUsername));
    await tester.pumpAndSettle();

    expect(profiles.changedUid, 'uid-123');
    expect(find.text('NuevoNombre'), findsWidgets);
    expect(find.text('diegonais'), findsNothing);
  });

  testWidgets('profile sign out uses the auth repository', (tester) async {
    final authRepository = _ControllableAuthRepository();

    await _pumpGate(
      tester,
      authRepository,
      contentRepository: const _ProfileContentRepository(),
    );
    authRepository.emit(
      const AuthUser(
        uid: 'uid-123',
        email: 'persona@example.com',
        isEmailVerified: true,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('main_nav_profile')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(AppStrings.signOut));
    await tester.tap(find.text(AppStrings.signOut));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.signOutTitle), findsOneWidget);

    await tester.tap(find.text(AppStrings.signOut).last);
    await tester.pumpAndSettle();

    expect(authRepository.signOutCallCount, 1);
    expect(find.text(AppStrings.loginTitle), findsOneWidget);
  });

  testWidgets('profile keeps its state when the bottom navigation is hidden', (
    tester,
  ) async {
    final authRepository = _ControllableAuthRepository();

    await _pumpGate(
      tester,
      authRepository,
      contentRepository: const _ProfileContentRepository(),
    );
    authRepository.emit(
      const AuthUser(
        uid: 'uid-123',
        email: 'persona@example.com',
        isEmailVerified: true,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('main_nav_profile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(AppStrings.hideNavigation));
    await tester.pumpAndSettle();

    expect(find.byTooltip(AppStrings.showNavigation), findsOneWidget);
    expect(find.text(AppStrings.myProfileTitle), findsOneWidget);
    expect(find.text('diegonais'), findsWidgets);
    expect(find.text(AppStrings.homeTitle), findsNothing);
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

    await _openProfileTab(tester);
    await tester.ensureVisible(find.text(AppStrings.signOut));
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

    await _openProfileTab(tester);
    await tester.ensureVisible(find.text(AppStrings.signOut));
    await tester.tap(find.text(AppStrings.signOut));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text(AppStrings.signOut).last);
    await tester.pumpAndSettle();

    expect(authRepository.signOutCallCount, 1);
    expect(find.text(AppStrings.myProfileTitle), findsOneWidget);
    expect(find.text(AppStrings.start), findsNothing);
    expect(find.text(AppStrings.loginTitle), findsNothing);
    expect(find.text(AppStrings.signOutError), findsOneWidget);
  });

  testWidgets('opens profile tab and keeps session after canceling sign out', (
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

    await _openProfileTab(tester);

    expect(find.text(AppStrings.myProfileTitle), findsOneWidget);
    expect(find.byTooltip(AppStrings.changeUsername), findsOneWidget);
    expect(find.text('diegonais'), findsWidgets);
    expect(find.text('persona@example.com'), findsOneWidget);
    expect(find.text(AppStrings.profileRole), findsNothing);
    expect(find.text(AppStrings.profileUserRole), findsNothing);
    expect(find.text(AppStrings.profileTotalPoints), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text(AppStrings.profileVerifiedEmail), findsOneWidget);

    await tester.ensureVisible(find.text(AppStrings.signOut));
    await tester.tap(find.text(AppStrings.signOut));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text(AppStrings.signOutTitle), findsOneWidget);

    await tester.tap(find.text(AppStrings.cancel));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.myProfileTitle), findsOneWidget);
    expect(authRepository.signOutCallCount, 0);
  });

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
    await _openProfileTab(tester);

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
    await _openProfileTab(tester);

    expect(find.text('80'), findsOneWidget);
    expect(find.text('241'), findsNothing);
  });
}

Future<void> _openProfileTab(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('main_nav_profile')));
  await tester.pumpAndSettle();
}

Future<void> _pumpGate(
  WidgetTester tester,
  _ControllableAuthRepository authRepository, {
  UserProfileRepository? userProfileRepository,
  CategoryProgressController? progressController,
  NavigatorObserver? navigatorObserver,
  ContentRepository? contentRepository,
  LeaderboardRepository? leaderboardRepository,
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
        contentRepository: contentRepository ?? const _EmptyContentRepository(),
        leaderboardRepository:
            leaderboardRepository ?? _FakeLeaderboardRepository(),
      ),
      onGenerateRoute: router.onGenerateRoute,
      navigatorObservers: [?navigatorObserver],
    ),
  );
}

class _FakeLeaderboardRepository implements LeaderboardRepository {
  @override
  Stream<List<LeaderboardEntry>> watchTopEntries({
    int limit = LeaderboardRepository.defaultLimit,
  }) {
    return Stream<List<LeaderboardEntry>>.value(const <LeaderboardEntry>[]);
  }

  @override
  Future<LeaderboardUserPosition?> fetchUserPosition({
    required String uid,
    required String username,
    required int totalPoints,
  }) async {
    if (totalPoints <= 0) {
      return null;
    }
    return LeaderboardUserPosition(
      entry: LeaderboardEntry(
        userId: uid,
        username: username,
        totalPoints: totalPoints,
      ),
      position: 1,
    );
  }

  @override
  Future<void> ensureEntryForCurrentUser({
    required String uid,
    required String username,
    required int totalPoints,
  }) async {}
}

class _CountingNavigatorObserver extends NavigatorObserver {
  int pushCount = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushCount += 1;
    super.didPush(route, previousRoute);
  }
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

CategoryProgressRecord _progressRecord({
  required String categoryId,
  required List<String> completedActivityIds,
  required List<String> viewedLessonPageIds,
}) {
  final now = DateTime.utc(2026, 9, 15, 12);

  return CategoryProgressRecord(
    categoryId: categoryId,
    lessonId: categoryId,
    status: CategoryProgressStatus.inProgress,
    viewedLessonPageIds: viewedLessonPageIds,
    completedActivityIds: completedActivityIds,
    totalLessonPages: 4,
    totalActivities: 6,
    startedAt: now,
    lastActivityAt: now,
    completedAt: null,
    updatedAt: now,
    activities: const <String, ActivityProgressRecord>{},
    exams: const <String, ExamProgressRecord>{},
  );
}

class _ProfileContentRepository implements ContentRepository {
  const _ProfileContentRepository();

  @override
  Future<List<Category>> loadCategories() async {
    return const <Category>[
      Category(
        id: 'relations_violence_digital',
        title: 'Relaciones y violencia digital',
        description: 'Aprende a reconocer riesgos digitales.',
        iconName: 'shield_outlined',
        status: CategoryStatus.available,
        isEnabled: true,
        indicators: <String>['6 actividades'],
        objectives: <String>['Reconocer señales.'],
        lessonId: 'relations_violence',
      ),
      Category(
        id: 'account_protection_authentication',
        title: 'Protección de cuentas y autenticación',
        description: 'Protege tus cuentas.',
        iconName: 'lock_outline',
        status: CategoryStatus.available,
        isEnabled: true,
        indicators: <String>['6 actividades'],
        objectives: <String>['Proteger cuentas.'],
        lessonId: 'accounts_auth',
      ),
    ];
  }

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
