import 'package:flutter/material.dart';

import '../../app/app_strings.dart';
import '../../data/models/category.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/info_card.dart';
import '../../shared/widgets/category_card.dart';

class CategoryDetailPlaceholderScreen extends StatelessWidget {
  const CategoryDetailPlaceholderScreen({required this.category, super.key});

  final Category category;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: AppStrings.temporaryDetailTitle,
      child: InfoCard(
        title: category.title,
        body: AppStrings.temporaryDetailBody,
        icon: categoryIconFromName(category.iconName),
      ),
    );
  }
}
