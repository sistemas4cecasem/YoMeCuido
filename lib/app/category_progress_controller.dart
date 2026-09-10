import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../data/models/activity_scoring_policy.dart';
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
  String? _totalPointsUserId;
  int? _currentTotalPoints;

  ProgressHydrationStatus get hydrationStatus => _hydrationStatus;

  String? get hydratedUserId => _hydratedUserId;

  Object? get hydrationError => _hydrationError;

  int? get currentTotalPoints => _currentTotalPoints;

  String? get totalPointsUserId => _totalPointsUserId;

  int? totalPointsForUser(String uid) {
    return _totalPointsUserId == uid.trim() ? _currentTotalPoints : null;
  }

  bool hasResolvedTotalPointsFor(String uid) {
    return totalPointsForUser(uid) != null;
  }

  void hydrateTotalPointsFromProfile({
    required String uid,
    required int totalPoints,
  }) {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) {
      clearForSignedOutUser();
      return;
    }
    final normalizedTotalPoints = totalPoints < 0 ? 0 : totalPoints;
    if (_totalPointsUserId == normalizedUid &&
        _currentTotalPoints == normalizedTotalPoints) {
      return;
    }

    _totalPointsUserId = normalizedUid;
    _currentTotalPoints = normalizedTotalPoints;
    notifyListeners();
  }

  bool hasResolvedProgressFor(String uid) {
    return _hydratedUserId == uid &&
        _hydrationStatus == ProgressHydrationStatus.loaded;
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
    final hadTotalPoints = _currentTotalPoints != null;
    _totalPointsUserId = null;
    _currentTotalPoints = null;
    if (_progressByCategory.isEmpty &&
        _attemptsById.isEmpty &&
        !hadTotalPoints) {
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

  Future<bool> markTheoryPageViewed({
    required String categoryId,
    required String lessonId,
    required String pageId,
    required int totalPages,
  }) async {
    final progress = _entryFor(categoryId);
    final normalizedTotalPages = totalPages < 0 ? 0 : totalPages;
    if (progress.viewedTheoryPageIds.contains(pageId)) {
      if (progress.theoryTotal != normalizedTotalPages) {
        progress.theoryTotal = normalizedTotalPages;
        progress.updatedAt = DateTime.now();
        notifyListeners();
      }
      return true;
    }

    final persisted = await _persistTheoryPageViewedForCurrentUser(
      categoryId: categoryId,
      lessonId: lessonId,
      pageId: pageId,
      totalLessonPages: normalizedTotalPages,
      totalActivities: progress.activityTotal,
    );
    if (!persisted) {
      return false;
    }

    progress.theoryTotal = normalizedTotalPages;
    progress.viewedTheoryPageIds.add(pageId);
    if (progress.status != CategoryProgressStatus.completed) {
      progress.status = CategoryProgressStatus.inProgress;
    }
    progress.updatedAt = DateTime.now();
    notifyListeners();
    return true;
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
      attemptNumber: 1,
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
      attemptNumber: 1,
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

  Future<bool> completeActivityAttempt({
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
    if (attempt.completedAt != null) {
      return false;
    }
    if (attempt.type != QuizAttemptType.activity ||
        attempt.categoryId != categoryId ||
        attempt.activityId != activityId) {
      throw StateError('Attempt does not belong to the requested activity.');
    }
    if (attempt.answers.length != result.totalQuestions ||
        attempt.questionIds.length != result.totalQuestions) {
      throw StateError('Cannot complete an attempt with pending answers.');
    }

    final now = DateTime.now();
    final progress = _entryFor(categoryId)..activityTotal = totalActivities;
    final activity = progress.activityProgressFor(activityId);
    final expectedAttemptNumber = activity.attemptCount + 1;
    attempt.attemptNumber = expectedAttemptNumber;
    attempt
      ..correctAnswers = result.correctAnswers
      ..totalQuestions = result.totalQuestions
      ..percentage = result.percentage;

    final persisted = await _persistCompletedActivityAttempt(
      categoryId: categoryId,
      lessonId: lessonId,
      activityId: activityId,
      attempt: attempt,
      activity: activity,
      totalLessonPages: progress.theoryTotal,
      totalActivities: totalActivities,
    );
    if (persisted == null) {
      return false;
    }

    attempt
      ..attemptNumber = persisted.attemptNumber
      ..correctAnswers = persisted.correctAnswers
      ..totalQuestions = persisted.totalQuestions
      ..percentage = persisted.percentage
      ..earnedPoints = persisted.earnedPoints
      ..completedAt = now;
    attempt.answers
      ..clear()
      ..addEntries(
        persisted.answers.map((answer) => MapEntry(answer.questionId, answer)),
      );
    _applyPersistedTotalPoints(persisted.totalPoints);

    final shouldReplaceBest = persisted.percentage >= activity.bestPercentage;
    activity
      ..status = ActivityProgressStatus.completed
      ..attemptCount = persisted.attemptNumber
      ..activityPoints =
          persisted.activityPoints ??
          (activity.activityPoints + persisted.earnedPoints)
      ..questionScores = persisted.questionScores
      ..lastAttemptAt = now
      ..completedAt ??= now
      ..updatedAt = now;
    if (shouldReplaceBest) {
      activity
        ..bestCorrectAnswers = persisted.correctAnswers
        ..bestTotalQuestions = persisted.totalQuestions
        ..bestPercentage = persisted.percentage;
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
    return true;
  }

  Future<CompletedQuizAttemptPersistenceResult?>
  _persistCompletedActivityAttempt({
    required String categoryId,
    required String lessonId,
    required String activityId,
    required _MutableQuizAttempt attempt,
    required _MutableActivityProgress activity,
    required int totalLessonPages,
    required int totalActivities,
  }) {
    return _requirePersistForCurrentUser((uid) {
      return _persistence!.completeActivityAttempt(
        uid: uid,
        categoryId: categoryId,
        lessonId: lessonId,
        activityId: activityId,
        attemptId: attempt.id,
        startedAt: attempt.startedAt,
        questionIds: attempt.questionIds,
        answers: attempt.answers.values,
        totalLessonPages: totalLessonPages,
        totalActivities: totalActivities,
      );
    }, orElse: () => _localCompletedActivityResult(attempt, activity));
  }

  Future<bool> completeExamAttempt({
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
    if (attempt.completedAt != null) {
      return false;
    }
    if (attempt.type != QuizAttemptType.exam ||
        attempt.categoryId != categoryId ||
        attempt.examId != examId) {
      throw StateError('Attempt does not belong to the requested exam.');
    }
    if (attempt.answers.length != result.totalQuestions ||
        attempt.questionIds.length != result.totalQuestions) {
      throw StateError('Cannot complete an attempt with pending answers.');
    }

    final now = DateTime.now();
    final progress = _entryFor(categoryId)..activityTotal = totalActivities;
    final exam = progress.examProgressFor(examId);
    attempt.attemptNumber = exam.attemptCount + 1;
    attempt
      ..correctAnswers = result.correctAnswers
      ..totalQuestions = result.totalQuestions
      ..percentage = result.percentage
      ..earnedPoints = 0;

    final persisted = await _persistCompletedExamAttempt(
      categoryId: categoryId,
      lessonId: lessonId,
      examId: examId,
      attempt: attempt,
      result: result,
      totalLessonPages: progress.theoryTotal,
      totalActivities: totalActivities,
    );
    if (persisted == null) {
      return false;
    }

    attempt
      ..attemptNumber = persisted.attemptNumber
      ..earnedPoints = persisted.earnedPoints
      ..completedAt = now;
    _applyPersistedTotalPoints(persisted.totalPoints);

    final shouldReplaceBest = result.percentage >= exam.bestPercentage;
    exam
      ..status = ActivityProgressStatus.completed
      ..attemptCount = persisted.attemptNumber
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
    return true;
  }

  Future<CompletedQuizAttemptPersistenceResult?> _persistCompletedExamAttempt({
    required String categoryId,
    required String lessonId,
    required String examId,
    required _MutableQuizAttempt attempt,
    required QuizResult result,
    required int totalLessonPages,
    required int totalActivities,
  }) {
    return _requirePersistForCurrentUser(
      (uid) {
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
      },
      orElse: () {
        return CompletedQuizAttemptPersistenceResult(
          attemptNumber: attempt.attemptNumber,
          answers: List<CategoryProgressAnswer>.unmodifiable(
            attempt.answers.values,
          ),
          correctAnswers: result.correctAnswers,
          totalQuestions: result.totalQuestions,
          percentage: result.percentage,
          earnedPoints: 0,
          activityPoints: null,
          questionScores: const <String, QuestionScoreRecord>{},
          totalPoints: _currentTotalPoints,
        );
      },
    );
  }

  CompletedQuizAttemptPersistenceResult _localCompletedActivityResult(
    _MutableQuizAttempt attempt,
    _MutableActivityProgress activity,
  ) {
    final policy = ActivityScoringPolicy();
    final scoredAnswers = <CategoryProgressAnswer>[];
    final questionScores = <String, QuestionScoreRecord>{};
    var earnedPoints = 0;

    for (final answer in attempt.answers.values) {
      final pointsEarned = policy.earnedPointsForAnswer(
        attemptNumber: attempt.attemptNumber,
        isCorrect: answer.isCorrect,
        alreadyScored:
            activity.questionScores[answer.questionId]?.hasAwardedPoints ??
            false,
      );
      earnedPoints += pointsEarned;
      scoredAnswers.add(
        CategoryProgressAnswer(
          questionId: answer.questionId,
          answer: answer.answer,
          isCorrect: answer.isCorrect,
          pointsEarned: pointsEarned,
          answeredAt: answer.answeredAt,
        ),
      );
      questionScores[answer.questionId] = pointsEarned > 0
          ? QuestionScoreRecord(
              questionId: answer.questionId,
              pointsAwarded: pointsEarned,
              awardedAttempt: attempt.attemptNumber,
            )
          : activity.questionScores[answer.questionId] ??
                QuestionScoreRecord.notAwarded(questionId: answer.questionId);
    }

    return CompletedQuizAttemptPersistenceResult(
      attemptNumber: attempt.attemptNumber,
      answers: List<CategoryProgressAnswer>.unmodifiable(scoredAnswers),
      correctAnswers: attempt.correctAnswers,
      totalQuestions: attempt.totalQuestions,
      percentage: attempt.percentage,
      earnedPoints: earnedPoints,
      activityPoints: activity.activityPoints + earnedPoints,
      questionScores: Map<String, QuestionScoreRecord>.unmodifiable(
        questionScores,
      ),
      totalPoints: _currentTotalPoints == null
          ? null
          : _currentTotalPoints! + earnedPoints,
    );
  }

  void _applyPersistedTotalPoints(int? totalPoints) {
    if (totalPoints == null) {
      return;
    }

    final uid =
        _currentUserIdProvider?.call()?.trim() ??
        _hydratedUserId ??
        _totalPointsUserId;
    if (uid == null || uid.isEmpty) {
      return;
    }

    _totalPointsUserId = uid;
    _currentTotalPoints = totalPoints < 0 ? 0 : totalPoints;
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

  Future<bool> _persistTheoryPageViewedForCurrentUser({
    required String categoryId,
    required String lessonId,
    required String pageId,
    required int totalLessonPages,
    required int totalActivities,
  }) async {
    final persistence = _persistence;
    if (persistence == null) {
      return true;
    }

    final uid = _currentUserIdProvider?.call();
    if (uid == null || uid.trim().isEmpty) {
      if (kDebugMode) {
        debugPrint(
          '[CategoryProgress] Persistence skipped: no authenticated user.',
        );
      }
      return false;
    }

    final normalizedUid = uid.trim();
    try {
      await persistence.markTheoryPageViewed(
        uid: normalizedUid,
        categoryId: categoryId,
        lessonId: lessonId,
        pageId: pageId,
        totalLessonPages: totalLessonPages,
        totalActivities: totalActivities,
      );
      return _currentUserIdProvider?.call()?.trim() == normalizedUid;
    } on CategoryProgressException catch (exception) {
      exception.logForDebug();
      return false;
    } catch (error, stackTrace) {
      if (!kDebugMode) {
        return false;
      }
      debugPrint('[CategoryProgress] Unexpected persistence error: $error');
      debugPrint('[CategoryProgress] StackTrace: $stackTrace');
      return false;
    }
  }

  Future<T?> _requirePersistForCurrentUser<T>(
    Future<T> Function(String uid) operation, {
    required T Function() orElse,
  }) async {
    if (_persistence == null) {
      return orElse();
    }

    final uid = _currentUserIdProvider?.call();
    if (uid == null || uid.trim().isEmpty) {
      if (kDebugMode) {
        debugPrint(
          '[CategoryProgress] Completion skipped: no authenticated user.',
        );
      }
      return null;
    }

    try {
      return await operation(uid);
    } on CategoryProgressException catch (exception) {
      exception.logForDebug();
      return null;
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('[CategoryProgress] Unexpected persistence error: $error');
        debugPrint('[CategoryProgress] StackTrace: $stackTrace');
      }
      return null;
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
    required this.activityPoints,
    required this.questionScores,
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
  final int activityPoints;
  final Map<String, QuestionScoreRecord> questionScores;
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
    required this.attemptNumber,
    required this.type,
    required this.categoryId,
    required this.activityId,
    required this.examId,
    required this.questionIds,
    required this.answers,
    required this.correctAnswers,
    required this.totalQuestions,
    required this.percentage,
    required this.earnedPoints,
    required this.startedAt,
    required this.completedAt,
  });

  final String id;
  final int attemptNumber;
  final QuizAttemptType type;
  final String categoryId;
  final String? activityId;
  final String? examId;
  final List<String> questionIds;
  final Map<String, CategoryProgressAnswer> answers;
  final int correctAnswers;
  final int totalQuestions;
  final int percentage;
  final int earnedPoints;
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
      ..activityPoints = record.activityPoints
      ..questionScores = record.questionScores
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
  int activityPoints = 0;
  Map<String, QuestionScoreRecord> questionScores =
      const <String, QuestionScoreRecord>{};
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
      activityPoints: activityPoints,
      questionScores: Map<String, QuestionScoreRecord>.unmodifiable(
        questionScores,
      ),
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
    required this.attemptNumber,
    required this.categoryId,
    required this.activityId,
    required this.examId,
    required List<String> questionIds,
    required this.startedAt,
  }) : questionIds = List<String>.unmodifiable(questionIds),
       totalQuestions = questionIds.length;

  final String id;
  int attemptNumber;
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
  int earnedPoints = 0;
  DateTime? completedAt;

  QuizAttemptSnapshot get snapshot {
    return QuizAttemptSnapshot(
      id: id,
      attemptNumber: attemptNumber,
      type: type,
      categoryId: categoryId,
      activityId: activityId,
      examId: examId,
      questionIds: questionIds,
      answers: Map<String, CategoryProgressAnswer>.unmodifiable(answers),
      correctAnswers: correctAnswers,
      totalQuestions: totalQuestions,
      percentage: percentage,
      earnedPoints: earnedPoints,
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
