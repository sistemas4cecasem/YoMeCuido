import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/category_progress_repository.dart';
import '../data/repositories/content_repository.dart';
import '../data/repositories/firebase_auth_repository.dart';
import '../data/repositories/firestore_content_repository.dart';
import '../data/repositories/user_profile_repository.dart';
import '../features/auth/auth_gate.dart';
import 'app_router.dart';
import 'app_strings.dart';
import 'category_progress_controller.dart';

class YoMeCuidoApp extends StatelessWidget {
  factory YoMeCuidoApp({
    ContentRepository? contentRepository,
    AuthRepository? authRepository,
    UserProfileRepository? userProfileRepository,
    CategoryProgressController? progressController,
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

    return YoMeCuidoApp._(
      contentRepository: contentRepository ?? FirestoreContentRepository(),
      authRepository: resolvedAuthRepository,
      userProfileRepository: resolvedUserProfileRepository,
      progressController: resolvedProgressController,
      key: key,
    );
  }

  YoMeCuidoApp._({
    required ContentRepository contentRepository,
    required AuthRepository authRepository,
    required UserProfileRepository userProfileRepository,
    required CategoryProgressController progressController,
    super.key,
  }) : _router = AppRouter(
         contentRepository: contentRepository,
         authRepository: authRepository,
         progressController: progressController,
       ),
       _authRepository = authRepository,
       _userProfileRepository = userProfileRepository,
       _progressController = progressController;

  final AppRouter _router;
  final AuthRepository _authRepository;
  final UserProfileRepository _userProfileRepository;
  final CategoryProgressController _progressController;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.data(),
      home: AuthGate(
        authRepository: _authRepository,
        userProfileRepository: _userProfileRepository,
        progressController: _progressController,
      ),
      onGenerateRoute: _router.onGenerateRoute,
    );
  }
}
