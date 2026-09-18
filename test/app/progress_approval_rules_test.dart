import 'package:demo_yomecuido/app/category_progress_controller.dart';
import 'package:demo_yomecuido/data/models/category_progress.dart';
import 'package:demo_yomecuido/data/models/quiz_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProgressApprovalRules', () {
    test('approves activities from the centralized 80 percent rule', () {
      expect(_activity(bestPercentage: 0).isPassed, isFalse);
      expect(_activity(bestPercentage: 70).isPassed, isFalse);
      expect(_activity(bestPercentage: 80).isPassed, isTrue);
      expect(_activity(bestPercentage: 100).isPassed, isTrue);
    });

    test('keeps activity approved when a later attempt is worse', () async {
      final controller = CategoryProgressController(
        attemptIdGenerator: _sequentialAttemptIds(),
      );

      await _completeActivityAttempt(
        controller,
        correctAnswers: 9,
        totalQuestions: 10,
      );
      await _completeActivityAttempt(
        controller,
        correctAnswers: 5,
        totalQuestions: 10,
      );

      final snapshot = controller.snapshotFor(_categoryId);
      final activity = snapshot.activityProgress[_activityId];
      expect(activity?.bestPercentage, 90);
      expect(snapshot.activityPassed(_activityId), isTrue);
      expect(snapshot.allActivitiesPassed, isTrue);
    });

    test('approves exams from the centralized 80 percent rule', () {
      expect(_exam(bestPercentage: 0).isPassed, isFalse);
      expect(_exam(bestPercentage: 73).isPassed, isFalse);
      expect(_exam(bestPercentage: 80).isPassed, isTrue);
      expect(_exam(bestPercentage: 100).isPassed, isTrue);
    });

    test('keeps exam approved when a later attempt is worse', () async {
      final controller = CategoryProgressController(
        attemptIdGenerator: _sequentialAttemptIds(),
      );

      await _completeExamAttempt(
        controller,
        correctAnswers: 13,
        totalQuestions: 15,
      );
      await _completeExamAttempt(
        controller,
        correctAnswers: 8,
        totalQuestions: 15,
      );

      final snapshot = controller.snapshotFor(_categoryId);
      final exam = snapshot.examProgress[_examId];
      expect(exam?.bestPercentage, 87);
      expect(snapshot.examPassed(_examId), isTrue);
      expect(snapshot.hasPassedExam, isTrue);
    });

    test('completes subcategory after a later passing exam attempt', () async {
      final controller = CategoryProgressController(
        attemptIdGenerator: _sequentialAttemptIds(),
      );

      await _completeTheory(controller);
      await _completeActivityAttempt(
        controller,
        correctAnswers: 8,
        totalQuestions: 10,
      );
      await _completeExamAttempt(
        controller,
        correctAnswers: 10,
        totalQuestions: 15,
      );
      await _completeExamAttempt(
        controller,
        correctAnswers: 13,
        totalQuestions: 15,
      );

      final snapshot = controller.snapshotFor(_categoryId);
      final exam = snapshot.examProgress[_examId];
      expect(exam?.bestPercentage, 87);
      expect(snapshot.examPassed(_examId), isTrue);
      expect(snapshot.subcategoryCompleted, isTrue);
    });

    test('keeps subcategory completed after a worse exam retry', () async {
      final controller = CategoryProgressController(
        attemptIdGenerator: _sequentialAttemptIds(),
      );

      await _completeTheory(controller);
      await _completeActivityAttempt(
        controller,
        correctAnswers: 8,
        totalQuestions: 10,
      );
      await _completeExamAttempt(
        controller,
        correctAnswers: 13,
        totalQuestions: 15,
      );
      await _completeExamAttempt(
        controller,
        correctAnswers: 7,
        totalQuestions: 15,
      );

      final snapshot = controller.snapshotFor(_categoryId);
      final exam = snapshot.examProgress[_examId];
      expect(exam?.bestPercentage, 87);
      expect(snapshot.examPassed(_examId), isTrue);
      expect(snapshot.subcategoryCompleted, isTrue);
    });

    test('detects completed theory from viewed and total pages', () {
      expect(
        _snapshot(viewedTheoryPages: 2, totalTheoryPages: 4).hasCompletedTheory,
        isFalse,
      );
      expect(
        _snapshot(viewedTheoryPages: 4, totalTheoryPages: 4).hasCompletedTheory,
        isTrue,
      );
    });

    test(
      'unlocks exam only with completed theory and all activities passed',
      () {
        expect(
          _snapshot(
            viewedTheoryPages: 3,
            totalTheoryPages: 4,
            totalActivities: 1,
            activities: <String, ActivityProgressSnapshot>{
              _activityId: _activity(bestPercentage: 80),
            },
          ).examUnlocked,
          isFalse,
        );
        expect(
          _snapshot(
            viewedTheoryPages: 4,
            totalTheoryPages: 4,
            totalActivities: 1,
            activities: <String, ActivityProgressSnapshot>{
              _activityId: _activity(bestPercentage: 70),
            },
          ).examUnlocked,
          isFalse,
        );
        expect(
          _snapshot(
            viewedTheoryPages: 4,
            totalTheoryPages: 4,
            totalActivities: 1,
            activities: <String, ActivityProgressSnapshot>{
              _activityId: _activity(bestPercentage: 80),
            },
          ).examUnlocked,
          isTrue,
        );
      },
    );

    test(
      'completes subcategory only with theory activities and exam passed',
      () {
        expect(
          _snapshot(
            viewedTheoryPages: 4,
            totalTheoryPages: 4,
            totalActivities: 1,
            activities: <String, ActivityProgressSnapshot>{
              _activityId: _activity(bestPercentage: 80),
            },
            exams: <String, ExamProgressSnapshot>{
              _examId: _exam(bestPercentage: 73),
            },
          ).subcategoryCompleted,
          isFalse,
        );
        expect(
          _snapshot(
            viewedTheoryPages: 4,
            totalTheoryPages: 4,
            totalActivities: 1,
            activities: <String, ActivityProgressSnapshot>{
              _activityId: _activity(bestPercentage: 80),
            },
            exams: <String, ExamProgressSnapshot>{
              _examId: _exam(bestPercentage: 80),
            },
          ).subcategoryCompleted,
          isTrue,
        );
      },
    );

    test('calculates weighted progress from validated learning route', () {
      expect(_weightedSnapshot().overallRawPercentage, 0);
      expect(_weightedSnapshot(viewedTheoryPages: 6).overallRawPercentage, 10);
      expect(
        _weightedSnapshot(
          viewedTheoryPages: 6,
          passedActivityCount: 1,
        ).overallRawPercentage,
        22.5,
      );
      expect(
        _weightedSnapshot(
          viewedTheoryPages: 6,
          passedActivityCount: 3,
        ).overallRawPercentage,
        47.5,
      );
      expect(
        _weightedSnapshot(
          viewedTheoryPages: 6,
          passedActivityCount: 5,
        ).overallRawPercentage,
        72.5,
      );
      expect(
        _weightedSnapshot(
          viewedTheoryPages: 6,
          passedActivityCount: 6,
        ).overallRawPercentage,
        85,
      );
      expect(
        _weightedSnapshot(
          viewedTheoryPages: 6,
          passedActivityCount: 6,
          examBestPercentage: 80,
        ).overallRawPercentage,
        100,
      );
    });

    test('rounds weighted progress only after summing the full value', () {
      expect(
        _weightedSnapshot(
          viewedTheoryPages: 6,
          passedActivityCount: 1,
        ).overallPercentage,
        23,
      );
      expect(
        _weightedSnapshot(
          viewedTheoryPages: 6,
          passedActivityCount: 3,
        ).overallPercentage,
        48,
      );
      expect(
        _weightedSnapshot(
          viewedTheoryPages: 6,
          passedActivityCount: 5,
        ).overallPercentage,
        73,
      );
    });

    test('ignores failed activities and failed exam in weighted progress', () {
      expect(
        _weightedSnapshot(
          viewedTheoryPages: 6,
          activityPercentages: const <int>[70],
        ).overallRawPercentage,
        10,
      );
      expect(
        _weightedSnapshot(
          viewedTheoryPages: 6,
          passedActivityCount: 6,
          examBestPercentage: 73,
        ).overallRawPercentage,
        85,
      );
      expect(
        _weightedSnapshot(
          viewedTheoryPages: 6,
          passedActivityCount: 6,
          examBestPercentage: 80,
        ).overallRawPercentage,
        100,
      );
    });

    test('keeps weighted progress after a worse retry', () async {
      final controller = CategoryProgressController(
        attemptIdGenerator: _sequentialAttemptIds(),
      );

      await _completeTheory(controller);
      await _completeActivityAttempt(
        controller,
        correctAnswers: 9,
        totalQuestions: 10,
      );
      final approvedProgress = controller
          .snapshotFor(_categoryId)
          .overallRawPercentage;
      await _completeActivityAttempt(
        controller,
        correctAnswers: 5,
        totalQuestions: 10,
      );

      expect(controller.snapshotFor(_categoryId).overallRawPercentage, 85);
      expect(
        controller.snapshotFor(_categoryId).overallRawPercentage,
        approvedProgress,
      );
    });

    test('keeps weighted progress finite and clamped', () {
      final zeroTotals = _snapshot(
        viewedTheoryPages: 0,
        totalTheoryPages: 0,
        totalActivities: 0,
      );
      expect(zeroTotals.overallRawPercentage.isFinite, isTrue);
      expect(zeroTotals.overallRawPercentage, 0);
      expect(zeroTotals.overallPercentage, 0);
      expect(zeroTotals.overallProgress, 0);

      final overfilled = _weightedSnapshot(
        viewedTheoryPages: 12,
        passedActivityCount: 8,
        examBestPercentage: 100,
      );
      expect(overfilled.overallRawPercentage.isFinite, isTrue);
      expect(overfilled.overallRawPercentage, 100);
      expect(overfilled.overallPercentage, 100);
      expect(overfilled.overallProgress, 1);
    });
  });
}

