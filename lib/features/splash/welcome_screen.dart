import 'package:flutter/material.dart';

import '../../app/app_router.dart';
import '../../app/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../shared/widgets/primary_button.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const logoAssetPath =
      'assets/images/brand/welcome_art_generated_v1.png';

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final contentWidth = constraints.maxWidth < 420
                ? constraints.maxWidth
                : 420.0;
            final actionBottomSpacing = constraints.maxHeight * 0.22;

            return Center(
              child: SizedBox(
                width: contentWidth,
                height: constraints.maxHeight,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: Semantics(
                        image: true,
                        label: AppStrings.appName,
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: Image.asset(
                            logoAssetPath,
                            key: const Key('welcome_logo'),
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: AppSpacing.screen,
                      right: AppSpacing.screen,
                      bottom: actionBottomSpacing,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            AppStrings.appTagline,
                            textAlign: TextAlign.center,
                            style: textTheme.bodyMedium?.copyWith(
                              color: context.colors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          PrimaryButton(
                            label: AppStrings.start,
                            semanticsLabel: AppStrings.start,
                            onPressed: () {
                              Navigator.of(
                                context,
                              ).pushNamed(AppRoutes.categories);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
