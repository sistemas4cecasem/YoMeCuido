import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/content_repository.dart';
import '../data/repositories/firebase_auth_repository.dart';
import '../data/repositories/local_content_repository.dart';
import '../features/auth/auth_gate.dart';
import 'app_router.dart';
import 'app_strings.dart';
import 'category_progress_controller.dart';

class YoMeCuidoApp extends StatelessWidget {
  YoMeCuidoApp({
    ContentRepository? contentRepository,
    AuthRepository? authRepository,
    Key? key,
  }) : this._(
         contentRepository: contentRepository ?? LocalContentRepository(),
         authRepository: authRepository ?? FirebaseAuthRepository(),
         progressController: CategoryProgressController(),
         key: key,
       );

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
       _authRepository = authRepository;

  final AppRouter _router;
  final AuthRepository _authRepository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.data(),
      home: AuthGate(authRepository: _authRepository),
      onGenerateRoute: _router.onGenerateRoute,
    );
  }
}
