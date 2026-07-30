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
    final textTheme = Theme.of(context).textTheme;

    return AppScaffold(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final logoCardWidth = constraints.maxWidth < 360
              ? constraints.maxWidth
              : 360.0;
          final logoHeight = constraints.maxWidth < 360 ? 228.0 : 252.0;

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
                      child: SizedBox(
                        width: logoCardWidth,
                        child: Image.asset(
                          logoAssetPath,
                          key: const Key('welcome_logo'),
                          height: logoHeight,
                          width: double.infinity,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    AppStrings.appTagline,
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge?.copyWith(
                      color: context.colors.textSecondary,
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
