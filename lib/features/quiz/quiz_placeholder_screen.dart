import 'package:flutter/material.dart';

import '../../app/app_strings.dart';
import '../../data/models/category.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/info_card.dart';
import '../../shared/widgets/category_card.dart';

class QuizPlaceholderScreen extends StatelessWidget {
  const QuizPlaceholderScreen({required this.category, super.key});

  final Category category;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: AppStrings.quizPlaceholderTitle,
      child: InfoCard(
        title: category.title,
        body: AppStrings.quizPlaceholderBody,
        icon: categoryIconFromName(category.iconName),
      ),
    );
  }
}
