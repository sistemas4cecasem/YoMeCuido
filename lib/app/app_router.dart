import 'package:flutter/material.dart';

import '../data/models/category.dart';
import '../data/repositories/content_repository.dart';
import '../features/categories/categories_screen.dart';
import '../features/category_detail/category_detail_screen.dart';
import '../features/lesson/lesson_screen.dart';
import '../features/quiz/quiz_placeholder_screen.dart';
import '../features/splash/welcome_screen.dart';
import '../shared/widgets/app_scaffold.dart';
import 'app_strings.dart';

abstract final class AppRoutes {
  static const home = '/';
  static const categories = '/categories';
  static const categoryDetail = '/category-detail';
  static const lesson = '/lesson';
  static const quizPlaceholder = '/quiz-placeholder';
}

class AppRouter {
  const AppRouter({required ContentRepository contentRepository})
    : _contentRepository = contentRepository;

  final ContentRepository _contentRepository;

  Route<dynamic> onGenerateRoute(RouteSettings settings) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (context) {
        return switch (settings.name) {
          AppRoutes.home || null => const WelcomeScreen(),
          AppRoutes.categories => CategoriesScreen(
            contentRepository: _contentRepository,
          ),
          AppRoutes.categoryDetail => CategoryDetailScreen(
            category: settings.arguments! as Category,
          ),
          AppRoutes.lesson => LessonScreen(
            category: settings.arguments! as Category,
            contentRepository: _contentRepository,
          ),
          AppRoutes.quizPlaceholder => QuizPlaceholderScreen(
            category: settings.arguments! as Category,
          ),
          _ => const _UnknownRoute(),
        };
      },
    );
  }
}

class _UnknownRoute extends StatelessWidget {
  const _UnknownRoute();

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      title: AppStrings.appName,
      child: Center(child: Text(AppStrings.contentLoadError)),
    );
  }
}
