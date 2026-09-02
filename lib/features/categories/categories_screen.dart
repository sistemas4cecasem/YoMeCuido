import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../../app/app_router.dart';
import '../../app/app_strings.dart';
import '../../app/category_progress_controller.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/category.dart';
import '../../data/models/final_exam.dart';
import '../../data/repositories/content_repository.dart';
import '../../shared/feedback/app_toast.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/category_card.dart';
import '../../shared/widgets/primary_button.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({
    required this.contentRepository,
    required this.progressController,
    super.key,
  });

  final ContentRepository contentRepository;
  final CategoryProgressController progressController;

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  late Future<List<Category>> _categoriesFuture;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = widget.contentRepository.loadCategories();
  }

  void _retry() {
    setState(() {
      _categoriesFuture = widget.contentRepository.loadCategories();
    });
  }

  void _openCategory(Category category, {required bool unlocked}) {
    if (!category.isEnabled) {
      AppToast.showInfo(context, AppStrings.comingSoonSnackBar);
      return;
    }

    if (!unlocked) {
      AppToast.showInfo(context, AppStrings.categoryLockedByProgressSnackBar);
      return;
    }

    Navigator.of(
      context,
    ).pushNamed(AppRoutes.categoryDetail, arguments: category);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: AppStrings.digitalSecurityTitle,
      child: FutureBuilder<List<Category>>(
        future: _categoriesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError ||
              !snapshot.hasData ||
              snapshot.data!.isEmpty) {
            if (kDebugMode && snapshot.error != null) {
              debugPrint('Content load error: ${snapshot.error}');
            }
            return _CategoriesLoadError(onRetry: _retry);
          }

          final categories = snapshot.data!;

          return AnimatedBuilder(
            animation: widget.progressController,
            builder: (context, child) {
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (
                      var index = 0;
                      index < categories.length;
                      index += 1
                    ) ...[
                      CategoryCard(
                        key: ValueKey(categories[index].id),
                        category: categories[index],
                        isUnlocked: _isCategoryUnlocked(categories, index),
                        isCompleted: _hasCompletedCategory(categories[index]),
                        lockedLabel: _lockedLabelFor(categories[index]),
                        onTap: () => _openCategory(
                          categories[index],
                          unlocked: _isCategoryUnlocked(categories, index),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  bool _isCategoryUnlocked(List<Category> categories, int index) {
    final category = categories[index];
    if (!category.isEnabled) {
      return false;
    }
    if (index == 0) {
      return true;
    }

    return _hasCompletedCategory(categories[index - 1]);
  }

  bool _hasCompletedCategory(Category category) {
    final progress = widget.progressController.snapshotFor(category.id);
    final exam = category.lessonId == null
        ? null
        : FinalExamConfigs.forCategoryLesson(
            categoryId: category.id,
            lessonId: category.lessonId!,
          );
    final completedActivities =
        progress.totalActivities > 0 &&
        progress.completedActivities >= progress.totalActivities;
    final completedExam =
        exam == null || progress.examProgress[exam.id]?.isCompleted == true;

    return completedActivities && completedExam;
  }

  String _lockedLabelFor(Category category) {
    if (!category.isEnabled) {
      return AppStrings.comingSoon;
    }
    return AppStrings.categoryLockedByProgress;
  }
}

class _CategoriesLoadError extends StatelessWidget {
  const _CategoriesLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppStrings.contentLoadError,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: AppStrings.retry,
              icon: Icons.refresh_outlined,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
