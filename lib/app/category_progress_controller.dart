import 'package:flutter/foundation.dart';

import '../data/models/quiz_result.dart';

class CategoryProgressController extends ChangeNotifier {
  final Map<String, _MutableCategoryProgress> _progressByCategory = {};

  CategoryProgressSnapshot snapshotFor(String categoryId) {
    return _entryFor(categoryId).snapshot;
  }

  void markTheoryPageViewed({
    required String categoryId,
    required String pageId,
    required int totalPages,
  }) {
    final progress = _entryFor(categoryId)..theoryTotal = totalPages;
    final added = progress.viewedTheoryPageIds.add(pageId);
    if (added) {
      notifyListeners();
    }
  }

  void startActivityAttempt({
    required String categoryId,
    required int totalActivities,
  }) {
    final progress = _entryFor(categoryId);
    progress
      ..activityTotal = totalActivities
      ..completedActivityIndexes.clear()
      ..correctAnswers = 0
      ..result = null;
    notifyListeners();
  }

  void recordActivityAnswer({
    required String categoryId,
    required int activityIndex,
    required int correctAnswers,
    required int totalActivities,
    QuizResult? result,
  }) {
    final progress = _entryFor(categoryId)..activityTotal = totalActivities;
    progress
      ..completedActivityIndexes.add(activityIndex)
      ..correctAnswers = correctAnswers
      ..result = result ?? progress.result;
    notifyListeners();
  }

  void resetCategory(String categoryId) {
    final progress = _entryFor(categoryId);
    progress
      ..viewedTheoryPageIds.clear()
      ..completedActivityIndexes.clear()
      ..correctAnswers = 0
      ..result = null;
    notifyListeners();
  }

  _MutableCategoryProgress _entryFor(String categoryId) {
    return _progressByCategory.putIfAbsent(
      categoryId,
      _MutableCategoryProgress.new,
    );
  }
}

class CategoryProgressSnapshot {
  const CategoryProgressSnapshot({
    required this.viewedTheoryPages,
    required this.totalTheoryPages,
    required this.completedActivities,
    required this.totalActivities,
    required this.correctAnswers,
    required this.result,
  });

  final int viewedTheoryPages;
  final int totalTheoryPages;
  final int completedActivities;
  final int totalActivities;
  final int correctAnswers;
  final QuizResult? result;

  bool get hasCompletedTheory => viewedTheoryPages >= totalTheoryPages;

  bool get hasCompletedActivities => completedActivities >= totalActivities;

  bool get hasResult => result != null;

  int get overallPercentage {
    final totalSteps = totalTheoryPages + totalActivities;
    if (totalSteps == 0) {
      return 0;
    }

    return (((viewedTheoryPages + completedActivities) / totalSteps) * 100)
        .round()
        .clamp(0, 100);
  }

  double get overallProgress => overallPercentage / 100;
}

class _MutableCategoryProgress {
  static const _defaultActivityTotal = 12;

  int theoryTotal = 4;
  int activityTotal = _defaultActivityTotal;
  int correctAnswers = 0;
  QuizResult? result;
  final Set<String> viewedTheoryPageIds = <String>{};
  final Set<int> completedActivityIndexes = <int>{};

  CategoryProgressSnapshot get snapshot {
    return CategoryProgressSnapshot(
      viewedTheoryPages: viewedTheoryPageIds.length.clamp(0, theoryTotal),
      totalTheoryPages: theoryTotal,
      completedActivities: completedActivityIndexes.length.clamp(
        0,
        activityTotal,
      ),
      totalActivities: activityTotal,
      correctAnswers: correctAnswers,
      result: result,
    );
  }
}
