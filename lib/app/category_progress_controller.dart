import 'package:flutter/foundation.dart';

import '../data/models/category_progress.dart';
import '../data/models/quiz_result.dart';
import '../data/repositories/category_progress_repository.dart';

enum ProgressHydrationStatus { notStarted, loading, loaded, error }

class CategoryProgressController extends ChangeNotifier {
  CategoryProgressController({
    CategoryProgressPersistence? persistence,
    String? Function()? currentUserIdProvider,
  }) : _persistence = persistence,
       _currentUserIdProvider = currentUserIdProvider;

  final CategoryProgressPersistence? _persistence;
  final String? Function()? _currentUserIdProvider;
  final Map<String, _MutableCategoryProgress> _progressByCategory = {};
  ProgressHydrationStatus _hydrationStatus = ProgressHydrationStatus.notStarted;
  String? _hydratedUserId;
  Object? _hydrationError;
  int _hydrationGeneration = 0;
  Future<void>? _activeHydration;

  ProgressHydrationStatus get hydrationStatus => _hydrationStatus;

  String? get hydratedUserId => _hydratedUserId;

  Object? get hydrationError => _hydrationError;

  bool hasResolvedProgressFor(String uid) {
    return _hydratedUserId == uid &&
        (_hydrationStatus == ProgressHydrationStatus.loaded ||
            _hydrationStatus == ProgressHydrationStatus.error);
  }

  Future<void> loadPersistedProgressForUser(String uid) {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) {
      clearForSignedOutUser();
      return Future<void>.value();
    }

    if (_hydratedUserId == normalizedUid &&
        _hydrationStatus == ProgressHydrationStatus.loading) {
      return _activeHydration ?? Future<void>.value();
    }

    if (hasResolvedProgressFor(normalizedUid)) {
      return Future<void>.value();
    }

    _hydrationGeneration += 1;
    final generation = _hydrationGeneration;
    final previousUserId = _hydratedUserId;
    _hydratedUserId = normalizedUid;
    _hydrationStatus = ProgressHydrationStatus.loading;
    _hydrationError = null;
    if (previousUserId != normalizedUid) {
      _progressByCategory.clear();
    }
    notifyListeners();

    final persistence = _persistence;
    if (persistence == null) {
      _hydrationStatus = ProgressHydrationStatus.loaded;
      notifyListeners();
      return Future<void>.value();
    }

