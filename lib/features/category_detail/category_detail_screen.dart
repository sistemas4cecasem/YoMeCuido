import 'package:flutter/material.dart';

import '../../app/app_router.dart';
import '../../app/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/category.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/category_card.dart';
import '../../shared/widgets/info_card.dart';
import '../../shared/widgets/primary_button.dart';

class CategoryDetailScreen extends StatelessWidget {
  const CategoryDetailScreen({required this.category, super.key});

  final Category category;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return AppScaffold(
      title: AppStrings.categoryDetailTitle,
      bottomNavigationBar: _StartLessonBar(category: category),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(category: category),
            const SizedBox(height: AppSpacing.lg),
            Text(category.description, style: textTheme.bodyLarge),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final indicator in category.indicators)
                  _IndicatorChip(label: indicator),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(AppStrings.objectivesTitle, style: textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Card(
              child: Padding(
                padding: AppInsets.card,
                child: Column(
                  children: [
                    for (final objective in category.objectives) ...[
                      _ObjectiveRow(text: objective),
                      if (objective != category.objectives.last)
                        Divider(height: AppSpacing.lg, color: colors.border),
                    ],
                  ],
                ),
              ),
            ),
            if (category.warning != null) ...[
              const SizedBox(height: AppSpacing.lg),
              InfoCard(
                title: AppStrings.sensitiveContentWarningTitle,
                body: category.warning!,
                icon: Icons.info_outline,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.category});

  final Category category;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: colors.orangeSoft,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: colors.border),
          ),
          child: Semantics(
            label: category.title,
            child: Icon(
              categoryIconFromName(category.iconName),
              size: 34,
              color: colors.orangeDark,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: Text(category.title, style: textTheme.headlineMedium)),
      ],
    );
  }
}

class _StartLessonBar extends StatelessWidget {
  const _StartLessonBar({required this.category});

  final Category category;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.center,
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSizing.maxContentWidth,
            ),
            child: Padding(
              padding: AppInsets.screen,
              child: PrimaryButton(
                label: AppStrings.startLesson,
                icon: Icons.arrow_forward_outlined,
                onPressed: () {
                  Navigator.of(
                    context,
                  ).pushNamed(AppRoutes.lesson, arguments: category);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IndicatorChip extends StatelessWidget {
  const _IndicatorChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }
}

class _ObjectiveRow extends StatelessWidget {
  const _ObjectiveRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.check_circle_outline, color: colors.success, size: 22),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
        ),
      ],
    );
  }
}
