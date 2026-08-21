import 'package:flutter/material.dart';

import '../../app/app_router.dart';
import '../../app/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/repositories/auth_repository.dart';
import '../auth/sign_out_button.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/secondary_button.dart';

enum WelcomeMode { access, learning }

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    this.mode = WelcomeMode.access,
    this.authRepository,
    super.key,
  });

  final WelcomeMode mode;
  final AuthRepository? authRepository;

  static const logoAssetPath =
      'assets/images/brand/welcome_art_generated_v1.png';
  static const _actionsMaxWidth = 320.0;
  static const _actionsBottomRatio = 0.19;

  @override
  Widget build(BuildContext context) {
    final isLearningMode = mode == WelcomeMode.learning;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final contentWidth = constraints.maxWidth < 420
                ? constraints.maxWidth
                : 420.0;
            final actionBottomSpacing =
                constraints.maxHeight * _actionsBottomRatio;
            final actionsWidth =
                contentWidth - (AppSpacing.screen * 2) < _actionsMaxWidth
                ? contentWidth - (AppSpacing.screen * 2)
                : _actionsMaxWidth;

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
                    if (authRepository != null)
                      Positioned(
                        top: AppSpacing.xs,
                        right: AppSpacing.screen,
                        child: SignOutButton(authRepository: authRepository!),
                      ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: actionBottomSpacing,
                      child: Center(
                        child: SizedBox(
                          width: actionsWidth,
                          child: _CompactActionTheme(
                            child: _WelcomeActions(
                              isLearningMode: isLearningMode,
                            ),
                          ),
                        ),
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

class _CompactActionTheme extends StatelessWidget {
  const _CompactActionTheme({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compactTextStyle = theme.textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w600,
    );

    final compactStyle = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(
        Size.fromHeight(AppSizing.primaryButtonHeight),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
      ),
      textStyle: WidgetStatePropertyAll(compactTextStyle),
    );

    return Theme(
      data: theme.copyWith(
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: _mergeButtonStyle(
            theme.elevatedButtonTheme.style,
            compactStyle,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: _mergeButtonStyle(
            theme.outlinedButtonTheme.style,
            compactStyle,
          ),
        ),
      ),
      child: child,
    );
  }

  ButtonStyle _mergeButtonStyle(ButtonStyle? base, ButtonStyle compactStyle) {
    return (base ?? const ButtonStyle()).copyWith(
      minimumSize: compactStyle.minimumSize,
      padding: compactStyle.padding,
      textStyle: compactStyle.textStyle,
    );
  }
}

class _WelcomeActions extends StatelessWidget {
  const _WelcomeActions({required this.isLearningMode});

  final bool isLearningMode;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrimaryButton(
          label: isLearningMode ? AppStrings.start : AppStrings.loginTitle,
          icon: isLearningMode ? null : Icons.login_outlined,
          semanticsLabel: isLearningMode
              ? AppStrings.start
              : AppStrings.loginTitle,
          onPressed: () {
            Navigator.of(context).pushNamed(
              isLearningMode ? AppRoutes.highLevelCategories : AppRoutes.login,
            );
          },
        ),
        if (!isLearningMode) ...[
          const SizedBox(height: AppSpacing.sm),
          SecondaryButton(
            label: AppStrings.addAccount,
            icon: Icons.person_add_alt_1_outlined,
            semanticsLabel: AppStrings.addAccount,
            onPressed: () {
              Navigator.of(context).pushNamed(AppRoutes.register);
            },
          ),
        ],
      ],
    );
  }
}
