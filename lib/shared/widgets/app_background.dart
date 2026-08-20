import 'package:flutter/material.dart';

import '../../app/app_assets.dart';
import '../../core/theme/app_colors.dart';

class AppBackground extends StatelessWidget {
  const AppBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        image: const DecorationImage(
          image: AssetImage(AppAssets.appBackground),
          fit: BoxFit.cover,
        ),
      ),
      child: child,
    );
  }
}