const _categoryId = 'relations_violence';
const _lessonId = 'relations_violence_lesson';
const _activityId = 'relations_violence_activity_01';
const _examId = 'relations_violence_final_exam';

ActivityProgressSnapshot _activity({
  String activityId = _activityId,
  required int bestPercentage,
}) {
  return ActivityProgressSnapshot(
    activityId: activityId,
    status: bestPercentage > 0
        ? ActivityProgressStatus.completed
        : ActivityProgressStatus.notStarted,
    attemptCount: bestPercentage > 0 ? 1 : 0,
    activityPoints: 0,
    questionScores: const <String, QuestionScoreRecord>{},
    bestCorrectAnswers: 0,
    bestTotalQuestions: 10,
    bestPercentage: bestPercentage,
    lastAttemptAt: null,
    completedAt: null,
    updatedAt: null,
  );
}

ExamProgressSnapshot _exam({required int bestPercentage}) {
  return ExamProgressSnapshot(
    examId: _examId,
    status: bestPercentage > 0
        ? ActivityProgressStatus.completed
        : ActivityProgressStatus.notStarted,
    attemptCount: bestPercentage > 0 ? 1 : 0,
    bestCorrectAnswers: 0,
    bestTotalQuestions: 15,
    bestPercentage: bestPercentage,
    lastAttemptAt: null,
    completedAt: null,
    updatedAt: null,
  );
}

