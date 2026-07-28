import 'package:flutter/material.dart';

import '../shared/widgets/app_scaffold.dart';
import '../shared/widgets/info_card.dart';
import 'app_strings.dart';

abstract final class AppRoutes {
  static const home = '/';
}

abstract final class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (context) {
        return switch (settings.name) {
          AppRoutes.home || null => const _FoundationRoute(),
          _ => const _FoundationRoute(),
        };
      },
    );
  }
}

class _FoundationRoute extends StatelessWidget {
  const _FoundationRoute();

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      title: AppStrings.appName,
      child: InfoCard(
        title: AppStrings.foundationTitle,
        body: AppStrings.foundationDescription,
        icon: Icons.shield_outlined,
      ),
    );
  }
}
