import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../../app/app_router.dart';
import '../../app/app_strings.dart';
import '../../app/category_progress_controller.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/category.dart';
import '../../data/repositories/content_repository.dart';
import '../../shared/feedback/app_toast.dart';
import '../../shared/services/connectivity_service.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/category_card.dart';
import '../../shared/widgets/primary_button.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({
    required this.parentCategoryId,
    required this.title,
    required this.contentRepository,
    required this.progressController,
    required this.connectivityService,
    super.key,
  });

  final String parentCategoryId;
  final String title;
  final ContentRepository contentRepository;
  final CategoryProgressController progressController;
  final ConnectivityService connectivityService;

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

  void _openCategory(
    Category category, {
    required bool unlocked,
    required bool isOnline,
  }) {
    if (!isOnline) {
      AppToast.showInfo(context, AppStrings.categoryConnectionRequiredSnackBar);
      return;
    }

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
      title: widget.title,
      child: FutureBuilder<List<Category>>(
        future: _categoriesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData) {
            if (kDebugMode && snapshot.error != null) {
              debugPrint('[Categories] Content load failed.');
            }
            return _CategoriesLoadError(onRetry: _retry);
          }

          final categories = snapshot.data!
              .where(
                (category) =>
                    category.parentCategoryId == widget.parentCategoryId,
              )
              .toList(growable: false);

          if (categories.isEmpty) {
            return const _EmptyCategoryGroup();
          }

          return AnimatedBuilder(
            animation: Listenable.merge([
              widget.progressController,
              widget.connectivityService,
            ]),
            builder: (context, child) {
              final isOnline =
                  widget.connectivityService.status ==
                  ConnectivityStatus.online;
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
                        isUnlocked:
                            isOnline && _isCategoryUnlocked(categories, index),
                        isCompleted:
                            isOnline &&
                            _hasCompletedCategory(categories[index]),
                        lockedLabel: _lockedLabelFor(
                          categories[index],
                          isOnline: isOnline,
                        ),
                        onTap: () => _openCategory(
                          categories[index],
                          unlocked: _isCategoryUnlocked(categories, index),
                          isOnline: isOnline,
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
    return progress.subcategoryCompleted;
  }

  String _lockedLabelFor(Category category, {required bool isOnline}) {
    if (!isOnline) {
      return AppStrings.connectionRequired;
    }
    if (!category.isEnabled) {
      return AppStrings.comingSoon;
    }
    return AppStrings.categoryLockedByProgress;
  }
}

class _EmptyCategoryGroup extends StatelessWidget {
  const _EmptyCategoryGroup();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Text(
          AppStrings.emptyCategoryGroup,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
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
