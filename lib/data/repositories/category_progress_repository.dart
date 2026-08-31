import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/category_progress.dart';
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

  Future<void> completeActivityAttempt({
    required String uid,
    required String categoryId,
    required String lessonId,
    required String activityId,
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

  Future<void> completeExamAttempt({
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
  Future<void> completeActivityAttempt({
    required String uid,
    required String categoryId,
    required String lessonId,
    required String activityId,
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
    return _runProgressOperation(
      CategoryProgressFailureOperation.completeActivityAttempt,
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
          final completedActivityIds = _existingCompletedActivityIds(
            categorySnapshot,
          );
          if (!completedActivityIds.contains(activityId)) {
            completedActivityIds.add(activityId);
          }
          final categoryCompleted =
              totalActivities > 0 &&
              completedActivityIds.length >= totalActivities;
          final bestPercentage = _existingBestPercentage(activitySnapshot);
          final shouldReplaceBest = percentage >= bestPercentage;

          transaction.set(attemptDocument, {
            'type': QuizAttemptType.activity.firestoreValue,
            'categoryId': categoryId,
            'activityId': activityId,
            'examId': null,
            'questionIds': questionIds,
            'answers': _answersByQuestionId(answers),
            'correctAnswers': correctAnswers,
            'totalQuestions': totalQuestions,
            'percentage': percentage,
            'startedAt': Timestamp.fromDate(startedAt),
            'completedAt': FieldValue.serverTimestamp(),
          });

          transaction.set(activityDocument, {
            'activityId': activityId,
            'status': ActivityProgressStatus.completed.firestoreValue,
            'attemptCount': _existingActivityAttemptCount(activitySnapshot) + 1,
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
            return;
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
        });
      },
    );
  }

  @override
  Future<void> completeExamAttempt({
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
    return _runProgressOperation(
      CategoryProgressFailureOperation.completeExamAttempt,
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
          final bestPercentage = _existingExamBestPercentage(examSnapshot);
          final shouldReplaceBest = percentage >= bestPercentage;

          transaction.set(attemptDocument, {
            'type': QuizAttemptType.exam.firestoreValue,
            'categoryId': categoryId,
            'activityId': null,
            'examId': examId,
            'questionIds': questionIds,
            'answers': _answersByQuestionId(answers),
            'correctAnswers': correctAnswers,
            'totalQuestions': totalQuestions,
            'percentage': percentage,
            'startedAt': Timestamp.fromDate(startedAt),
            'completedAt': FieldValue.serverTimestamp(),
          });

          transaction.set(examDocument, {
            'examId': examId,
            'status': ActivityProgressStatus.completed.firestoreValue,
            'attemptCount': _existingExamAttemptCount(examSnapshot) + 1,
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
            return;
          }

          transaction.update(categoryDocument, {
            'categoryId': categoryId,
            'lessonId': lessonId,
            'totalLessonPages': totalLessonPages,
            'totalActivities': totalActivities,
            'lastActivityAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        });
      },
    );
  }

  DocumentReference<Map<String, dynamic>> _progressDocument(
    String uid,
    String categoryId,
  ) {
    return _progressCollection(uid).doc(categoryId);
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
          'answeredAt': Timestamp.fromDate(answer.answeredAt),
        },
    };
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
