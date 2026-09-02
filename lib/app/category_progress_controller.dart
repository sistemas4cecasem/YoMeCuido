import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../data/models/category_progress.dart';
import '../data/models/quiz_result.dart';
import '../data/repositories/category_progress_repository.dart';

typedef AttemptIdGenerator = String Function();

enum ProgressHydrationStatus { notStarted, loading, loaded, error }

class CategoryProgressController extends ChangeNotifier {
  CategoryProgressController({
    CategoryProgressPersistence? persistence,
    String? Function()? currentUserIdProvider,
    AttemptIdGenerator? attemptIdGenerator,
  }) : _persistence = persistence,
       _currentUserIdProvider = currentUserIdProvider,
       _attemptIdGenerator = attemptIdGenerator ?? _defaultAttemptId;

  final CategoryProgressPersistence? _persistence;
  final String? Function()? _currentUserIdProvider;
  final AttemptIdGenerator _attemptIdGenerator;
  final Map<String, _MutableCategoryProgress> _progressByCategory = {};
  final Map<String, _MutableQuizAttempt> _attemptsById = {};
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
      _attemptsById.clear();
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
    if (_progressByCategory.isEmpty && _attemptsById.isEmpty) {
      return;
    }
    _progressByCategory.clear();
    _attemptsById.clear();
    notifyListeners();
  }

  CategoryProgressSnapshot snapshotFor(String categoryId) {
    return _entryFor(categoryId).snapshot;
  }

  ActivityProgressSnapshot activityProgressFor({
    required String categoryId,
    required String activityId,
  }) {
    return _entryFor(categoryId).activitySnapshotFor(activityId);
  }

  QuizAttemptSnapshot? attemptFor(String attemptId) {
    return _attemptsById[attemptId]?.snapshot;
  }

  ExamProgressSnapshot examProgressFor({
    required String categoryId,
    required String examId,
  }) {
    return _entryFor(categoryId).examSnapshotFor(examId);
  }

  void updateActivityTotal({
    required String categoryId,
    required int totalActivities,
  }) {
    final normalizedTotal = totalActivities < 0 ? 0 : totalActivities;
    final progress = _entryFor(categoryId);
    if (progress.activityTotal == normalizedTotal) {
      return;
    }

    progress.activityTotal = normalizedTotal;
    final hasCompletedAll =
        normalizedTotal > 0 &&
        progress.completedActivityIds.length >= normalizedTotal;
    if (hasCompletedAll) {
      progress
        ..status = CategoryProgressStatus.completed
        ..completedAt ??= DateTime.now();
    } else if (progress.status == CategoryProgressStatus.completed) {
      progress
        ..status = CategoryProgressStatus.inProgress
        ..completedAt = null;
    }
    progress.updatedAt = DateTime.now();
    notifyListeners();
  }

  void updateTheoryTotal({
    required String categoryId,
    required int totalPages,
  }) {
    final normalizedTotal = totalPages < 0 ? 0 : totalPages;
    final progress = _entryFor(categoryId);
    if (progress.theoryTotal == normalizedTotal) {
      return;
    }

    progress.theoryTotal = normalizedTotal;
    if (progress.status == CategoryProgressStatus.completed &&
        progress.viewedTheoryPageIds.length < normalizedTotal) {
      progress
        ..status = CategoryProgressStatus.inProgress
        ..completedAt = null;
    }
    progress.updatedAt = DateTime.now();
    notifyListeners();
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

  String startActivityAttempt({
    required String categoryId,
    required String lessonId,
    required String activityId,
    required List<String> questionIds,
    required int totalActivities,
  }) {
    final attemptId = _attemptIdGenerator();
    final now = DateTime.now();
    _entryFor(categoryId).activityTotal = totalActivities;
    _attemptsById[attemptId] = _MutableQuizAttempt(
      id: attemptId,
      type: QuizAttemptType.activity,
      categoryId: categoryId,
      activityId: activityId,
      examId: null,
      questionIds: questionIds,
      startedAt: now,
    );
    notifyListeners();
    return attemptId;
  }

  String startExamAttempt({
    required String categoryId,
    required String lessonId,
    required String examId,
    required List<String> questionIds,
    required int totalActivities,
  }) {
    final attemptId = _attemptIdGenerator();
    final now = DateTime.now();
    _entryFor(categoryId).activityTotal = totalActivities;
    _attemptsById[attemptId] = _MutableQuizAttempt(
      id: attemptId,
      type: QuizAttemptType.exam,
      categoryId: categoryId,
      activityId: null,
      examId: examId,
      questionIds: questionIds,
      startedAt: now,
    );
    notifyListeners();
    return attemptId;
  }

  void discardAttempt(String attemptId) {
    if (_attemptsById.remove(attemptId) != null) {
      notifyListeners();
    }
  }

  Future<void> recordAnswer({
    required String categoryId,
    String? activityId,
    String? examId,
    required String attemptId,
    required String questionId,
    required String answer,
    required bool isCorrect,
  }) async {
    final attempt = _attemptsById[attemptId];
    if (attempt == null) {
      throw StateError('Unknown attempt id "$attemptId".');
    }
    if (attempt.categoryId != categoryId ||
        attempt.activityId != activityId ||
        attempt.examId != examId) {
      throw StateError('Attempt does not belong to the requested target.');
    }

    final answeredAt = DateTime.now();
    attempt.answers[questionId] = CategoryProgressAnswer(
      questionId: questionId,
      answer: answer,
      isCorrect: isCorrect,
      answeredAt: answeredAt,
    );
    notifyListeners();
  }

  Future<void> completeActivityAttempt({
    required String categoryId,
    required String lessonId,
    required String activityId,
    required String attemptId,
    required QuizResult result,
    required int totalActivities,
  }) async {
    final attempt = _attemptsById[attemptId];
    if (attempt == null) {
      throw StateError('Unknown attempt id "$attemptId".');
    }

    final now = DateTime.now();
    attempt
      ..correctAnswers = result.correctAnswers
      ..totalQuestions = result.totalQuestions
      ..percentage = result.percentage
      ..completedAt = now;

    final progress = _entryFor(categoryId)..activityTotal = totalActivities;
    final activity = progress.activityProgressFor(activityId);
    final shouldReplaceBest = result.percentage >= activity.bestPercentage;
    activity
      ..status = ActivityProgressStatus.completed
      ..attemptCount += 1
      ..lastAttemptAt = now
      ..completedAt ??= now
      ..updatedAt = now;
    if (shouldReplaceBest) {
      activity
        ..bestCorrectAnswers = result.correctAnswers
        ..bestTotalQuestions = result.totalQuestions
        ..bestPercentage = result.percentage;
    }

    progress.completedActivityIds.add(activityId);
    progress
      ..status = progress.completedActivityIds.length >= progress.activityTotal
          ? CategoryProgressStatus.completed
          : CategoryProgressStatus.inProgress
      ..lastActivityAt = now
      ..completedAt = progress.status == CategoryProgressStatus.completed
          ? now
          : null
      ..updatedAt = now;
    notifyListeners();

    await _persistCompletedActivityAttempt(
      categoryId: categoryId,
      lessonId: lessonId,
      activityId: activityId,
      attempt: attempt,
      result: result,
      totalLessonPages: progress.theoryTotal,
      totalActivities: totalActivities,
    );
  }

  Future<void> _persistCompletedActivityAttempt({
    required String categoryId,
    required String lessonId,
    required String activityId,
    required _MutableQuizAttempt attempt,
    required QuizResult result,
    required int totalLessonPages,
    required int totalActivities,
  }) {
    return _persistForCurrentUser((uid) {
      return _persistence!.completeActivityAttempt(
        uid: uid,
        categoryId: categoryId,
        lessonId: lessonId,
        activityId: activityId,
        attemptId: attempt.id,
        startedAt: attempt.startedAt,
        questionIds: attempt.questionIds,
        answers: attempt.answers.values,
        correctAnswers: result.correctAnswers,
        totalQuestions: result.totalQuestions,
        percentage: result.percentage,
        totalLessonPages: totalLessonPages,
        totalActivities: totalActivities,
      );
    });
  }

  Future<void> completeExamAttempt({
    required String categoryId,
    required String lessonId,
    required String examId,
    required String attemptId,
    required QuizResult result,
    required int totalActivities,
  }) async {
    final attempt = _attemptsById[attemptId];
    if (attempt == null) {
      throw StateError('Unknown attempt id "$attemptId".');
    }
    if (attempt.type != QuizAttemptType.exam || attempt.examId != examId) {
      throw StateError('Attempt does not belong to the requested exam.');
    }

    final now = DateTime.now();
    attempt
      ..correctAnswers = result.correctAnswers
      ..totalQuestions = result.totalQuestions
      ..percentage = result.percentage
      ..completedAt = now;

    final progress = _entryFor(categoryId)..activityTotal = totalActivities;
    final exam = progress.examProgressFor(examId);
    final shouldReplaceBest = result.percentage >= exam.bestPercentage;
    exam
      ..status = ActivityProgressStatus.completed
      ..attemptCount += 1
      ..lastAttemptAt = now
      ..completedAt ??= now
      ..updatedAt = now;
    if (shouldReplaceBest) {
      exam
        ..bestCorrectAnswers = result.correctAnswers
        ..bestTotalQuestions = result.totalQuestions
        ..bestPercentage = result.percentage;
    }

    progress
      ..status = CategoryProgressStatus.completed
      ..lastActivityAt = now
      ..completedAt = now
      ..updatedAt = now;
    notifyListeners();

    await _persistCompletedExamAttempt(
      categoryId: categoryId,
      lessonId: lessonId,
      examId: examId,
      attempt: attempt,
      result: result,
      totalLessonPages: progress.theoryTotal,
      totalActivities: totalActivities,
    );
  }

  Future<void> _persistCompletedExamAttempt({
    required String categoryId,
    required String lessonId,
    required String examId,
    required _MutableQuizAttempt attempt,
    required QuizResult result,
    required int totalLessonPages,
    required int totalActivities,
  }) {
    return _persistForCurrentUser((uid) {
      return _persistence!.completeExamAttempt(
        uid: uid,
        categoryId: categoryId,
        lessonId: lessonId,
        examId: examId,
        attemptId: attempt.id,
        startedAt: attempt.startedAt,
        questionIds: attempt.questionIds,
        answers: attempt.answers.values,
        correctAnswers: result.correctAnswers,
        totalQuestions: result.totalQuestions,
        percentage: result.percentage,
        totalLessonPages: totalLessonPages,
        totalActivities: totalActivities,
      );
    });
  }

  void resetCategory(String categoryId) {
    final progress = _entryFor(categoryId);
    progress
      ..viewedTheoryPageIds.clear()
      ..completedActivityIds.clear()
      ..status = CategoryProgressStatus.notStarted
      ..lastActivityAt = null
      ..completedAt = null
      ..updatedAt = DateTime.now();
    progress.activities.clear();
    progress.exams.clear();
    _attemptsById.removeWhere((id, attempt) {
      return attempt.categoryId == categoryId;
    });
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
    _attemptsById.clear();
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
    _attemptsById.clear();
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
    required this.activityProgress,
    required this.examProgress,
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
  final Map<String, ActivityProgressSnapshot> activityProgress;
  final Map<String, ExamProgressSnapshot> examProgress;
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

class ActivityProgressSnapshot {
  const ActivityProgressSnapshot({
    required this.activityId,
    required this.status,
    required this.attemptCount,
    required this.bestCorrectAnswers,
    required this.bestTotalQuestions,
    required this.bestPercentage,
    required this.lastAttemptAt,
    required this.completedAt,
    required this.updatedAt,
  });

  final String activityId;
  final ActivityProgressStatus status;
  final int attemptCount;
  final int bestCorrectAnswers;
  final int bestTotalQuestions;
  final int bestPercentage;
  final DateTime? lastAttemptAt;
  final DateTime? completedAt;
  final DateTime? updatedAt;

  bool get isCompleted => status == ActivityProgressStatus.completed;
}

class ExamProgressSnapshot {
  const ExamProgressSnapshot({
    required this.examId,
    required this.status,
    required this.attemptCount,
    required this.bestCorrectAnswers,
    required this.bestTotalQuestions,
    required this.bestPercentage,
    required this.lastAttemptAt,
    required this.completedAt,
    required this.updatedAt,
  });

  final String examId;
  final ActivityProgressStatus status;
  final int attemptCount;
  final int bestCorrectAnswers;
  final int bestTotalQuestions;
  final int bestPercentage;
  final DateTime? lastAttemptAt;
  final DateTime? completedAt;
  final DateTime? updatedAt;

  bool get isCompleted => status == ActivityProgressStatus.completed;
}

class QuizAttemptSnapshot {
  const QuizAttemptSnapshot({
    required this.id,
    required this.type,
    required this.categoryId,
    required this.activityId,
    required this.examId,
    required this.questionIds,
    required this.answers,
    required this.correctAnswers,
    required this.totalQuestions,
    required this.percentage,
    required this.startedAt,
    required this.completedAt,
  });

  final String id;
  final QuizAttemptType type;
  final String categoryId;
  final String? activityId;
  final String? examId;
  final List<String> questionIds;
  final Map<String, CategoryProgressAnswer> answers;
  final int correctAnswers;
  final int totalQuestions;
  final int percentage;
  final DateTime startedAt;
  final DateTime? completedAt;

  bool get isCompleted => completedAt != null;
}

class _MutableCategoryProgress {
  static const _defaultActivityTotal = 6;

  int theoryTotal = 4;
  int activityTotal = _defaultActivityTotal;
  CategoryProgressStatus status = CategoryProgressStatus.notStarted;
  DateTime? startedAt;
  DateTime? lastActivityAt;
  DateTime? completedAt;
  DateTime? updatedAt;
  final Set<String> viewedTheoryPageIds = <String>{};
  final Set<String> completedActivityIds = <String>{};
  final Map<String, _MutableActivityProgress> activities =
      <String, _MutableActivityProgress>{};
  final Map<String, _MutableExamProgress> exams =
      <String, _MutableExamProgress>{};

  _MutableCategoryProgress();

  factory _MutableCategoryProgress.fromRecord(CategoryProgressRecord record) {
    final progress = _MutableCategoryProgress()
      ..theoryTotal = record.totalLessonPages
      ..activityTotal = record.totalActivities
      ..status = record.status
      ..startedAt = record.startedAt
      ..lastActivityAt = record.lastActivityAt
      ..completedAt = record.completedAt
      ..updatedAt = record.updatedAt;

    progress.viewedTheoryPageIds.addAll(record.viewedLessonPageIds);
    progress.completedActivityIds.addAll(
      record.completedActivityIds.where(_isNotLegacyQuestionProgressId),
    );
    for (final activity in record.activities.values) {
      progress.activities[activity.activityId] =
          _MutableActivityProgress.fromRecord(activity);
    }
    for (final exam in record.exams.values) {
      progress.exams[exam.examId] = _MutableExamProgress.fromRecord(exam);
    }

    return progress;
  }

  _MutableActivityProgress activityProgressFor(String activityId) {
    return activities.putIfAbsent(
      activityId,
      () => _MutableActivityProgress(activityId),
    );
  }

  ActivityProgressSnapshot activitySnapshotFor(String activityId) {
    return activityProgressFor(activityId).snapshot;
  }

  _MutableExamProgress examProgressFor(String examId) {
    return exams.putIfAbsent(examId, () => _MutableExamProgress(examId));
  }

  ExamProgressSnapshot examSnapshotFor(String examId) {
    return examProgressFor(examId).snapshot;
  }

  CategoryProgressSnapshot get snapshot {
    final bestActivities = activities.values
        .where((activity) {
          return activity.status == ActivityProgressStatus.completed &&
              activity.bestTotalQuestions > 0;
        })
        .toList(growable: false);
    final correctAnswers = bestActivities.fold<int>(
      0,
      (total, activity) => total + activity.bestCorrectAnswers,
    );
    final totalQuestions = bestActivities.fold<int>(
      0,
      (total, activity) => total + activity.bestTotalQuestions,
    );
    final result = totalQuestions == 0
        ? null
        : QuizResult.fromScore(
            correctAnswers: correctAnswers,
            totalQuestions: totalQuestions,
          );

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
      activityProgress: Map<String, ActivityProgressSnapshot>.unmodifiable(
        activities.map((key, value) => MapEntry(key, value.snapshot)),
      ),
      examProgress: Map<String, ExamProgressSnapshot>.unmodifiable(
        exams.map((key, value) => MapEntry(key, value.snapshot)),
      ),
      startedAt: startedAt,
      lastActivityAt: lastActivityAt,
      completedAt: completedAt,
      updatedAt: updatedAt,
    );
  }
}

class _MutableActivityProgress {
  _MutableActivityProgress(this.activityId);

  factory _MutableActivityProgress.fromRecord(ActivityProgressRecord record) {
    return _MutableActivityProgress(record.activityId)
      ..status = record.status
      ..attemptCount = record.attemptCount
      ..bestCorrectAnswers = record.bestCorrectAnswers
      ..bestTotalQuestions = record.bestTotalQuestions
      ..bestPercentage = record.bestPercentage
      ..lastAttemptAt = record.lastAttemptAt
      ..completedAt = record.completedAt
      ..updatedAt = record.updatedAt;
  }

  final String activityId;
  ActivityProgressStatus status = ActivityProgressStatus.notStarted;
  int attemptCount = 0;
  int bestCorrectAnswers = 0;
  int bestTotalQuestions = 0;
  int bestPercentage = 0;
  DateTime? lastAttemptAt;
  DateTime? completedAt;
  DateTime? updatedAt;

  ActivityProgressSnapshot get snapshot {
    return ActivityProgressSnapshot(
      activityId: activityId,
      status: status,
      attemptCount: attemptCount,
      bestCorrectAnswers: bestCorrectAnswers,
      bestTotalQuestions: bestTotalQuestions,
      bestPercentage: bestPercentage,
      lastAttemptAt: lastAttemptAt,
      completedAt: completedAt,
      updatedAt: updatedAt,
    );
  }
}

class _MutableExamProgress {
  _MutableExamProgress(this.examId);

  factory _MutableExamProgress.fromRecord(ExamProgressRecord record) {
    return _MutableExamProgress(record.examId)
      ..status = record.status
      ..attemptCount = record.attemptCount
      ..bestCorrectAnswers = record.bestCorrectAnswers
      ..bestTotalQuestions = record.bestTotalQuestions
      ..bestPercentage = record.bestPercentage
      ..lastAttemptAt = record.lastAttemptAt
      ..completedAt = record.completedAt
      ..updatedAt = record.updatedAt;
  }

  final String examId;
  ActivityProgressStatus status = ActivityProgressStatus.notStarted;
  int attemptCount = 0;
  int bestCorrectAnswers = 0;
  int bestTotalQuestions = 0;
  int bestPercentage = 0;
  DateTime? lastAttemptAt;
  DateTime? completedAt;
  DateTime? updatedAt;

  ExamProgressSnapshot get snapshot {
    return ExamProgressSnapshot(
      examId: examId,
      status: status,
      attemptCount: attemptCount,
      bestCorrectAnswers: bestCorrectAnswers,
      bestTotalQuestions: bestTotalQuestions,
      bestPercentage: bestPercentage,
      lastAttemptAt: lastAttemptAt,
      completedAt: completedAt,
      updatedAt: updatedAt,
    );
  }
}

class _MutableQuizAttempt {
  _MutableQuizAttempt({
    required this.id,
    required this.type,
    required this.categoryId,
    required this.activityId,
    required this.examId,
    required List<String> questionIds,
    required this.startedAt,
  }) : questionIds = List<String>.unmodifiable(questionIds),
       totalQuestions = questionIds.length;

  final String id;
  final QuizAttemptType type;
  final String categoryId;
  final String? activityId;
  final String? examId;
  final List<String> questionIds;
  final DateTime startedAt;
  final Map<String, CategoryProgressAnswer> answers =
      <String, CategoryProgressAnswer>{};
  int correctAnswers = 0;
  int totalQuestions;
  int percentage = 0;
  DateTime? completedAt;

  QuizAttemptSnapshot get snapshot {
    return QuizAttemptSnapshot(
      id: id,
      type: type,
      categoryId: categoryId,
      activityId: activityId,
      examId: examId,
      questionIds: questionIds,
      answers: Map<String, CategoryProgressAnswer>.unmodifiable(answers),
      correctAnswers: correctAnswers,
      totalQuestions: totalQuestions,
      percentage: percentage,
      startedAt: startedAt,
      completedAt: completedAt,
    );
  }
}

String _defaultAttemptId() {
  const alphabet =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final random = math.Random.secure();
  final buffer = StringBuffer('attempt_');
  for (var index = 0; index < 20; index += 1) {
    buffer.write(alphabet[random.nextInt(alphabet.length)]);
  }

  return buffer.toString();
}

bool _isNotLegacyQuestionProgressId(String id) {
  return !RegExp(r'^activity_\d+$').hasMatch(id);
}
