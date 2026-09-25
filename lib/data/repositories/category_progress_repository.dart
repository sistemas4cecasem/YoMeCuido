import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/activity_scoring_policy.dart';
import '../models/category_progress.dart';
import '../models/scored_question_sets.dart';
import 'leaderboard_repository.dart';
import 'user_profile_repository.dart';

abstract class CategoryProgressPersistence {
  Future<List<CategoryProgressRecord>> fetchAllProgress({required String uid});

  Future<void> markTheoryPageViewed({
    required String uid,
    required String categoryId,
    required String lessonId,
    required String pageId,
    required int totalLessonPages,
    required int totalActivities,
  });

  Future<CompletedQuizAttemptPersistenceResult> completeActivityAttempt({
    required String uid,
    required String categoryId,
    required String lessonId,
    required String activityId,
    required String attemptId,
    int? reservedAttemptNumber,
    int? pointValue,
    required DateTime startedAt,
    required List<String> questionIds,
    required Iterable<CategoryProgressAnswer> answers,
    required int totalLessonPages,
    required int totalActivities,
  });

  Future<CompletedQuizAttemptPersistenceResult> completeExamAttempt({
    required String uid,
    required String categoryId,
    required String lessonId,
    required String examId,
    required String attemptId,
    int? reservedAttemptNumber,
    required DateTime startedAt,
    required List<String> questionIds,
    required Iterable<CategoryProgressAnswer> answers,
    required int correctAnswers,
    required int totalQuestions,
    required int percentage,
    required int totalLessonPages,
    required int totalActivities,
  });
}

abstract class CategoryProgressRefreshPersistence {
  Future<CategoryProgressRecord?> fetchCategoryProgress({
    required String uid,
    required String categoryId,
  });
}

abstract class AttemptReservationPersistence {
  Future<AttemptReservation> reserveActivityAttempt({
    required String uid,
    required String categoryId,
    required String activityId,
    required String attemptId,
  });

  Future<AttemptReservation> reserveExamAttempt({
    required String uid,
    required String categoryId,
    required String examId,
    required String attemptId,
    List<String>? selectedQuestionIds,
  });
}

class AttemptReservation {
  const AttemptReservation({
    required this.attemptId,
    required this.attemptNumber,
    required this.startedAt,
    this.pointValue,
    this.isAuthoritative = true,
  });

  final String attemptId;
  final int attemptNumber;
  final DateTime startedAt;
  final int? pointValue;
  final bool isAuthoritative;
}

class CompletedQuizAttemptPersistenceResult {
  const CompletedQuizAttemptPersistenceResult({
    required this.attemptNumber,
    required this.answers,
    required this.correctAnswers,
    required this.totalQuestions,
    required this.percentage,
    required this.earnedPoints,
    required this.activityPoints,
    required this.questionScores,
    required this.totalPoints,
  });

  final int attemptNumber;
  final List<CategoryProgressAnswer> answers;
  final int correctAnswers;
  final int totalQuestions;
  final int percentage;
  final int earnedPoints;
  final int? activityPoints;
  final Map<String, QuestionScoreRecord> questionScores;
  final int? totalPoints;
}

enum ActivitySyncStage {
  beforeSubmission,
  submissionCommitted,
  attemptConfirmed,
  aggregatesApplied,
}

enum ExamSyncStage {
  beforeSubmission,
  submissionCommitted,
  proofACommitted,
  proofBCommitted,
  attemptConfirmed,
  aggregatesApplied,
}

