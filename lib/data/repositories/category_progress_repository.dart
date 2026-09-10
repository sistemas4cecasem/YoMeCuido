import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../firestore/educational_content_firestore_mapper.dart';
import '../models/activity_scoring_policy.dart';
import '../models/category_progress.dart';
import '../models/quiz_question.dart';
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

  Future<void> startActivityAttempt({
    required String uid,
    required String categoryId,
    required String lessonId,
    required String activityId,
    required String attemptId,
    required List<String> questionIds,
    required int totalLessonPages,
    required int totalActivities,
  });

  Future<void> startExamAttempt({
    required String uid,
    required String categoryId,
    required String lessonId,
    required String examId,
    required String attemptId,
    required List<String> questionIds,
    required int totalLessonPages,
    required int totalActivities,
  });

  Future<void> recordAttemptAnswer({
    required String uid,
    required String categoryId,
    String? activityId,
    String? examId,
    required String attemptId,
    required String questionId,
    required String answer,
    required bool isCorrect,
  });

  Future<CompletedQuizAttemptPersistenceResult> completeActivityAttempt({
    required String uid,
    required String categoryId,
    required String lessonId,
    required String activityId,
    required String attemptId,
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

class CategoryProgressRepository implements CategoryProgressPersistence {
  CategoryProgressRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static const progressCollection = 'categoryProgress';
  static const activitiesCollection = 'activities';
  static const examsCollection = 'exams';
  static const attemptsCollection = 'attempts';

  final FirebaseFirestore _firestore;

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
  Future<void> startActivityAttempt({
    required String uid,
    required String categoryId,
    required String lessonId,
    required String activityId,
    required String attemptId,
    required List<String> questionIds,
    required int totalLessonPages,
    required int totalActivities,
  }) {
    return _runProgressOperation(
      CategoryProgressFailureOperation.startActivityAttempt,
      () async {
        _validateUser(uid);
        final categoryDocument = _progressDocument(uid, categoryId);
        final activityDocument = _activityDocument(uid, categoryId, activityId);
        final attemptDocument = _activityAttemptDocument(
          uid,
          categoryId,
          activityId,
          attemptId,
        );

        await _firestore.runTransaction<void>((transaction) async {
          final categorySnapshot = await transaction.get(categoryDocument);
          final activitySnapshot = await transaction.get(activityDocument);

          if (!categorySnapshot.exists) {
            transaction.set(
              categoryDocument,
              _initialProgressData(
                categoryId: categoryId,
                lessonId: lessonId,
                totalLessonPages: totalLessonPages,
                totalActivities: totalActivities,
              ),
            );
          } else {
            transaction.update(categoryDocument, {
              'categoryId': categoryId,
              'lessonId': lessonId,
              'status': CategoryProgressStatus.inProgress.firestoreValue,
              'totalLessonPages': totalLessonPages,
              'totalActivities': totalActivities,
              'completedAt': null,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }

          final nextAttemptCount =
              _existingActivityAttemptCount(activitySnapshot) + 1;
          transaction.set(activityDocument, {
            'activityId': activityId,
            'status': ActivityProgressStatus.inProgress.firestoreValue,
            'attemptCount': nextAttemptCount,
            'bestCorrectAnswers': _existingBestCorrectAnswers(activitySnapshot),
            'bestTotalQuestions': _existingBestTotalQuestions(activitySnapshot),
            'bestPercentage': _existingBestPercentage(activitySnapshot),
            'lastAttemptAt': FieldValue.serverTimestamp(),
            'completedAt': _existingActivityCompletedAt(activitySnapshot),
            'updatedAt': FieldValue.serverTimestamp(),
          });

          transaction.set(attemptDocument, {
            'type': QuizAttemptType.activity.firestoreValue,
            'categoryId': categoryId,
            'activityId': activityId,
            'examId': null,
            'questionIds': questionIds,
            'answers': <String, Map<String, dynamic>>{},
            'correctAnswers': 0,
            'totalQuestions': questionIds.length,
            'percentage': 0,
            'startedAt': FieldValue.serverTimestamp(),
            'completedAt': null,
          });
        });
      },
    );
  }

  @override
  Future<void> startExamAttempt({
    required String uid,
    required String categoryId,
    required String lessonId,
    required String examId,
    required String attemptId,
    required List<String> questionIds,
    required int totalLessonPages,
    required int totalActivities,
  }) {
    return _runProgressOperation(
      CategoryProgressFailureOperation.startExamAttempt,
      () async {
        _validateUser(uid);
        final categoryDocument = _progressDocument(uid, categoryId);
        final examDocument = _examDocument(uid, categoryId, examId);
        final attemptDocument = _examAttemptDocument(
          uid,
          categoryId,
          examId,
          attemptId,
        );

        await _firestore.runTransaction<void>((transaction) async {
          final categorySnapshot = await transaction.get(categoryDocument);
          final examSnapshot = await transaction.get(examDocument);

          if (!categorySnapshot.exists) {
            transaction.set(
              categoryDocument,
              _initialProgressData(
                categoryId: categoryId,
                lessonId: lessonId,
                totalLessonPages: totalLessonPages,
                totalActivities: totalActivities,
              ),
            );
          } else {
            transaction.update(categoryDocument, {
              'categoryId': categoryId,
              'lessonId': lessonId,
              'totalLessonPages': totalLessonPages,
              'totalActivities': totalActivities,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }

          final nextAttemptCount = _existingExamAttemptCount(examSnapshot) + 1;
          transaction.set(examDocument, {
            'examId': examId,
            'status': ActivityProgressStatus.inProgress.firestoreValue,
            'attemptCount': nextAttemptCount,
            'bestCorrectAnswers': _existingExamBestCorrectAnswers(examSnapshot),
            'bestTotalQuestions': _existingExamBestTotalQuestions(examSnapshot),
            'bestPercentage': _existingExamBestPercentage(examSnapshot),
            'lastAttemptAt': FieldValue.serverTimestamp(),
            'completedAt': _existingExamCompletedAt(examSnapshot),
            'updatedAt': FieldValue.serverTimestamp(),
          });

          transaction.set(attemptDocument, {
            'type': QuizAttemptType.exam.firestoreValue,
            'categoryId': categoryId,
            'activityId': null,
            'examId': examId,
            'questionIds': questionIds,
            'answers': <String, Map<String, dynamic>>{},
            'correctAnswers': 0,
            'totalQuestions': questionIds.length,
            'percentage': 0,
            'startedAt': FieldValue.serverTimestamp(),
            'completedAt': null,
          });
        });
      },
    );
  }

  @override
  Future<void> recordAttemptAnswer({
    required String uid,
    required String categoryId,
    String? activityId,
    String? examId,
    required String attemptId,
    required String questionId,
    required String answer,
    required bool isCorrect,
  }) {
    return _runProgressOperation(
      CategoryProgressFailureOperation.recordAttemptAnswer,
      () async {
        _validateUser(uid);
        final attemptDocument = activityId == null
            ? _examAttemptDocument(uid, categoryId, examId!, attemptId)
            : _activityAttemptDocument(uid, categoryId, activityId, attemptId);
        final answerData = <String, dynamic>{
          'questionId': questionId,
          'answer': answer,
          'isCorrect': isCorrect,
          'answeredAt': FieldValue.serverTimestamp(),
        };

        await attemptDocument.update({'answers.$questionId': answerData});
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
        final categoryDocument = _progressDocument(uid, categoryId);
        final activityDocument = _activityDocument(uid, categoryId, activityId);
        final attemptDocument = _activityAttemptDocument(
          uid,
          categoryId,
          activityId,
          attemptId,
        );
        final userDocument = _userDocument(uid);

        return _firestore.runTransaction<CompletedQuizAttemptPersistenceResult>(
          (transaction) async {
            final categorySnapshot = await transaction.get(categoryDocument);
            final activitySnapshot = await transaction.get(activityDocument);
            final attemptSnapshot = await transaction.get(attemptDocument);
            final userSnapshot = await transaction.get(userDocument);
            if (attemptSnapshot.exists) {
              return _completedAttemptResultFromSnapshots(
                attemptSnapshot: attemptSnapshot,
                activitySnapshot: activitySnapshot,
                userSnapshot: userSnapshot,
              );
            }
            final questionSnapshots =
                <String, DocumentSnapshot<Map<String, dynamic>>>{};
            for (final questionId in questionIds) {
              questionSnapshots[questionId] = await transaction.get(
                _questionDocument(categoryId, questionId),
              );
            }
            final completedActivityIds = _existingCompletedActivityIds(
              categorySnapshot,
            );
            if (!completedActivityIds.contains(activityId)) {
              completedActivityIds.add(activityId);
            }
            final categoryCompleted =
                totalActivities > 0 &&
                completedActivityIds.length >= totalActivities;
            final nextAttemptNumber =
                _existingActivityAttemptCount(activitySnapshot) + 1;
            final existingQuestionScores = _existingQuestionScores(
              activitySnapshot,
            );
            final scoringResult = _scoreActivityAnswers(
              categoryId: categoryId,
              activityId: activityId,
              attemptNumber: nextAttemptNumber,
              questionIds: questionIds,
              answers: answers,
              questionSnapshots: questionSnapshots,
              existingQuestionScores: existingQuestionScores,
            );
            final correctAnswers = scoringResult.correctAnswers;
            final totalQuestions = scoringResult.totalQuestions;
            final percentage = scoringResult.percentage;
            final nextActivityPoints =
                _existingActivityPoints(activitySnapshot) +
                scoringResult.earnedPoints;
            final nextTotalPoints =
                _existingUserTotalPoints(userSnapshot) +
                scoringResult.earnedPoints;
            final bestPercentage = _existingBestPercentage(activitySnapshot);
            final shouldReplaceBest = percentage >= bestPercentage;

            transaction.set(attemptDocument, {
              'type': QuizAttemptType.activity.firestoreValue,
              'attemptNumber': nextAttemptNumber,
              'categoryId': categoryId,
              'activityId': activityId,
              'examId': null,
              'questionIds': questionIds,
              'answers': _answersByQuestionId(scoringResult.answers),
              'correctAnswers': correctAnswers,
              'totalQuestions': totalQuestions,
              'percentage': percentage,
              'earnedPoints': scoringResult.earnedPoints,
              'startedAt': Timestamp.fromDate(startedAt),
              'completedAt': FieldValue.serverTimestamp(),
            });

            transaction.set(activityDocument, {
              'activityId': activityId,
              'status': ActivityProgressStatus.completed.firestoreValue,
              'attemptCount': nextAttemptNumber,
              'activityPoints': nextActivityPoints,
              'questionScores': _questionScoresByQuestionId(
                scoringResult.questionScores,
              ),
              'bestCorrectAnswers': shouldReplaceBest
                  ? correctAnswers
                  : _existingBestCorrectAnswers(activitySnapshot),
              'bestTotalQuestions': shouldReplaceBest
                  ? totalQuestions
                  : _existingBestTotalQuestions(activitySnapshot),
              'bestPercentage': shouldReplaceBest ? percentage : bestPercentage,
              'lastAttemptAt': FieldValue.serverTimestamp(),
              'completedAt':
                  _existingActivityCompletedAt(activitySnapshot) ??
                  FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });

            transaction.set(userDocument, {
              'totalPoints': nextTotalPoints,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));

            if (!categorySnapshot.exists) {
              transaction.set(categoryDocument, {
                ..._initialProgressData(
                  categoryId: categoryId,
                  lessonId: lessonId,
                  totalLessonPages: totalLessonPages,
                  totalActivities: totalActivities,
                ),
                'status': categoryCompleted
                    ? CategoryProgressStatus.completed.firestoreValue
                    : CategoryProgressStatus.inProgress.firestoreValue,
                'completedActivityIds': completedActivityIds,
                'lastActivityAt': FieldValue.serverTimestamp(),
                'completedAt': categoryCompleted
                    ? FieldValue.serverTimestamp()
                    : null,
                'updatedAt': FieldValue.serverTimestamp(),
              });
              return scoringResult.toPersistenceResult(
                attemptNumber: nextAttemptNumber,
                activityPoints: nextActivityPoints,
                totalPoints: nextTotalPoints,
              );
            }

            transaction.update(categoryDocument, {
              'categoryId': categoryId,
              'lessonId': lessonId,
              'status': categoryCompleted
                  ? CategoryProgressStatus.completed.firestoreValue
                  : CategoryProgressStatus.inProgress.firestoreValue,
              'completedActivityIds': completedActivityIds,
              'totalLessonPages': totalLessonPages,
              'totalActivities': totalActivities,
              'lastActivityAt': FieldValue.serverTimestamp(),
              'completedAt': categoryCompleted
                  ? FieldValue.serverTimestamp()
                  : null,
              'updatedAt': FieldValue.serverTimestamp(),
            });
            return scoringResult.toPersistenceResult(
              attemptNumber: nextAttemptNumber,
              activityPoints: nextActivityPoints,
              totalPoints: nextTotalPoints,
            );
          },
        );
      },
    );
  }

  @override
  Future<CompletedQuizAttemptPersistenceResult> completeExamAttempt({
    required String uid,
    required String categoryId,
    required String lessonId,
    required String examId,
    required String attemptId,
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
        final categoryDocument = _progressDocument(uid, categoryId);
        final examDocument = _examDocument(uid, categoryId, examId);
        final attemptDocument = _examAttemptDocument(
          uid,
          categoryId,
          examId,
          attemptId,
        );
        final userDocument = _userDocument(uid);

        return _firestore.runTransaction<CompletedQuizAttemptPersistenceResult>(
          (transaction) async {
            final categorySnapshot = await transaction.get(categoryDocument);
            final examSnapshot = await transaction.get(examDocument);
            final attemptSnapshot = await transaction.get(attemptDocument);
            final userSnapshot = await transaction.get(userDocument);
            final existingTotalPoints = _existingUserTotalPoints(userSnapshot);
            if (attemptSnapshot.exists) {
              return _completedAttemptResultFromSnapshots(
                attemptSnapshot: attemptSnapshot,
                userSnapshot: userSnapshot,
              );
            }
            final nextAttemptNumber =
                _existingExamAttemptCount(examSnapshot) + 1;
            final bestPercentage = _existingExamBestPercentage(examSnapshot);
            final shouldReplaceBest = percentage >= bestPercentage;

            transaction.set(attemptDocument, {
              'type': QuizAttemptType.exam.firestoreValue,
              'attemptNumber': nextAttemptNumber,
              'categoryId': categoryId,
              'activityId': null,
              'examId': examId,
              'questionIds': questionIds,
              'answers': _answersByQuestionId(answers),
              'correctAnswers': correctAnswers,
              'totalQuestions': totalQuestions,
              'percentage': percentage,
              'earnedPoints': 0,
              'startedAt': Timestamp.fromDate(startedAt),
              'completedAt': FieldValue.serverTimestamp(),
            });

            transaction.set(examDocument, {
              'examId': examId,
              'status': ActivityProgressStatus.completed.firestoreValue,
              'attemptCount': nextAttemptNumber,
              'bestCorrectAnswers': shouldReplaceBest
                  ? correctAnswers
                  : _existingExamBestCorrectAnswers(examSnapshot),
              'bestTotalQuestions': shouldReplaceBest
                  ? totalQuestions
                  : _existingExamBestTotalQuestions(examSnapshot),
              'bestPercentage': shouldReplaceBest ? percentage : bestPercentage,
              'lastAttemptAt': FieldValue.serverTimestamp(),
              'completedAt':
                  _existingExamCompletedAt(examSnapshot) ??
                  FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });

            if (!categorySnapshot.exists) {
              transaction.set(
                categoryDocument,
                _initialProgressData(
                  categoryId: categoryId,
                  lessonId: lessonId,
                  totalLessonPages: totalLessonPages,
                  totalActivities: totalActivities,
                ),
              );
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
            }

            transaction.update(categoryDocument, {
              'categoryId': categoryId,
              'lessonId': lessonId,
              'status': CategoryProgressStatus.completed.firestoreValue,
              'totalLessonPages': totalLessonPages,
              'totalActivities': totalActivities,
              'lastActivityAt': FieldValue.serverTimestamp(),
              'completedAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
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

  DocumentReference<Map<String, dynamic>> _questionDocument(
    String categoryId,
    String questionId,
  ) {
    return _firestore
        .collection('categories')
        .doc(categoryId)
        .collection('questions')
        .doc(questionId);
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

  Map<String, QuestionScoreRecord> _existingQuestionScores(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    if (!snapshot.exists) {
      return const <String, QuestionScoreRecord>{};
    }
    final value = snapshot.data()?['questionScores'];
    if (value is! Map) {
      return const <String, QuestionScoreRecord>{};
    }

    final scores = <String, QuestionScoreRecord>{};
    for (final entry in value.entries) {
      final questionId = entry.key;
      final data = entry.value;
      if (questionId is! String || data is! Map) {
        continue;
      }
      try {
        final score = QuestionScoreRecord.fromMap(
          questionId: questionId,
          data: Map<String, dynamic>.from(data),
        );
        scores[score.questionId] = score;
      } on FormatException {
        continue;
      }
    }

    return scores;
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

  int _existingExamAttemptCount(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return _readExistingNonNegativeInt(snapshot, 'attemptCount');
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

  Map<String, Map<String, dynamic>> _answersByQuestionId(
    Iterable<CategoryProgressAnswer> answers,
  ) {
    return {
      for (final answer in answers)
        answer.questionId: {
          'questionId': answer.questionId,
          'answer': answer.answer,
          'isCorrect': answer.isCorrect,
          'pointsEarned': answer.pointsEarned,
          'answeredAt': Timestamp.fromDate(answer.answeredAt),
        },
    };
  }

  Map<String, Map<String, dynamic>> _questionScoresByQuestionId(
    Map<String, QuestionScoreRecord> questionScores,
  ) {
    return {
      for (final score in questionScores.values)
        score.questionId: score.toFirestore(),
    };
  }

  _ActivityScoringResult _scoreActivityAnswers({
    required String categoryId,
    required String activityId,
    required int attemptNumber,
    required List<String> questionIds,
    required Iterable<CategoryProgressAnswer> answers,
    required Map<String, DocumentSnapshot<Map<String, dynamic>>>
    questionSnapshots,
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
        throw StateError('Missing answer for question "$questionId".');
      }
      final question = _questionFromSnapshot(
        categoryId: categoryId,
        activityId: activityId,
        snapshot: questionSnapshots[questionId],
      );
      final isCorrect = question.isCorrectAnswer(answer.answer);
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

  QuizQuestion _questionFromSnapshot({
    required String categoryId,
    required String activityId,
    required DocumentSnapshot<Map<String, dynamic>>? snapshot,
  }) {
    if (snapshot == null || !snapshot.exists || snapshot.data() == null) {
      throw StateError('Question content is missing.');
    }
    final question = EducationalContentFirestoreMapper.questionFromMap(
      _contentData(snapshot.data()!),
      documentId: snapshot.id,
      categoryId: categoryId,
    );
    if (question.activityId != activityId) {
      throw StateError('Question does not belong to the requested activity.');
    }
    return question;
  }

  Map<String, Object?> _contentData(Map<String, dynamic> data) {
    return data.map((key, value) => MapEntry(key, _contentValue(value)));
  }

  Object? _contentValue(Object? value) {
    if (value is Map) {
      return value.map((key, mapValue) {
        if (key is! String) {
          throw const FormatException('Content map keys must be strings.');
        }
        return MapEntry(key, _contentValue(mapValue));
      });
    }
    if (value is List) {
      return value.map(_contentValue).toList(growable: false);
    }
    return value;
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
    if (answerIds.length != answers.length ||
        answerIds.length != expectedTotalQuestions) {
      throw StateError('Attempt answers do not match total questions.');
    }
    if (!questionIds.every(answerIds.contains)) {
      throw StateError('Attempt answers do not match question order.');
    }
  }

  CompletedQuizAttemptPersistenceResult _completedAttemptResultFromSnapshots({
    required DocumentSnapshot<Map<String, dynamic>> attemptSnapshot,
    DocumentSnapshot<Map<String, dynamic>>? activitySnapshot,
    DocumentSnapshot<Map<String, dynamic>>? userSnapshot,
  }) {
    final attempt = QuizAttempt.fromFirestore(attemptSnapshot);
    return CompletedQuizAttemptPersistenceResult(
      attemptNumber: attempt.attemptNumber,
      answers: attempt.answers,
      correctAnswers: attempt.correctAnswers,
      totalQuestions: attempt.totalQuestions,
      percentage: attempt.percentage,
      earnedPoints: attempt.earnedPoints,
      activityPoints: activitySnapshot == null
          ? null
          : _existingActivityPoints(activitySnapshot),
      questionScores: activitySnapshot == null
          ? const <String, QuestionScoreRecord>{}
          : _existingQuestionScores(activitySnapshot),
      totalPoints: userSnapshot == null
          ? null
          : _existingUserTotalPoints(userSnapshot),
    );
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
  permissionDenied,
  unavailable,
  firebase,
  unexpected,
}

enum CategoryProgressFailureOperation {
  validateUser,
  fetchAllProgress,
  markTheoryPageViewed,
  startActivityAttempt,
  startExamAttempt,
  recordAttemptAnswer,
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