    final hydration = _hydrateFromPersistence(
      persistence: persistence,
      uid: normalizedUid,
      generation: generation,
    );
    _activeHydration = hydration;
    return hydration;
  }

  void hydrateFromRecords({
    required String uid,
    required Iterable<CategoryProgressRecord> records,
  }) {
    _hydrationGeneration += 1;
    _hydrateRecords(uid: uid.trim(), records: records);
    _hydrationStatus = ProgressHydrationStatus.loaded;
    _hydrationError = null;
    notifyListeners();
  }

  void clearForSignedOutUser() {
    _hydrationGeneration += 1;
    _activeHydration = null;
    _hydratedUserId = null;
    _hydrationStatus = ProgressHydrationStatus.notStarted;
    _hydrationError = null;
    if (_progressByCategory.isEmpty) {
      return;
    }
    _progressByCategory.clear();
    notifyListeners();
  }

  CategoryProgressSnapshot snapshotFor(String categoryId) {
    return _entryFor(categoryId).snapshot;
  }

  Future<void> markTheoryPageViewed({
    required String categoryId,
    required String lessonId,
    required String pageId,
    required int totalPages,
  }) async {
    final progress = _entryFor(categoryId)..theoryTotal = totalPages;
    final added = progress.viewedTheoryPageIds.add(pageId);
    if (added) {
      if (progress.status != CategoryProgressStatus.completed) {
        progress.status = CategoryProgressStatus.inProgress;
      }
      progress.updatedAt = DateTime.now();
      notifyListeners();
      await _persistForCurrentUser((uid) {
        return _persistence!.markTheoryPageViewed(
          uid: uid,
          categoryId: categoryId,
          lessonId: lessonId,
          pageId: pageId,
          totalLessonPages: totalPages,
          totalActivities: progress.activityTotal,
        );
      });
    }
  }

  Future<void> startActivityAttempt({
    required String categoryId,
    required String lessonId,
    required int totalActivities,
  }) async {
    final progress = _entryFor(categoryId);
    progress
      ..activityTotal = totalActivities
      ..completedActivityIds.clear()
      ..correctAnswers = 0
      ..attemptCount += 1
      ..status = CategoryProgressStatus.inProgress
      ..result = null
      ..lastActivityAt = null
      ..completedAt = null
      ..updatedAt = DateTime.now();
    progress.latestAnswers.clear();
    notifyListeners();

    await _persistForCurrentUser((uid) {
      return _persistence!.startActivityAttempt(
        uid: uid,
        categoryId: categoryId,
        lessonId: lessonId,
        totalLessonPages: progress.theoryTotal,
        totalActivities: totalActivities,
      );
    });
  }

  Future<void> recordActivityAnswer({
    required String categoryId,
    required String lessonId,
    required String activityId,
    required String answer,
    required bool isCorrect,
    required int correctAnswers,
    required int totalActivities,
    QuizResult? result,
  }) async {
    final progress = _entryFor(categoryId)..activityTotal = totalActivities;
    final answeredAt = DateTime.now();
    progress
      ..completedActivityIds.add(activityId)
      ..correctAnswers = correctAnswers
      ..status = result == null
          ? CategoryProgressStatus.inProgress
          : CategoryProgressStatus.completed
      ..result = result ?? progress.result
      ..lastActivityAt = answeredAt
      ..completedAt = result == null ? null : answeredAt
      ..updatedAt = answeredAt;
    progress.latestAnswers[activityId] = CategoryProgressAnswer(
      answer: answer,
      isCorrect: isCorrect,
      answeredAt: answeredAt,
    );
    notifyListeners();

    await _persistForCurrentUser((uid) {
      return _persistence!.recordActivityAnswer(
        uid: uid,
        categoryId: categoryId,
        lessonId: lessonId,
        activityId: activityId,
        answer: answer,
        isCorrect: isCorrect,
        correctAnswers: correctAnswers,
        totalLessonPages: progress.theoryTotal,
        totalActivities: totalActivities,
        isCompleted: result != null,
      );
    });
  }

  void resetCategory(String categoryId) {
    final progress = _entryFor(categoryId);
    progress
      ..viewedTheoryPageIds.clear()
      ..completedActivityIds.clear()
      ..correctAnswers = 0
      ..status = CategoryProgressStatus.notStarted
      ..result = null
      ..lastActivityAt = null
      ..completedAt = null
      ..updatedAt = DateTime.now();
    progress.latestAnswers.clear();
    notifyListeners();
  }

  Future<void> _persistForCurrentUser(
    Future<void> Function(String uid) operation,
  ) async {
    if (_persistence == null) {
      return;
    }

    final uid = _currentUserIdProvider?.call();
    if (uid == null || uid.trim().isEmpty) {
      if (kDebugMode) {
        debugPrint(
          '[CategoryProgress] Persistence skipped: no authenticated user.',
        );
      }
      return;
    }

    try {
      await operation(uid);
    } on CategoryProgressException catch (exception) {
      exception.logForDebug();
    } catch (error, stackTrace) {
      if (!kDebugMode) {
        return;
      }
      debugPrint('[CategoryProgress] Unexpected persistence error: $error');
      debugPrint('[CategoryProgress] StackTrace: $stackTrace');
    }
  }

  Future<void> _hydrateFromPersistence({
    required CategoryProgressPersistence persistence,
    required String uid,
    required int generation,
  }) async {
    try {
      final records = await persistence.fetchAllProgress(uid: uid);
      if (!_shouldApplyHydration(uid: uid, generation: generation)) {
        return;
      }

      _hydrateRecords(uid: uid, records: records);
      _hydrationStatus = ProgressHydrationStatus.loaded;
      _hydrationError = null;
      notifyListeners();
    } on CategoryProgressException catch (exception) {
      exception.logForDebug();
      _handleHydrationError(uid: uid, generation: generation, error: exception);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('[CategoryProgress] Unexpected hydration error: $error');
        debugPrint('[CategoryProgress] StackTrace: $stackTrace');
      }
      _handleHydrationError(uid: uid, generation: generation, error: error);
    }
  }

  void _handleHydrationError({
    required String uid,
    required int generation,
    required Object error,
  }) {
    if (!_shouldApplyHydration(uid: uid, generation: generation)) {
      return;
    }

    _progressByCategory.clear();
    _hydrationStatus = ProgressHydrationStatus.error;
    _hydrationError = error;
    notifyListeners();
  }

  bool _shouldApplyHydration({required String uid, required int generation}) {
    final currentUid = _currentUserIdProvider?.call();
    return generation == _hydrationGeneration &&
        _hydratedUserId == uid &&
        (currentUid == null || currentUid == uid);
  }

  void _hydrateRecords({
    required String uid,
    required Iterable<CategoryProgressRecord> records,
  }) {
    _progressByCategory
      ..clear()
      ..addEntries(
        records.map((record) {
          return MapEntry(
            record.categoryId,
            _MutableCategoryProgress.fromRecord(record),
          );
        }),
      );
    _hydratedUserId = uid;
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
    required this.viewedTheoryPageIds,
    required this.completedActivityIds,
    required this.status,
    required this.attemptCount,
    required this.latestAnswers,
    required this.startedAt,
    required this.lastActivityAt,
    required this.completedAt,
    required this.updatedAt,
  });

  final int viewedTheoryPages;
  final int totalTheoryPages;
  final int completedActivities;
  final int totalActivities;
  final int correctAnswers;
  final QuizResult? result;
  final List<String> viewedTheoryPageIds;
  final List<String> completedActivityIds;
  final CategoryProgressStatus status;
  final int attemptCount;
  final Map<String, CategoryProgressAnswer> latestAnswers;
  final DateTime? startedAt;
  final DateTime? lastActivityAt;
  final DateTime? completedAt;
  final DateTime? updatedAt;

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
  int attemptCount = 0;
  CategoryProgressStatus status = CategoryProgressStatus.notStarted;
  QuizResult? result;
  DateTime? startedAt;
  DateTime? lastActivityAt;
  DateTime? completedAt;
  DateTime? updatedAt;
  final Set<String> viewedTheoryPageIds = <String>{};
  final Set<String> completedActivityIds = <String>{};
  final Map<String, CategoryProgressAnswer> latestAnswers =
      <String, CategoryProgressAnswer>{};

  _MutableCategoryProgress();

  factory _MutableCategoryProgress.fromRecord(CategoryProgressRecord record) {
    final progress = _MutableCategoryProgress()
      ..theoryTotal = record.totalLessonPages
      ..activityTotal = record.totalActivities
      ..correctAnswers = record.correctAnswers
      ..attemptCount = record.attemptCount
      ..status = record.status
      ..startedAt = record.startedAt
      ..lastActivityAt = record.lastActivityAt
      ..completedAt = record.completedAt
      ..updatedAt = record.updatedAt;

    progress.viewedTheoryPageIds.addAll(record.viewedLessonPageIds);
    progress.completedActivityIds.addAll(record.completedActivityIds);
    progress.latestAnswers.addAll(record.latestAnswers);

    if (record.status == CategoryProgressStatus.completed &&
        record.totalActivities > 0 &&
        record.correctAnswers >= 0 &&
        record.correctAnswers <= record.totalActivities) {
      progress.result = QuizResult.fromScore(
        correctAnswers: record.correctAnswers,
        totalQuestions: record.totalActivities,
      );
    }

    return progress;
  }

  CategoryProgressSnapshot get snapshot {
    return CategoryProgressSnapshot(
      viewedTheoryPages: viewedTheoryPageIds.length.clamp(0, theoryTotal),
      totalTheoryPages: theoryTotal,
      completedActivities: completedActivityIds.length.clamp(0, activityTotal),
      totalActivities: activityTotal,
      correctAnswers: correctAnswers,
      result: result,
      viewedTheoryPageIds: List<String>.unmodifiable(viewedTheoryPageIds),
      completedActivityIds: List<String>.unmodifiable(completedActivityIds),
      status: status,
      attemptCount: attemptCount,
      latestAnswers: Map<String, CategoryProgressAnswer>.unmodifiable(
        latestAnswers,
      ),
      startedAt: startedAt,
      lastActivityAt: lastActivityAt,
      completedAt: completedAt,
      updatedAt: updatedAt,
    );
  }
}
