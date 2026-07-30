import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.child,
    this.title,
    this.actions,
    this.bottomNavigationBar,
    this.floatingActionButton,
    super.key,
  });

  final String? title;
  final List<Widget>? actions;
  final Widget child;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final appBarHeight =
        56.0 + ((textScale - 1).clamp(0.0, 1.0).toDouble() * 24.0);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: title == null
          ? null
          : AppBar(
              toolbarHeight: appBarHeight,
              title: Text(title!, maxLines: 2),
              actions: actions,
            ),
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        child: ColoredBox(
          color: colors.background,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSizing.maxContentWidth,
              ),
              child: Padding(padding: AppInsets.screen, child: child),
            ),
          ),
        ),
      ),
    );
  }
}