CategoryProgressSnapshot _snapshot({
  int viewedTheoryPages = 0,
  int totalTheoryPages = 4,
  int totalActivities = 1,
  Map<String, ActivityProgressSnapshot> activities =
      const <String, ActivityProgressSnapshot>{},
  Map<String, ExamProgressSnapshot> exams =
      const <String, ExamProgressSnapshot>{},
}) {
  final completedActivityIds = activities.values
      .where((activity) => activity.isCompleted)
      .map((activity) => activity.activityId)
      .toList(growable: false);
  return CategoryProgressSnapshot(
    viewedTheoryPages: viewedTheoryPages,
    totalTheoryPages: totalTheoryPages,
    completedActivities: completedActivityIds.length,
    totalActivities: totalActivities,
    correctAnswers: 0,
    earnedPoints: 0,
    result: null,
    viewedTheoryPageIds: List<String>.generate(
      viewedTheoryPages,
      (index) => 'page_$index',
    ),
    completedActivityIds: completedActivityIds,
    status: CategoryProgressStatus.inProgress,
    activityProgress: activities,
    examProgress: exams,
    startedAt: null,
    lastActivityAt: null,
    completedAt: null,
    updatedAt: null,
  );
}

CategoryProgressSnapshot _weightedSnapshot({
  int viewedTheoryPages = 0,
  int totalTheoryPages = 6,
  int totalActivities = 6,
  int passedActivityCount = 0,
  List<int>? activityPercentages,
  int? examBestPercentage,
}) {
  final percentages =
      activityPercentages ??
      List<int>.generate(
        passedActivityCount,
        (_) => ProgressApprovalRules.passingPercentage,
      );
  return _snapshot(
    viewedTheoryPages: viewedTheoryPages,
    totalTheoryPages: totalTheoryPages,
    totalActivities: totalActivities,
    activities: <String, ActivityProgressSnapshot>{
      for (var index = 0; index < percentages.length; index += 1)
        'activity_$index': _activity(
          activityId: 'activity_$index',
          bestPercentage: percentages[index],
        ),
    },
    exams: examBestPercentage == null
        ? const <String, ExamProgressSnapshot>{}
        : <String, ExamProgressSnapshot>{
            _examId: _exam(bestPercentage: examBestPercentage),
          },
  );
}

