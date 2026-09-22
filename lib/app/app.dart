import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/category_progress_repository.dart';
import '../data/repositories/content_repository.dart';
import '../data/repositories/firebase_auth_repository.dart';
import '../data/repositories/firestore_content_repository.dart';
import '../data/repositories/leaderboard_repository.dart';
import '../data/repositories/pending_quiz_attempt_repository.dart';
import '../data/repositories/user_profile_repository.dart';
import '../features/auth/auth_gate.dart';
import '../shared/services/connectivity_service.dart';
import '../shared/services/pending_quiz_attempt_sync_service.dart';
import '../shared/widgets/connectivity_status_view.dart';
import 'app_router.dart';
import 'app_strings.dart';
import 'category_progress_controller.dart';

class YoMeCuidoApp extends StatefulWidget {
  factory YoMeCuidoApp({
    ContentRepository? contentRepository,
    AuthRepository? authRepository,
    UserProfileRepository? userProfileRepository,
    LeaderboardRepository? leaderboardRepository,
    CategoryProgressController? progressController,
    ConnectivityService? connectivityService,
    Key? key,
  }) {
    final resolvedUserProfileRepository =
        userProfileRepository ?? UserProfileRepository();
    final resolvedAuthRepository =
        authRepository ??
        FirebaseAuthRepository(
          userProfileRepository: resolvedUserProfileRepository,
        );
    final resolvedProgressController =
        progressController ??
        CategoryProgressController(
          persistence: CategoryProgressRepository(),
          currentUserIdProvider: () => resolvedAuthRepository.currentUser?.uid,
        );
    final resolvedConnectivityService =
        connectivityService ?? ConnectivityService();
    final pendingQuizAttemptSyncService = PendingQuizAttemptSyncService(
      authRepository: resolvedAuthRepository,
      connectivityService: resolvedConnectivityService,
      progressController: resolvedProgressController,
      repository: SharedPreferencesPendingQuizAttemptRepository(),
    );

    return YoMeCuidoApp._(
      contentRepository: contentRepository ?? FirestoreContentRepository(),
      authRepository: resolvedAuthRepository,
      userProfileRepository: resolvedUserProfileRepository,
      leaderboardRepository:
          leaderboardRepository ?? FirestoreLeaderboardRepository(),
      progressController: resolvedProgressController,
      connectivityService: resolvedConnectivityService,
      pendingQuizAttemptSyncService: pendingQuizAttemptSyncService,
      key: key,
    );
  }

  YoMeCuidoApp._({
    required ContentRepository contentRepository,
    required AuthRepository authRepository,
    required UserProfileRepository userProfileRepository,
    required LeaderboardRepository leaderboardRepository,
    required CategoryProgressController progressController,
    required ConnectivityService connectivityService,
    required PendingQuizAttemptSyncService pendingQuizAttemptSyncService,
    super.key,
  }) : _router = AppRouter(
         contentRepository: contentRepository,
         authRepository: authRepository,
         progressController: progressController,
         connectivityService: connectivityService,
         pendingQuizAttemptSyncService: pendingQuizAttemptSyncService,
       ),
       _authRepository = authRepository,
       _userProfileRepository = userProfileRepository,
       _leaderboardRepository = leaderboardRepository,
       _contentRepository = contentRepository,
       _progressController = progressController,
       _connectivityService = connectivityService,
       _pendingQuizAttemptSyncService = pendingQuizAttemptSyncService;

  final AppRouter _router;
  final AuthRepository _authRepository;
  final UserProfileRepository _userProfileRepository;
  final LeaderboardRepository _leaderboardRepository;
  final ContentRepository _contentRepository;
  final CategoryProgressController _progressController;
  final ConnectivityService _connectivityService;
  final PendingQuizAttemptSyncService _pendingQuizAttemptSyncService;

  @override
  State<YoMeCuidoApp> createState() => _YoMeCuidoAppState();
}

class _YoMeCuidoAppState extends State<YoMeCuidoApp> {
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    unawaited(widget._connectivityService.start());
    unawaited(widget._pendingQuizAttemptSyncService.start());
  }

  @override
  void dispose() {
    widget._connectivityService.dispose();
    unawaited(widget._pendingQuizAttemptSyncService.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _scaffoldMessengerKey,
      theme: AppTheme.data(),
      builder: (context, child) {
        return ConnectivityStatusView(
          connectivityService: widget._connectivityService,
          scaffoldMessengerKey: _scaffoldMessengerKey,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: AuthGate(
        authRepository: widget._authRepository,
        userProfileRepository: widget._userProfileRepository,
        leaderboardRepository: widget._leaderboardRepository,
        progressController: widget._progressController,
        contentRepository: widget._contentRepository,
        connectivityService: widget._connectivityService,
      ),
      onGenerateRoute: widget._router.onGenerateRoute,
    );
  }
}
