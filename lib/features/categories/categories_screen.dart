import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../../app/app_router.dart';
import '../../app/app_strings.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/category.dart';
import '../../data/repositories/content_repository.dart';
import '../../shared/feedback/app_toast.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/category_card.dart';
import '../../shared/widgets/primary_button.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({required this.contentRepository, super.key});

  final ContentRepository contentRepository;

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

  void _openCategory(Category category) {
    if (!category.isEnabled) {
      AppToast.showInfo(context, AppStrings.comingSoonSnackBar);
      return;
    }

    Navigator.of(
      context,
    ).pushNamed(AppRoutes.categoryDetail, arguments: category);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: AppStrings.categoriesTitle,
      child: FutureBuilder<List<Category>>(
        future: _categoriesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData) {
            if (kDebugMode && snapshot.error != null) {
              debugPrint('Content load error: ${snapshot.error}');
            }
            return _CategoriesLoadError(onRetry: _retry);
          }

          final categories = snapshot.data!;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final category in categories) ...[
                  CategoryCard(
                    key: ValueKey(category.id),
                    category: category,
                    onTap: () => _openCategory(category),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ],
            ),
          );
        },
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
