import 'package:flutter/material.dart';

import '../data/models/category.dart';
import '../data/models/learning_activity.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/content_repository.dart';
import '../features/auth/forgot_password_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/activities/activities_menu_screen.dart';
import '../features/categories/categories_screen.dart';
import '../features/category_detail/category_detail_screen.dart';
import '../features/category_summary/category_summary_screen.dart';
import '../features/high_level_categories/high_level_categories_screen.dart';
import '../features/lesson/lesson_screen.dart';
import '../features/quiz/quiz_screen.dart';
import '../features/splash/welcome_screen.dart';
import '../shared/widgets/app_scaffold.dart';
import 'app_strings.dart';
import 'category_progress_controller.dart';

abstract final class AppRoutes {
  static const home = '/';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const highLevelCategories = '/high-level-categories';
  static const categories = '/categories';
  static const categoryDetail = '/category-detail';
  static const lesson = '/lesson';
  static const activities = '/activities';
  static const quiz = '/quiz';
  static const categorySummary = '/category-summary';
}

class AppRouter {
  const AppRouter({
    required ContentRepository contentRepository,
    required AuthRepository authRepository,
    required CategoryProgressController progressController,
  }) : _contentRepository = contentRepository,
       _authRepository = authRepository,
       _progressController = progressController;

  final ContentRepository _contentRepository;
  final AuthRepository _authRepository;
  final CategoryProgressController _progressController;

  Route<dynamic> onGenerateRoute(RouteSettings settings) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (context) {
        return switch (settings.name) {
          AppRoutes.home || null => const WelcomeScreen(),
          AppRoutes.login => LoginScreen(authRepository: _authRepository),
          AppRoutes.register => RegisterScreen(authRepository: _authRepository),
          AppRoutes.forgotPassword => ForgotPasswordScreen(
            authRepository: _authRepository,
          ),
          AppRoutes.highLevelCategories => const HighLevelCategoriesScreen(),
          AppRoutes.categories => CategoriesScreen(
            contentRepository: _contentRepository,
          ),
          AppRoutes.categoryDetail => CategoryDetailScreen(
            category: settings.arguments! as Category,
            progressController: _progressController,
          ),
          AppRoutes.lesson => LessonScreen(
            category: settings.arguments! as Category,
            contentRepository: _contentRepository,
            progressController: _progressController,
          ),
          AppRoutes.activities => ActivitiesMenuScreen(
            category: settings.arguments! as Category,
            contentRepository: _contentRepository,
            progressController: _progressController,
          ),
          AppRoutes.quiz => _buildQuizScreen(settings),
          AppRoutes.categorySummary => CategorySummaryScreen(
            category: settings.arguments! as Category,
            progressController: _progressController,
          ),
          _ => const _UnknownRoute(),
        };
      },
    );
  }

  Widget _buildQuizScreen(RouteSettings settings) {
    final arguments = settings.arguments! as QuizRouteArguments;

    return QuizScreen(
      category: arguments.category,
      activity: arguments.activity,
      contentRepository: _contentRepository,
      progressController: _progressController,
    );
  }
}

class QuizRouteArguments {
  const QuizRouteArguments({required this.category, required this.activity});

  final Category category;
  final LearningActivity activity;
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