Future<void> _completeActivityAttempt(
  CategoryProgressController controller, {
  required int correctAnswers,
  required int totalQuestions,
}) async {
  final questionIds = List<String>.generate(
    totalQuestions,
    (index) => 'question_$index',
  );
  final attemptId = controller.startActivityAttempt(
    categoryId: _categoryId,
    lessonId: _lessonId,
    activityId: _activityId,
    questionIds: questionIds,
    totalActivities: 1,
  );
  for (var index = 0; index < totalQuestions; index += 1) {
    await controller.recordAnswer(
      categoryId: _categoryId,
      activityId: _activityId,
      attemptId: attemptId,
      questionId: questionIds[index],
      answer: 'answer_$index',
      isCorrect: index < correctAnswers,
    );
  }
  await controller.completeActivityAttempt(
    categoryId: _categoryId,
    lessonId: _lessonId,
    activityId: _activityId,
    attemptId: attemptId,
    result: QuizResult.fromScore(
      correctAnswers: correctAnswers,
      totalQuestions: totalQuestions,
    ),
    totalActivities: 1,
  );
}

Future<void> _completeTheory(CategoryProgressController controller) async {
  for (final pageId in ['page_01']) {
    await controller.markTheoryPageViewed(
      categoryId: _categoryId,
      lessonId: _lessonId,
      pageId: pageId,
      totalPages: 1,
    );
  }
}

Future<void> _completeExamAttempt(
  CategoryProgressController controller, {
  required int correctAnswers,
  required int totalQuestions,
}) async {
  final questionIds = List<String>.generate(
    totalQuestions,
    (index) => 'exam_question_$index',
  );
  final attemptId = controller.startExamAttempt(
    categoryId: _categoryId,
    lessonId: _lessonId,
    examId: _examId,
    questionIds: questionIds,
    totalActivities: 1,
  );
  for (var index = 0; index < totalQuestions; index += 1) {
    await controller.recordAnswer(
      categoryId: _categoryId,
      examId: _examId,
      attemptId: attemptId,
      questionId: questionIds[index],
      answer: 'answer_$index',
      isCorrect: index < correctAnswers,
    );
  }
  await controller.completeExamAttempt(
    categoryId: _categoryId,
    lessonId: _lessonId,
    examId: _examId,
    attemptId: attemptId,
    result: QuizResult.fromScore(
      correctAnswers: correctAnswers,
      totalQuestions: totalQuestions,
    ),
    totalActivities: 1,
  );
}

AttemptIdGenerator _sequentialAttemptIds() {
  var nextAttempt = 0;
  return () {
    nextAttempt += 1;
    return 'attempt_$nextAttempt';
  };
}
