import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../../app/app_router.dart';
import '../../app/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/category.dart';
import '../../data/models/lesson_page.dart';
import '../../data/repositories/content_repository.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/lesson_progress_bar.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/secondary_button.dart';

class LessonScreen extends StatefulWidget {
  const LessonScreen({
    required this.category,
    required this.contentRepository,
    super.key,
  });

  final Category category;
  final ContentRepository contentRepository;

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  late Future<List<LessonPage>> _pagesFuture;
  int _pageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pagesFuture = widget.contentRepository.loadLessonPages(widget.category.id);
  }

  void _retry() {
    setState(() {
      _pageIndex = 0;
      _pagesFuture = widget.contentRepository.loadLessonPages(
        widget.category.id,
      );
    });
  }

  void _goBack() {
    if (_pageIndex == 0) {
      return;
    }

    setState(() {
      _pageIndex -= 1;
    });
  }

  void _goForward(List<LessonPage> pages) {
    final isLastPage = _pageIndex == pages.length - 1;

    if (isLastPage) {
      Navigator.of(
        context,
      ).pushNamed(AppRoutes.quiz, arguments: widget.category);
      return;
    }

    setState(() {
      _pageIndex += 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: widget.category.title,
      child: FutureBuilder<List<LessonPage>>(
        future: _pagesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError ||
              !snapshot.hasData ||
              snapshot.data!.isEmpty) {
            if (kDebugMode && snapshot.error != null) {
              debugPrint('Lesson load error: ${snapshot.error}');
            }
            return _LessonLoadError(onRetry: _retry);
          }

          final pages = [...snapshot.data!]
            ..sort((a, b) => a.order.compareTo(b.order));
          final page = pages[_pageIndex.clamp(0, pages.length - 1)];
          final step = _pageIndex + 1;
          final isFirstPage = _pageIndex == 0;
          final isLastPage = _pageIndex == pages.length - 1;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '$step de ${pages.length}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              LessonProgressBar(currentStep: step, totalSteps: pages.length),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: SingleChildScrollView(child: _TheoryCard(page: page)),
              ),
              const SizedBox(height: AppSpacing.lg),
              _LessonActions(
                isFirstPage: isFirstPage,
                isLastPage: isLastPage,
                onPrevious: _goBack,
                onNext: () => _goForward(pages),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LessonActions extends StatelessWidget {
  const _LessonActions({
    required this.isFirstPage,
    required this.isLastPage,
    required this.onPrevious,
    required this.onNext,
  });

  final bool isFirstPage;
  final bool isLastPage;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);

    return LayoutBuilder(
      builder: (context, constraints) {
        final shouldStack = constraints.maxWidth < 360 || textScale > 1.2;
        final previousButton = SecondaryButton(
          label: AppStrings.previous,
          icon: Icons.arrow_back_outlined,
          onPressed: isFirstPage ? null : onPrevious,
        );
        final nextButton = PrimaryButton(
          label: isLastPage ? AppStrings.startActivities : AppStrings.next,
          icon: isLastPage
              ? Icons.play_arrow_outlined
              : Icons.arrow_forward_outlined,
          onPressed: onNext,
        );

        if (shouldStack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              previousButton,
              const SizedBox(height: AppSpacing.sm),
              nextButton,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: previousButton),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: nextButton),
          ],
        );
      },
    );
  }
}

class _TheoryCard extends StatelessWidget {
  const _TheoryCard({required this.page});

  final LessonPage page;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.menu_book_outlined, color: colors.orangeDark, size: 32),
            const SizedBox(height: AppSpacing.md),
            Text(page.title, style: textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.md),
            Text(page.body, style: textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}

class _LessonLoadError extends StatelessWidget {
  const _LessonLoadError({required this.onRetry});

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
