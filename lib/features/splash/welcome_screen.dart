import 'package:flutter/material.dart';

import '../../app/app_router.dart';
import '../../app/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/primary_button.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const logoAssetPath = 'assets/images/brand/yomecuido_logo.png';

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return AppScaffold(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Semantics(
                      image: true,
                      label: AppStrings.appName,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppRadii.card),
                          border: Border.all(color: palette.border),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Image.asset(
                            logoAssetPath,
                            key: const Key('welcome_logo'),
                            height: 132,
                            width: 180,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    AppStrings.appName,
                    textAlign: TextAlign.center,
                    style: textTheme.displaySmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    AppStrings.appTagline,
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge?.copyWith(
                      color: palette.textMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  PrimaryButton(
                    label: AppStrings.start,
                    semanticsLabel: AppStrings.start,
                    onPressed: () {
                      Navigator.of(context).pushNamed(AppRoutes.categories);
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