class CategoryProgressRepository
    implements
        CategoryProgressPersistence,
        CategoryProgressRefreshPersistence,
        AttemptReservationPersistence {
  CategoryProgressRepository({
    FirebaseFirestore? firestore,
    @visibleForTesting this.onActivitySyncStage,
    @visibleForTesting this.onExamSyncStage,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  static const progressCollection = 'categoryProgress';
  static const activitiesCollection = 'activities';
  static const examsCollection = 'exams';
  static const attemptsCollection = 'attempts';
  static const answerSubmissionsCollection = 'answerSubmissions';

  final FirebaseFirestore _firestore;
  final Future<void> Function(ActivitySyncStage)? onActivitySyncStage;
  final Future<void> Function(ExamSyncStage)? onExamSyncStage;

  Future<void> _checkpoint(ActivitySyncStage stage) async {
    await onActivitySyncStage?.call(stage);
  }

  Future<void> _examCheckpoint(ExamSyncStage stage) async {
    await onExamSyncStage?.call(stage);
  }

  @override
  Future<AttemptReservation> reserveActivityAttempt({
    required String uid,
    required String categoryId,
    required String activityId,
    required String attemptId,
  }) {
    return _reserveAttempt(
      uid: uid,
      categoryId: categoryId,
      targetId: activityId,
      attemptId: attemptId,
      isExam: false,
    );
  }

  @override
  Future<AttemptReservation> reserveExamAttempt({
    required String uid,
    required String categoryId,
    required String examId,
    required String attemptId,
    List<String>? selectedQuestionIds,
  }) {
    return _reserveAttempt(
      uid: uid,
      categoryId: categoryId,
      targetId: examId,
      attemptId: attemptId,
      isExam: true,
      selectedQuestionIds: selectedQuestionIds,
    );
  }

  Future<AttemptReservation> _reserveAttempt({
    required String uid,
    required String categoryId,
    required String targetId,
    required String attemptId,
    required bool isExam,
    List<String>? selectedQuestionIds,
  }) {
    final operation = isExam
        ? CategoryProgressFailureOperation.reserveExamAttempt
        : CategoryProgressFailureOperation.reserveActivityAttempt;
    return _runProgressOperation<AttemptReservation>(operation, () async {
      _validateUser(uid);
      if (attemptId.trim().isEmpty || targetId.trim().isEmpty) {
        throw const FormatException(
          'Attempt reservation identifiers required.',
        );
      }
      final document = isExam
          ? _examDocument(uid, categoryId, targetId)
          : _activityDocument(uid, categoryId, targetId);
      final startedAt = DateTime.now();
      return _firestore.runTransaction<AttemptReservation>((transaction) async {
        final snapshot = await transaction.get(document);
        final data = snapshot.data();
        if (!isExam &&
            data != null &&
            data.containsKey('questionScores') &&
            !data.containsKey('scoredAt10QuestionIds')) {
          throw const FormatException(
            'Legacy activity progress requires a separate migration.',
          );
        }
        if (isExam &&
            (selectedQuestionIds == null ||
                selectedQuestionIds.length != 15 ||
                selectedQuestionIds.toSet().length != 15)) {
          throw const FormatException(
            'An exam requires 15 distinct questions.',
          );
        }
        final active = data?['activeAttempt'];
        if (active is Map) {
          final activeId = active['attemptId'];
          final number = active['attemptNumber'];
          final reservedAt = active['reservedAt'];
          final pointValue = active['pointValue'];
          if (activeId is! String ||
              activeId.trim().isEmpty ||
              number is! int) {
            throw const FormatException('Invalid active attempt reservation.');
          }
          if (!isExam && pointValue is! int) {
            throw const FormatException(
              'Activity reservation has no point value.',
            );
          }
          if (isExam &&
              !listEquals(
                active['selectedQuestionIds'] as List?,
                selectedQuestionIds,
              )) {
            throw const FormatException(
              'Exam selection changed after reservation.',
            );
          }
          return AttemptReservation(
            attemptId: activeId,
            attemptNumber: number,
            pointValue: pointValue is int ? pointValue : null,
            startedAt: reservedAt is Timestamp
                ? reservedAt.toDate()
                : startedAt,
          );
        }

        final previousCount = _existingActivityAttemptCount(snapshot);
        final nextAttemptNumber = previousCount + 1;
        final pointValue = isExam
            ? null
            : const ActivityScoringPolicy().pointsForCorrectAnswer(
                attemptNumber: nextAttemptNumber,
              );
        final activeAttempt = <String, Object?>{
          'attemptId': attemptId,
          'attemptNumber': nextAttemptNumber,
          'reservedAt': FieldValue.serverTimestamp(),
        };
        if (pointValue != null) activeAttempt['pointValue'] = pointValue;
        if (isExam) {
          activeAttempt['selectedQuestionIds'] = selectedQuestionIds;
        }
        final updates = <String, Object?>{
          if (isExam) 'examId': targetId else 'activityId': targetId,
          'status': ActivityProgressStatus.inProgress.firestoreValue,
          'attemptCount': nextAttemptNumber,
          'bestCorrectAnswers': _readExistingNonNegativeInt(
            snapshot,
            'bestCorrectAnswers',
          ),
          'bestTotalQuestions': _readExistingNonNegativeInt(
            snapshot,
            'bestTotalQuestions',
          ),
          'bestPercentage': _readExistingNonNegativeInt(
            snapshot,
            'bestPercentage',
          ),
          'lastAttemptAt': data?['lastAttemptAt'],
          'completedAt': data?['completedAt'],
          'updatedAt': FieldValue.serverTimestamp(),
          'activeAttempt': activeAttempt,
          if (!isExam) ...<String, Object?>{
            'activityPoints': _existingActivityPoints(snapshot),
            ..._existingScoredSets(snapshot).toFirestoreFields(),
          },
        };
        transaction.set(document, updates, SetOptions(merge: true));
        return AttemptReservation(
          attemptId: attemptId,
          attemptNumber: nextAttemptNumber,
          pointValue: pointValue,
          startedAt: startedAt,
        );
      });
    });
  }

  @override
  Future<List<CategoryProgressRecord>> fetchAllProgress({required String uid}) {
    return _runProgressOperation<List<CategoryProgressRecord>>(
      CategoryProgressFailureOperation.fetchAllProgress,
      () async {
        _validateUser(uid);
        final snapshot = await _progressCollection(uid).get();
        final records = <CategoryProgressRecord>[];

        for (final document in snapshot.docs) {
          try {
            final activities = await _fetchActivityProgress(
              uid: uid,
              categoryId: document.id,
            );
            final exams = await _fetchExamProgress(
              uid: uid,
              categoryId: document.id,
            );
            records.add(
              CategoryProgressRecord.fromFirestore(
                document,
                activities: activities,
                exams: exams,
              ),
            );
          } on FormatException catch (exception) {
            if (kDebugMode) {
              debugPrint(
                '[CategoryProgress] Ignoring invalid progress document '
                '${document.id}: ${exception.message}',
              );
            }
          }
        }

        return records;
      },
    );
  }

  @override
  Future<CategoryProgressRecord?> fetchCategoryProgress({
    required String uid,
    required String categoryId,
  }) {
    return _runProgressOperation<CategoryProgressRecord?>(
      CategoryProgressFailureOperation.fetchAllProgress,
      () async {
        _validateUser(uid);
        final document = await _progressDocument(uid, categoryId).get();
        if (!document.exists) return null;
        final activities = await _fetchActivityProgress(
          uid: uid,
          categoryId: categoryId,
        );
        final exams = await _fetchExamProgress(
          uid: uid,
          categoryId: categoryId,
        );
        return CategoryProgressRecord.fromFirestore(
          document,
          activities: activities,
          exams: exams,
        );
      },
    );
  }

  @override
  Future<void> markTheoryPageViewed({
    required String uid,
    required String categoryId,
    required String lessonId,
    required String pageId,
    required int totalLessonPages,
    required int totalActivities,
  }) {
    return _runProgressOperation(
      CategoryProgressFailureOperation.markTheoryPageViewed,
      () async {
        _validateUser(uid);
        final document = _progressDocument(uid, categoryId);

        await _firestore.runTransaction<void>((transaction) async {
          final snapshot = await transaction.get(document);
          if (!snapshot.exists) {
            transaction.set(document, {
              ..._initialProgressData(
                categoryId: categoryId,
                lessonId: lessonId,
                totalLessonPages: totalLessonPages,
                totalActivities: totalActivities,
              ),
              'viewedLessonPageIds': <String>[pageId],
            });
            return;
          }

          final status = _existingCategoryStatus(snapshot);
          transaction.update(document, {
            'categoryId': categoryId,
            'lessonId': lessonId,
            'status': status == CategoryProgressStatus.completed
                ? CategoryProgressStatus.completed.firestoreValue
                : CategoryProgressStatus.inProgress.firestoreValue,
            'viewedLessonPageIds': FieldValue.arrayUnion(<String>[pageId]),
            'totalLessonPages': totalLessonPages,
            'totalActivities': totalActivities,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        });
      },
    );
  }

  @override
  Future<CompletedQuizAttemptPersistenceResult> completeActivityAttempt({
    required String uid,
    required String categoryId,
    required String lessonId,
    required String activityId,
    required String attemptId,
    int? reservedAttemptNumber,
    int? pointValue,
    required DateTime startedAt,
    required List<String> questionIds,
    required Iterable<CategoryProgressAnswer> answers,
    required int totalLessonPages,
    required int totalActivities,
  }) {
    return _runProgressOperation<CompletedQuizAttemptPersistenceResult>(
      CategoryProgressFailureOperation.completeActivityAttempt,
      () async {
        _validateUser(uid);
        _validateCompletedAttemptInput(
          questionIds: questionIds,
          answers: answers,
        );
        if (questionIds.length != 10 || questionIds.toSet().length != 10) {
          throw const FormatException(
            'An activity requires ten distinct questions.',
          );
        }

        final answerById = {
          for (final answer in answers) answer.questionId: answer,
        };
        final committedAnswers = {
          for (final id in questionIds) id: answerById[id]?.answer ?? '',
        };
        final correct = [
          for (final id in questionIds) answerById[id]?.isCorrect ?? false,
        ];
        final correctAnswers = correct.where((value) => value).length;
        final percentage = correctAnswers * 10;
        final submissionDocument = _activitySubmissionDocument(
          uid,
          categoryId,
          activityId,
          attemptId,
        );
        final attemptDocument = _activityAttemptDocument(
          uid,
          categoryId,
          activityId,
          attemptId,
        );
        final activityDocument = _activityDocument(uid, categoryId, activityId);
        final categoryDocument = _progressDocument(uid, categoryId);
        final userDocument = _userDocument(uid);
        final leaderboardDocument = _leaderboardDocument(uid);

        // Public answers support local feedback; the protected key in Rules
        // remains the authority for the semantic attempt.
        final submission = <String, dynamic>{
          'attemptId': attemptId,
          'attemptNumber': 0,
          'categoryId': categoryId,
          'activityId': activityId,
          'answers': committedAnswers,
          'committedAt': FieldValue.serverTimestamp(),
        };
        // The reservation is the only source of the attempt number and value.
        final reservedActivity = await activityDocument.get();
        final active = reservedActivity.data()?['activeAttempt'];
        final activeNumber = active is Map ? active['attemptNumber'] : null;
        final activeValue = active is Map ? active['pointValue'] : null;
        final isCurrentReservation =
            active is Map &&
            active['attemptId'] == attemptId &&
            activeNumber is int &&
            activeValue is int;
        final isLaterReservation =
            active is Map &&
            reservedAttemptNumber != null &&
            activeNumber is int &&
            activeNumber > reservedAttemptNumber;
        if (active != null && !isCurrentReservation && !isLaterReservation) {
          throw const FormatException(
            'Attempt does not match its reservation.',
          );
        }
        if (isCurrentReservation &&
            pointValue != null &&
            pointValue != activeValue) {
          throw const FormatException('Invalid pending point value.');
        }
        final attemptNumber = isCurrentReservation
            ? activeNumber
            : (reservedAttemptNumber ??
                  (reservedActivity.data()?['attemptCount'] as int? ?? 0));
        if (reservedAttemptNumber != null &&
            reservedAttemptNumber != attemptNumber) {
          throw const FormatException('Pending attempt number changed.');
        }
        if (attemptNumber < 1) {
          throw const FormatException('Missing reserved attempt number.');
        }
        submission['attemptNumber'] = attemptNumber;
        await _checkpoint(ActivitySyncStage.beforeSubmission);
        await _createOrVerifyDocument(
          submissionDocument,
          submission,
          (existing) =>
              existing['attemptId'] == attemptId &&
              existing['attemptNumber'] == attemptNumber &&
              existing['categoryId'] == categoryId &&
              existing['activityId'] == activityId &&
              mapEquals(existing['answers'] as Map?, committedAnswers),
        );
        await _checkpoint(ActivitySyncStage.submissionCommitted);

        final semanticAttempt = <String, dynamic>{
          'type': QuizAttemptType.activity.firestoreValue,
          'categoryId': categoryId,
          'activityId': activityId,
          'examId': null,
          'attemptNumber': attemptNumber,
          'questionIds': questionIds,
          'correct': correct,
          'correctAnswers': correctAnswers,
          'totalQuestions': 10,
          'percentage': percentage,
          'startedAt': Timestamp.fromDate(startedAt),
          'completedAt': FieldValue.serverTimestamp(),
        };
        await _createOrVerifyDocument(
          attemptDocument,
          semanticAttempt,
          (existing) =>
              existing['type'] == 'activity' &&
              existing['categoryId'] == categoryId &&
              existing['activityId'] == activityId &&
              existing['attemptNumber'] == attemptNumber &&
              listEquals(existing['questionIds'] as List?, questionIds) &&
              listEquals(existing['correct'] as List?, correct) &&
              existing['correctAnswers'] == correctAnswers &&
              existing['percentage'] == percentage,
        );
        await _checkpoint(ActivitySyncStage.attemptConfirmed);

        final snapshots = await Future.wait([
          activityDocument.get(),
          categoryDocument.get(),
          userDocument.get(),
        ]);
        final activitySnapshot = snapshots[0];
        final categorySnapshot = snapshots[1];
        final userSnapshot = snapshots[2];
        final activityData = activitySnapshot.data();
        final userData = userSnapshot.data();
        if (activityData == null || userData == null) {
          throw const FormatException('Missing activity or user progress.');
        }
        final award = userData['lastActivityAward'];
        final currentActive = activityData['activeAttempt'];
        final laterActive =
            currentActive is Map &&
            reservedAttemptNumber != null &&
            currentActive['attemptNumber'] is int &&
            (currentActive['attemptNumber'] as int) > reservedAttemptNumber;
        if (currentActive == null || laterActive) {
          final activityCount = activityData['attemptCount'];
          final laterAttemptApplied =
              activityCount is int && activityCount > attemptNumber;
          final latestAwardMatches =
              award is Map &&
              award['categoryId'] == categoryId &&
              award['activityId'] == activityId &&
              award['attemptId'] == attemptId &&
              award['attemptNumber'] == attemptNumber;
          if ((!laterActive && activityData['status'] != 'completed') ||
              !(laterAttemptApplied || latestAwardMatches)) {
            throw const FormatException(
              'Attempt was not applied to aggregates.',
            );
          }
          final sets = _existingScoredSets(activitySnapshot);
          final confirmedValue = const ActivityScoringPolicy()
              .pointsForCorrectAnswer(attemptNumber: attemptNumber);
          if (pointValue != null && pointValue != confirmedValue) {
            throw const FormatException('Invalid pending point value.');
          }
          final group = confirmedValue == 10
              ? sets.scoredAt10QuestionIds
              : confirmedValue == 5
              ? sets.scoredAt5QuestionIds
              : confirmedValue == 1
              ? sets.scoredAt1QuestionIds
              : <String>{};
          final confirmedReward =
              correct
                  .asMap()
                  .entries
                  .where(
                    (entry) =>
                        entry.value && group.contains(questionIds[entry.key]),
                  )
                  .length *
              confirmedValue;
          return CompletedQuizAttemptPersistenceResult(
            attemptNumber: attemptNumber,
            answers: List<CategoryProgressAnswer>.unmodifiable(answers),
            correctAnswers: correctAnswers,
            totalQuestions: 10,
            percentage: percentage,
            earnedPoints: confirmedReward,
            activityPoints: _existingActivityPoints(activitySnapshot),
            questionScores: sets.toLocalQuestionScores(),
            totalPoints: _existingUserTotalPoints(userSnapshot),
          );
        }
        final validatedNumber = _validateActiveAttempt(
          snapshot: activitySnapshot,
          attemptId: attemptId,
        );
        final value = (activityData['activeAttempt'] as Map)['pointValue'];
        if (validatedNumber != attemptNumber ||
            value is! int ||
            value !=
                const ActivityScoringPolicy().pointsForCorrectAnswer(
                  attemptNumber: attemptNumber,
                ) ||
            (pointValue != null && pointValue != value)) {
          throw const FormatException('Invalid reserved point value.');
        }
        final previousScores = _existingScoredSets(
          activitySnapshot,
        ).toLocalQuestionScores();
        final scoring = _scoreActivityAnswers(
          categoryId: categoryId,
          activityId: activityId,
          attemptNumber: attemptNumber,
          questionIds: questionIds,
          answers: answers,
          existingQuestionScores: previousScores,
        );
        final nextSets = ScoredQuestionSets.fromLegacy(scoring.questionScores);
        final nextActivityPoints =
            _existingActivityPoints(activitySnapshot) + scoring.earnedPoints;
        final nextTotalPoints =
            _existingUserTotalPoints(userSnapshot) + scoring.earnedPoints;
        final replaceBest =
            percentage >= _existingBestPercentage(activitySnapshot);
        final completedIds = _existingCompletedActivityIds(categorySnapshot);
        if (!completedIds.contains(activityId)) completedIds.add(activityId);
        final username = _existingUserUsername(userSnapshot);
        if (username == null) {
          throw const FormatException('User profile has no username.');
        }

        final batch = _firestore.batch();
        batch.set(activityDocument, {
          'activityId': activityId,
          'status': ActivityProgressStatus.completed.firestoreValue,
          'attemptCount': attemptNumber,
          'activeAttempt': null,
          'activityPoints': nextActivityPoints,
          ...nextSets.toFirestoreFields(),
          'bestCorrectAnswers': replaceBest
              ? correctAnswers
              : _existingBestCorrectAnswers(activitySnapshot),
          'bestTotalQuestions': replaceBest
              ? 10
              : _existingBestTotalQuestions(activitySnapshot),
          'bestPercentage': replaceBest
              ? percentage
              : _existingBestPercentage(activitySnapshot),
          'lastAttemptAt': FieldValue.serverTimestamp(),
          'completedAt':
              _existingActivityCompletedAt(activitySnapshot) ??
              FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        if (categorySnapshot.exists) {
          batch.update(categoryDocument, {
            'categoryId': categoryId,
            'lessonId': lessonId,
            'status': CategoryProgressStatus.inProgress.firestoreValue,
            'completedActivityIds': completedIds,
            'totalLessonPages': categorySnapshot.data()?['totalLessonPages'],
            'totalActivities': categorySnapshot.data()?['totalActivities'],
            'lastActivityAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          batch.set(categoryDocument, {
            ..._initialProgressData(
              categoryId: categoryId,
              lessonId: lessonId,
              totalLessonPages: totalLessonPages,
              totalActivities: totalActivities,
            ),
            'status': CategoryProgressStatus.inProgress.firestoreValue,
            'completedActivityIds': completedIds,
            'lastActivityAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        batch.set(userDocument, {
          'totalPoints': nextTotalPoints,
          'lastActivityAward': {
            'categoryId': categoryId,
            'activityId': activityId,
            'attemptId': attemptId,
            'attemptNumber': attemptNumber,
          },
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        batch.set(leaderboardDocument, {
          'username': username,
          'totalPoints': nextTotalPoints,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        await batch.commit();
        await _checkpoint(ActivitySyncStage.aggregatesApplied);
        return scoring.toPersistenceResult(
          attemptNumber: attemptNumber,
          activityPoints: nextActivityPoints,
          totalPoints: nextTotalPoints,
        );
      },
    );
  }

  Future<void> _createOrVerifyDocument(
    DocumentReference<Map<String, dynamic>> document,
    Map<String, dynamic> proposal,
    bool Function(Map<String, dynamic>) matches,
  ) async {
    try {
      await document.set(proposal);
    } on FirebaseException catch (error) {
      if (error.code != 'permission-denied') rethrow;
      final snapshot = await document.get();
      final data = snapshot.data();
      if (data == null || !matches(data)) rethrow;
    }
  }

  @override
  Future<CompletedQuizAttemptPersistenceResult> completeExamAttempt({
    required String uid,
    required String categoryId,
    required String lessonId,
    required String examId,
    required String attemptId,
    int? reservedAttemptNumber,
    required DateTime startedAt,
    required List<String> questionIds,
    required Iterable<CategoryProgressAnswer> answers,
    required int correctAnswers,
    required int totalQuestions,
    required int percentage,
    required int totalLessonPages,
    required int totalActivities,
  }) {
    return _runProgressOperation<CompletedQuizAttemptPersistenceResult>(
      CategoryProgressFailureOperation.completeExamAttempt,
      () async {
        _validateUser(uid);
        _validateCompletedAttemptInput(
          questionIds: questionIds,
          answers: answers,
          totalQuestions: totalQuestions,
        );
        if (questionIds.length != 15 || questionIds.toSet().length != 15) {
          throw const FormatException(
            'An exam requires 15 distinct questions.',
          );
        }
        final answerById = {
          for (final answer in answers) answer.questionId: answer,
        };
        final committedAnswers = {
          for (final id in questionIds) id: answerById[id]?.answer ?? '',
        };
        final correct = [
          for (final id in questionIds) answerById[id]?.isCorrect ?? false,
        ];
        final calculatedCorrect = correct.where((value) => value).length;
        final calculatedPercentage = ((calculatedCorrect / 15) * 100).round();
        if (correctAnswers != calculatedCorrect ||
            percentage != calculatedPercentage) {
          throw const FormatException('Exam result does not match answers.');
        }
        final categoryDocument = _progressDocument(uid, categoryId);
        final examDocument = _examDocument(uid, categoryId, examId);
        final attemptDocument = _examAttemptDocument(
          uid,
          categoryId,
          examId,
          attemptId,
        );
        final userDocument = _userDocument(uid);

        final reservedExam = await examDocument.get();
        final active = reservedExam.data()?['activeAttempt'];
        final activeNumber = active is Map ? active['attemptNumber'] : null;
        final isCurrent =
            active is Map &&
            active['attemptId'] == attemptId &&
            activeNumber is int &&
            listEquals(active['selectedQuestionIds'] as List?, questionIds);
        final isLater =
            active is Map &&
            reservedAttemptNumber != null &&
            activeNumber is int &&
            activeNumber > reservedAttemptNumber;
        if (active != null && !isCurrent && !isLater) {
          throw const FormatException('Exam reservation changed.');
        }
        final attemptNumber = isCurrent
            ? activeNumber
            : reservedAttemptNumber ??
                  (reservedExam.data()?['attemptCount'] as int? ?? 0);
        if (attemptNumber < 1 ||
            (reservedAttemptNumber != null &&
                reservedAttemptNumber != attemptNumber)) {
          throw const FormatException('Invalid reserved exam number.');
        }
        final submissionDocument = examDocument
            .collection(answerSubmissionsCollection)
            .doc(attemptId);
        await _examCheckpoint(ExamSyncStage.beforeSubmission);
        await _createOrVerifyDocument(
          submissionDocument,
          {
            'attemptId': attemptId,
            'attemptNumber': attemptNumber,
            'categoryId': categoryId,
            'examId': examId,
            'answers': committedAnswers,
            'committedAt': FieldValue.serverTimestamp(),
          },
          (existing) =>
              existing['attemptId'] == attemptId &&
              existing['attemptNumber'] == attemptNumber &&
              existing['categoryId'] == categoryId &&
              existing['examId'] == examId &&
              mapEquals(existing['answers'] as Map?, committedAnswers),
        );
        await _examCheckpoint(ExamSyncStage.submissionCommitted);

        for (final part in ['A', 'B']) {
          final start = part == 'A' ? 0 : 8;
          final end = part == 'A' ? 8 : 15;
          final partIds = questionIds.sublist(start, end);
          final partCorrect = correct.sublist(start, end);
          final proofDocument = attemptDocument.collection('proofs').doc(part);
          await _createOrVerifyDocument(
            proofDocument,
            {
              'uid': uid,
              'attemptId': attemptId,
              'attemptNumber': attemptNumber,
              'categoryId': categoryId,
              'examId': examId,
              'part': part,
              'questionIds': partIds,
              'correct': partCorrect,
              'correctAnswers': partCorrect.where((value) => value).length,
              'createdAt': FieldValue.serverTimestamp(),
            },
            (existing) =>
                existing['uid'] == uid &&
                existing['attemptId'] == attemptId &&
                existing['attemptNumber'] == attemptNumber &&
                existing['categoryId'] == categoryId &&
                existing['examId'] == examId &&
                existing['part'] == part &&
                listEquals(existing['questionIds'] as List?, partIds) &&
                listEquals(existing['correct'] as List?, partCorrect),
          );
          await _examCheckpoint(
            part == 'A'
                ? ExamSyncStage.proofACommitted
                : ExamSyncStage.proofBCommitted,
          );
        }
        await _createOrVerifyDocument(
          attemptDocument,
          {
            'type': QuizAttemptType.exam.firestoreValue,
            'attemptNumber': attemptNumber,
            'categoryId': categoryId,
            'activityId': null,
            'examId': examId,
            'questionIds': questionIds,
            'correct': correct,
            'correctAnswers': calculatedCorrect,
            'totalQuestions': 15,
            'percentage': calculatedPercentage,
            'earnedPoints': 0,
            'startedAt': Timestamp.fromDate(startedAt),
            'completedAt': FieldValue.serverTimestamp(),
          },
          (existing) =>
              existing['type'] == 'exam' &&
              existing['attemptNumber'] == attemptNumber &&
              existing['categoryId'] == categoryId &&
              existing['examId'] == examId &&
              listEquals(existing['questionIds'] as List?, questionIds) &&
              listEquals(existing['correct'] as List?, correct) &&
              existing['correctAnswers'] == calculatedCorrect &&
              existing['percentage'] == calculatedPercentage &&
              existing['earnedPoints'] == 0,
        );
        await _examCheckpoint(ExamSyncStage.attemptConfirmed);

        final snapshots = await Future.wait([
          categoryDocument.get(),
          examDocument.get(),
          userDocument.get(),
        ]);
        final categorySnapshot = snapshots[0];
        final examSnapshot = snapshots[1];
        final userSnapshot = snapshots[2];
        final existingTotalPoints = _existingUserTotalPoints(userSnapshot);
        final examData = examSnapshot.data();
        final laterActive =
            examData?['activeAttempt'] is Map &&
            reservedAttemptNumber != null &&
            (examData!['activeAttempt'] as Map)['attemptNumber'] is int &&
            (examData['activeAttempt'] as Map)['attemptNumber'] > attemptNumber;
        if (examData?['activeAttempt'] == null || laterActive) {
          if (examData?['attemptCount'] is! int ||
              (examData!['attemptCount'] as int) < attemptNumber ||
              (examData['attemptCount'] == attemptNumber &&
                  examData['status'] != 'completed')) {
            throw const FormatException('Exam result was not applied.');
          }
          return CompletedQuizAttemptPersistenceResult(
            attemptNumber: attemptNumber,
            answers: List<CategoryProgressAnswer>.unmodifiable(answers),
            correctAnswers: calculatedCorrect,
            totalQuestions: 15,
            percentage: calculatedPercentage,
            earnedPoints: 0,
            activityPoints: null,
            questionScores: const <String, QuestionScoreRecord>{},
            totalPoints: existingTotalPoints,
          );
        }

        final nextAttemptNumber = _validateActiveAttempt(
          snapshot: examSnapshot,
          attemptId: attemptId,
        );
        if (nextAttemptNumber != attemptNumber) {
          throw const FormatException('Exam attempt number changed.');
        }
        final bestPercentage = _existingExamBestPercentage(examSnapshot);
        final shouldReplaceBest = percentage >= bestPercentage;
        final nextBestPercentage = shouldReplaceBest
            ? percentage
            : bestPercentage;
        final existingActivities = await _fetchActivityProgress(
          uid: uid,
          categoryId: categoryId,
        );
        final existingExams = await _fetchExamProgress(
          uid: uid,
          categoryId: categoryId,
        );
        final categoryCompleted = _isSubcategoryCompleted(
          categorySnapshot: categorySnapshot,
          totalLessonPages: totalLessonPages,
          totalActivities: totalActivities,
          activityBestPercentages: <String, int>{
            for (final activity in existingActivities.values)
              activity.activityId: activity.bestPercentage,
          },
          examBestPercentages: <String, int>{
            for (final exam in existingExams.values)
              exam.examId: exam.bestPercentage,
            examId: nextBestPercentage,
          },
        );

        final batch = _firestore.batch();
        batch.set(examDocument, {
          'examId': examId,
          'status': ActivityProgressStatus.completed.firestoreValue,
          'attemptCount': nextAttemptNumber,
          'activeAttempt': null,
          'bestCorrectAnswers': shouldReplaceBest
              ? correctAnswers
              : _existingExamBestCorrectAnswers(examSnapshot),
          'bestTotalQuestions': shouldReplaceBest
              ? totalQuestions
              : _existingExamBestTotalQuestions(examSnapshot),
          'bestPercentage': nextBestPercentage,
          'lastAttemptAt': FieldValue.serverTimestamp(),
          'completedAt':
              _existingExamCompletedAt(examSnapshot) ??
              FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (!categorySnapshot.exists) {
          batch.set(categoryDocument, {
            ..._initialProgressData(
              categoryId: categoryId,
              lessonId: lessonId,
              totalLessonPages: totalLessonPages,
              totalActivities: totalActivities,
            ),
            'status': categoryCompleted
                ? CategoryProgressStatus.completed.firestoreValue
                : CategoryProgressStatus.inProgress.firestoreValue,
            'lastActivityAt': FieldValue.serverTimestamp(),
            'completedAt': categoryCompleted
                ? FieldValue.serverTimestamp()
                : null,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          batch.update(categoryDocument, {
            'categoryId': categoryId,
            'lessonId': lessonId,
            'status': categoryCompleted
                ? CategoryProgressStatus.completed.firestoreValue
                : CategoryProgressStatus.inProgress.firestoreValue,
            'totalLessonPages': totalLessonPages,
            'totalActivities': totalActivities,
            'lastActivityAt': FieldValue.serverTimestamp(),
            'completedAt': categoryCompleted
                ? FieldValue.serverTimestamp()
                : null,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        await batch.commit();
        await _examCheckpoint(ExamSyncStage.aggregatesApplied);
        return CompletedQuizAttemptPersistenceResult(
          attemptNumber: nextAttemptNumber,
          answers: List<CategoryProgressAnswer>.unmodifiable(answers),
          correctAnswers: correctAnswers,
          totalQuestions: totalQuestions,
          percentage: percentage,
          earnedPoints: 0,
          activityPoints: null,
          questionScores: const <String, QuestionScoreRecord>{},
          totalPoints: existingTotalPoints,
        );
      },
    );
  }

  DocumentReference<Map<String, dynamic>> _progressDocument(
    String uid,
    String categoryId,
  ) {
    return _progressCollection(uid).doc(categoryId);
  }

  DocumentReference<Map<String, dynamic>> _userDocument(String uid) {
    return _firestore
        .collection(UserProfileRepository.usersCollection)
        .doc(uid);
  }

  DocumentReference<Map<String, dynamic>> _leaderboardDocument(String uid) {
    return _firestore
        .collection(LeaderboardRepository.leaderboardCollection)
        .doc(uid);
  }

  CollectionReference<Map<String, dynamic>> _progressCollection(String uid) {
    return _firestore
        .collection(UserProfileRepository.usersCollection)
        .doc(uid)
        .collection(progressCollection);
  }

  DocumentReference<Map<String, dynamic>> _activityDocument(
    String uid,
    String categoryId,
    String activityId,
  ) {
    return _progressDocument(
      uid,
      categoryId,
    ).collection(activitiesCollection).doc(activityId);
  }

  DocumentReference<Map<String, dynamic>> _activityAttemptDocument(
    String uid,
    String categoryId,
    String activityId,
    String attemptId,
  ) {
    return _activityDocument(
      uid,
      categoryId,
      activityId,
    ).collection(attemptsCollection).doc(attemptId);
  }

  DocumentReference<Map<String, dynamic>> _activitySubmissionDocument(
    String uid,
    String categoryId,
    String activityId,
    String attemptId,
  ) {
    return _activityDocument(
      uid,
      categoryId,
      activityId,
    ).collection(answerSubmissionsCollection).doc(attemptId);
  }

  DocumentReference<Map<String, dynamic>> _examDocument(
    String uid,
    String categoryId,
    String examId,
  ) {
    return _progressDocument(
      uid,
      categoryId,
    ).collection(examsCollection).doc(examId);
  }

  DocumentReference<Map<String, dynamic>> _examAttemptDocument(
    String uid,
    String categoryId,
    String examId,
    String attemptId,
  ) {
    return _examDocument(
      uid,
      categoryId,
      examId,
    ).collection(attemptsCollection).doc(attemptId);
  }

  Future<Map<String, ActivityProgressRecord>> _fetchActivityProgress({
    required String uid,
    required String categoryId,
  }) async {
    final snapshot = await _progressDocument(
      uid,
      categoryId,
    ).collection(activitiesCollection).get();
    final activities = <String, ActivityProgressRecord>{};

    for (final document in snapshot.docs) {
      try {
        final record = ActivityProgressRecord.fromFirestore(document);
        activities[record.activityId] = record;
      } on FormatException catch (exception) {
        if (kDebugMode) {
          debugPrint(
            '[CategoryProgress] Ignoring invalid activity progress '
            '${document.id}: ${exception.message}',
          );
        }
      }
    }

    return activities;
  }

  Future<Map<String, ExamProgressRecord>> _fetchExamProgress({
    required String uid,
    required String categoryId,
  }) async {
    final snapshot = await _progressDocument(
      uid,
      categoryId,
    ).collection(examsCollection).get();
    final exams = <String, ExamProgressRecord>{};

    for (final document in snapshot.docs) {
      try {
        final record = ExamProgressRecord.fromFirestore(document);
        exams[record.examId] = record;
      } on FormatException catch (exception) {
        if (kDebugMode) {
          debugPrint(
            '[CategoryProgress] Ignoring invalid exam progress '
            '${document.id}: ${exception.message}',
          );
        }
      }
    }

    return exams;
  }

  Map<String, dynamic> _initialProgressData({
    required String categoryId,
    required String lessonId,
    required int totalLessonPages,
    required int totalActivities,
  }) {
    return {
      'categoryId': categoryId,
      'lessonId': lessonId,
      'status': CategoryProgressStatus.inProgress.firestoreValue,
      'viewedLessonPageIds': <String>[],
      'completedActivityIds': <String>[],
      'totalLessonPages': totalLessonPages,
      'totalActivities': totalActivities,
      'startedAt': FieldValue.serverTimestamp(),
      'lastActivityAt': null,
      'completedAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  int _existingActivityAttemptCount(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    if (!snapshot.exists) {
      return 0;
    }

    final value = snapshot.data()?['attemptCount'];
    if (value is int && value >= 0) {
      return value;
    }

    return 0;
  }

  int _validateActiveAttempt({
    required DocumentSnapshot<Map<String, dynamic>> snapshot,
    required String attemptId,
  }) {
    final active = snapshot.data()?['activeAttempt'];
    final attemptNumber = active is Map ? active['attemptNumber'] : null;
    if (active is! Map ||
        active['attemptId'] != attemptId ||
        attemptNumber is! int ||
        _existingActivityAttemptCount(snapshot) != attemptNumber) {
      throw const CategoryProgressException(
        CategoryProgressFailureReason.invalidAttemptReservation,
        operation: CategoryProgressFailureOperation.completeActivityAttempt,
        technicalMessage: 'Attempt does not match the active reservation.',
      );
    }
    return attemptNumber;
  }

  int _existingBestCorrectAnswers(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return _readExistingNonNegativeInt(snapshot, 'bestCorrectAnswers');
  }

  int _existingBestTotalQuestions(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return _readExistingNonNegativeInt(snapshot, 'bestTotalQuestions');
  }

  int _existingBestPercentage(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    return _readExistingNonNegativeInt(snapshot, 'bestPercentage');
  }

  int _readExistingNonNegativeInt(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    String key,
  ) {
    if (!snapshot.exists) {
      return 0;
    }

    final value = snapshot.data()?[key];
    if (value is int && value >= 0) {
      return value;
    }

    return 0;
  }

  int _existingActivityPoints(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    return _readExistingNonNegativeInt(snapshot, 'activityPoints');
  }

  int _existingUserTotalPoints(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return _readExistingNonNegativeInt(snapshot, 'totalPoints');
  }

  String? _existingUserUsername(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final value = snapshot.data()?['username'];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  ScoredQuestionSets _existingScoredSets(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    if (data == null) {
      return ScoredQuestionSets(
        scoredAt10QuestionIds: const [],
        scoredAt5QuestionIds: const [],
        scoredAt1QuestionIds: const [],
      );
    }
    if (data.containsKey('scoredAt10QuestionIds')) {
      List<String> ids(String field) {
        final raw = data[field];
        if (raw is! List || raw.any((id) => id is! String)) {
          throw FormatException('Invalid $field in activity progress.');
        }
        return List<String>.from(raw);
      }

      return ScoredQuestionSets(
        scoredAt10QuestionIds: ids('scoredAt10QuestionIds'),
        scoredAt5QuestionIds: ids('scoredAt5QuestionIds'),
        scoredAt1QuestionIds: ids('scoredAt1QuestionIds'),
      );
    }
    final legacy = data['questionScores'];
    if (legacy is! Map) {
      return ScoredQuestionSets(
        scoredAt10QuestionIds: const [],
        scoredAt5QuestionIds: const [],
        scoredAt1QuestionIds: const [],
      );
    }
    final parsed = <String, QuestionScoreRecord>{};
    for (final entry in legacy.entries) {
      if (entry.key is String && entry.value is Map) {
        parsed[entry.key as String] = QuestionScoreRecord.fromMap(
          questionId: entry.key as String,
          data: Map<String, dynamic>.from(entry.value as Map),
        );
      }
    }
    return ScoredQuestionSets.fromLegacy(parsed);
  }

  DateTime? _existingActivityCompletedAt(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final value = snapshot.data()?['completedAt'];
    if (value is Timestamp) {
      return value.toDate();
    }

    return null;
  }

  int _existingExamBestCorrectAnswers(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return _readExistingNonNegativeInt(snapshot, 'bestCorrectAnswers');
  }

  int _existingExamBestTotalQuestions(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return _readExistingNonNegativeInt(snapshot, 'bestTotalQuestions');
  }

  int _existingExamBestPercentage(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return _readExistingNonNegativeInt(snapshot, 'bestPercentage');
  }

  DateTime? _existingExamCompletedAt(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final value = snapshot.data()?['completedAt'];
    if (value is Timestamp) {
      return value.toDate();
    }

    return null;
  }

  _ActivityScoringResult _scoreActivityAnswers({
    required String categoryId,
    required String activityId,
    required int attemptNumber,
    required List<String> questionIds,
    required Iterable<CategoryProgressAnswer> answers,
    required Map<String, QuestionScoreRecord> existingQuestionScores,
  }) {
    final policy = ActivityScoringPolicy();
    final answersById = {
      for (final answer in answers) answer.questionId: answer,
    };
    final nextQuestionScores = Map<String, QuestionScoreRecord>.from(
      existingQuestionScores,
    );
    final scoredAnswers = <CategoryProgressAnswer>[];
    var earnedPoints = 0;
    var correctAnswers = 0;

    for (final questionId in questionIds) {
      final answer = answersById[questionId];
      if (answer == null) {
        continue;
      }
      final isCorrect = answer.isCorrect;
      if (isCorrect) {
        correctAnswers += 1;
      }
      final existingScore =
          nextQuestionScores[questionId] ??
          QuestionScoreRecord.notAwarded(questionId: questionId);
      final pointsEarned = policy.earnedPointsForAnswer(
        attemptNumber: attemptNumber,
        isCorrect: isCorrect,
        alreadyScored: existingScore.hasAwardedPoints,
      );

      if (pointsEarned > 0) {
        nextQuestionScores[questionId] = QuestionScoreRecord(
          questionId: questionId,
          pointsAwarded: pointsEarned,
          awardedAttempt: attemptNumber,
        );
      } else {
        nextQuestionScores.putIfAbsent(
          questionId,
          () => QuestionScoreRecord.notAwarded(questionId: questionId),
        );
      }

      earnedPoints += pointsEarned;
      scoredAnswers.add(
        CategoryProgressAnswer(
          questionId: answer.questionId,
          answer: answer.answer,
          isCorrect: isCorrect,
          pointsEarned: pointsEarned,
          answeredAt: answer.answeredAt,
        ),
      );
    }

    return _ActivityScoringResult(
      answers: List<CategoryProgressAnswer>.unmodifiable(scoredAnswers),
      correctAnswers: correctAnswers,
      totalQuestions: questionIds.length,
      percentage: ((correctAnswers / questionIds.length) * 100).round(),
      earnedPoints: earnedPoints,
      questionScores: Map<String, QuestionScoreRecord>.unmodifiable(
        nextQuestionScores,
      ),
    );
  }

  void _validateCompletedAttemptInput({
    required List<String> questionIds,
    required Iterable<CategoryProgressAnswer> answers,
    int? totalQuestions,
  }) {
    final expectedTotalQuestions = totalQuestions ?? questionIds.length;
    if (questionIds.isEmpty) {
      throw StateError('Completed attempts require at least one question.');
    }
    if (questionIds.length != expectedTotalQuestions) {
      throw StateError('Question order does not match total questions.');
    }
    final answerIds = answers.map((answer) => answer.questionId).toSet();
    if (answerIds.length != answers.length) {
      throw StateError('Attempt answers do not match total questions.');
    }
    if (!answerIds.every(questionIds.contains)) {
      throw StateError('Attempt answers do not match question order.');
    }
  }

  List<String> _existingCompletedActivityIds(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final value = snapshot.data()?['completedActivityIds'];
    if (value is! List<Object?>) {
      return <String>[];
    }

    return value.whereType<String>().toList();
  }

  List<String> _existingViewedLessonPageIds(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final value = snapshot.data()?['viewedLessonPageIds'];
    if (value is! List<Object?>) {
      return <String>[];
    }

    return value.whereType<String>().toList();
  }

  bool _isSubcategoryCompleted({
    required DocumentSnapshot<Map<String, dynamic>> categorySnapshot,
    required int totalLessonPages,
    required int totalActivities,
    required Map<String, int> activityBestPercentages,
    required Map<String, int> examBestPercentages,
  }) {
    final theoryCompleted = ProgressApprovalRules.theoryCompleted(
      viewedTheoryPages: _existingViewedLessonPageIds(categorySnapshot).length,
      totalTheoryPages: totalLessonPages,
    );
    final allActivitiesPassed = totalActivities <= 0
        ? true
        : activityBestPercentages.values
                  .where(ProgressApprovalRules.hasPassingPercentage)
                  .length >=
              totalActivities;
    final examPassed = examBestPercentages.values.any(
      ProgressApprovalRules.hasPassingPercentage,
    );

    return theoryCompleted && allActivitiesPassed && examPassed;
  }

  CategoryProgressStatus _existingCategoryStatus(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final value = snapshot.data()?['status'];
    if (value is String) {
      try {
        return CategoryProgressStatus.fromFirestore(value);
      } on FormatException {
        return CategoryProgressStatus.inProgress;
      }
    }

    return CategoryProgressStatus.inProgress;
  }

  void _validateUser(String uid) {
    if (uid.trim().isEmpty) {
      throw const CategoryProgressException(
        CategoryProgressFailureReason.unauthenticated,
        operation: CategoryProgressFailureOperation.validateUser,
      );
    }
  }

  Future<T> _runProgressOperation<T>(
    CategoryProgressFailureOperation operation,
    Future<T> Function() action,
  ) async {
    try {
      return await action();
    } on CategoryProgressException {
      rethrow;
    } on FirebaseException catch (exception, stackTrace) {
      throw CategoryProgressException.fromFirebaseException(
        operation,
        exception,
        stackTrace,
      );
    } catch (error, stackTrace) {
      throw CategoryProgressException(
        CategoryProgressFailureReason.unexpected,
        operation: operation,
        technicalMessage: error.toString(),
        stackTrace: stackTrace,
      );
    }
  }
}

class _ActivityScoringResult {
  const _ActivityScoringResult({
    required this.answers,
    required this.correctAnswers,
    required this.totalQuestions,
    required this.percentage,
    required this.earnedPoints,
    required this.questionScores,
  });

  final List<CategoryProgressAnswer> answers;
  final int correctAnswers;
  final int totalQuestions;
  final int percentage;
  final int earnedPoints;
  final Map<String, QuestionScoreRecord> questionScores;

  CompletedQuizAttemptPersistenceResult toPersistenceResult({
    required int attemptNumber,
    required int activityPoints,
    required int totalPoints,
  }) {
    return CompletedQuizAttemptPersistenceResult(
      attemptNumber: attemptNumber,
      answers: answers,
      correctAnswers: correctAnswers,
      totalQuestions: totalQuestions,
      percentage: percentage,
      earnedPoints: earnedPoints,
      activityPoints: activityPoints,
      questionScores: questionScores,
      totalPoints: totalPoints,
    );
  }
}

enum CategoryProgressFailureReason {
  unauthenticated,
  invalidAttemptReservation,
  permissionDenied,
  unavailable,
  firebase,
  unexpected,
}

enum CategoryProgressFailureOperation {
  validateUser,
  fetchAllProgress,
  markTheoryPageViewed,
  reserveActivityAttempt,
  reserveExamAttempt,
  completeActivityAttempt,
  completeExamAttempt,
}

class CategoryProgressException implements Exception {
  const CategoryProgressException(
    this.reason, {
    required this.operation,
    this.firebaseCode,
    this.technicalMessage,
    this.stackTrace,
  });

  factory CategoryProgressException.fromFirebaseException(
    CategoryProgressFailureOperation operation,
    FirebaseException exception,
    StackTrace stackTrace,
  ) {
    final reason = switch (exception.code) {
      'permission-denied' => CategoryProgressFailureReason.permissionDenied,
      'unavailable' => CategoryProgressFailureReason.unavailable,
      'unauthenticated' => CategoryProgressFailureReason.unauthenticated,
      _ => CategoryProgressFailureReason.firebase,
    };

    return CategoryProgressException(
      reason,
      operation: operation,
      firebaseCode: exception.code,
      technicalMessage: exception.message,
      stackTrace: stackTrace,
    );
  }

  final CategoryProgressFailureReason reason;
  final CategoryProgressFailureOperation operation;
  final String? firebaseCode;
  final String? technicalMessage;
  final StackTrace? stackTrace;

  void logForDebug() {
    if (!kDebugMode) {
      return;
    }

    debugPrint(
      '[CategoryProgress] $operation failed: $reason'
      '${firebaseCode == null ? '' : ' ($firebaseCode)'}'
      '${technicalMessage == null ? '' : ' - $technicalMessage'}',
    );
    final stackTrace = this.stackTrace;
    if (stackTrace != null) {
      debugPrint('[CategoryProgress] StackTrace: $stackTrace');
    }
  }

  @override
  String toString() {
    return 'CategoryProgressException($operation, $reason, $firebaseCode, '
        '$technicalMessage)';
  }
}
