import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../data/repositories/content_repository.dart';
import '../data/repositories/local_content_repository.dart';
import 'app_router.dart';
import 'app_strings.dart';
import 'category_progress_controller.dart';

class YoMeCuidoApp extends StatelessWidget {
  YoMeCuidoApp({ContentRepository? contentRepository, Key? key})
    : this._(
        contentRepository: contentRepository ?? LocalContentRepository(),
        progressController: CategoryProgressController(),
        key: key,
      );

  YoMeCuidoApp._({
    required ContentRepository contentRepository,
    required CategoryProgressController progressController,
    super.key,
  }) : _router = AppRouter(
         contentRepository: contentRepository,
         progressController: progressController,
       );

  final AppRouter _router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.data(),
      initialRoute: AppRoutes.home,
      onGenerateRoute: _router.onGenerateRoute,
    );
  }
}
