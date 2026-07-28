import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../data/repositories/content_repository.dart';
import '../data/repositories/local_content_repository.dart';
import 'app_router.dart';
import 'app_strings.dart';

class YoMeCuidoApp extends StatelessWidget {
  YoMeCuidoApp({ContentRepository? contentRepository, super.key})
    : _router = AppRouter(
        contentRepository: contentRepository ?? LocalContentRepository(),
      );

  final AppRouter _router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      initialRoute: AppRoutes.home,
      onGenerateRoute: _router.onGenerateRoute,
    );
  }
}
