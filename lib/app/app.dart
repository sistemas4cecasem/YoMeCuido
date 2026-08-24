import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/category_progress_repository.dart';
import '../data/repositories/content_repository.dart';
import '../data/repositories/firebase_auth_repository.dart';
import '../data/repositories/local_content_repository.dart';
import '../features/auth/auth_gate.dart';
import 'app_router.dart';
import 'app_strings.dart';
import 'category_progress_controller.dart';

class YoMeCuidoApp extends StatelessWidget {
  factory YoMeCuidoApp({
    ContentRepository? contentRepository,
    AuthRepository? authRepository,
    CategoryProgressController? progressController,
    Key? key,
  }) {
    final resolvedAuthRepository = authRepository ?? FirebaseAuthRepository();
    final resolvedProgressController =
        progressController ??
        CategoryProgressController(
          persistence: CategoryProgressRepository(),
          currentUserIdProvider: () => resolvedAuthRepository.currentUser?.uid,
        );

    return YoMeCuidoApp._(
      contentRepository: contentRepository ?? LocalContentRepository(),
      authRepository: resolvedAuthRepository,
      progressController: resolvedProgressController,
      key: key,
    );
  }

  YoMeCuidoApp._({
    required ContentRepository contentRepository,
    required AuthRepository authRepository,
    required CategoryProgressController progressController,
    super.key,
  }) : _router = AppRouter(
         contentRepository: contentRepository,
         authRepository: authRepository,
         progressController: progressController,
       ),
       _authRepository = authRepository,
       _progressController = progressController;

  final AppRouter _router;
  final AuthRepository _authRepository;
  final CategoryProgressController _progressController;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.data(),
      home: AuthGate(
        authRepository: _authRepository,
        progressController: _progressController,
      ),
      onGenerateRoute: _router.onGenerateRoute,
    );
  }
}
