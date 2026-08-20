import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'app_background.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.child,
    this.title,
    this.actions,
    this.automaticallyImplyLeading = true,
    this.bottomNavigationBar,
    this.floatingActionButton,
    super.key,
  });

  final String? title;
  final List<Widget>? actions;
  final bool automaticallyImplyLeading;
  final Widget child;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final appBarHeight =
        56.0 + ((textScale - 1).clamp(0.0, 1.0).toDouble() * 24.0);
    final contentPadding = EdgeInsets.only(
      left: AppSpacing.screen,
      top: AppSpacing.lg,
      right: AppSpacing.screen,
      bottom: bottomNavigationBar == null ? AppSpacing.lg : 0,
    );

    return Scaffold(
      backgroundColor: colors.background,
      appBar: title == null
          ? null
          : AppBar(
              toolbarHeight: appBarHeight,
              automaticallyImplyLeading: automaticallyImplyLeading,
              backgroundColor: colors.background.withValues(alpha: 0.88),
              title: Text(title!, maxLines: 2),
              actions: actions,
            ),
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        bottom: bottomNavigationBar == null,
        child: AppBackground(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSizing.maxContentWidth,
              ),
              child: Padding(padding: contentPadding, child: child),
            ),
          ),
        ),
      ),
    );
  }
}
