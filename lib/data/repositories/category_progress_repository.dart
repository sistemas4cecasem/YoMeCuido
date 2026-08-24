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
    required int totalLessonPages,
    required int totalActivities,
  });

  Future<void> recordActivityAnswer({
    required String uid,
    required String categoryId,
    required String lessonId,
    required String activityId,
    required String answer,
    required bool isCorrect,
    required int correctAnswers,
    required int totalLessonPages,
    required int totalActivities,
    required bool isCompleted,
  });
}

class CategoryProgressRepository implements CategoryProgressPersistence {
  CategoryProgressRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static const progressCollection = 'categoryProgress';

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
            records.add(CategoryProgressRecord.fromFirestore(document));
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
                attemptCount: 0,
              ),
              'viewedLessonPageIds': <String>[pageId],
            });
            return;
          }

          final status = _existingStatus(snapshot);
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
    required int totalLessonPages,
    required int totalActivities,
  }) {
    return _runProgressOperation(
      CategoryProgressFailureOperation.startActivityAttempt,
      () async {
        _validateUser(uid);
        final document = _progressDocument(uid, categoryId);

        await _firestore.runTransaction<void>((transaction) async {
          final snapshot = await transaction.get(document);
          final nextAttemptCount = _existingAttemptCount(snapshot) + 1;
          final attemptData = <String, dynamic>{
            'categoryId': categoryId,
            'lessonId': lessonId,
            'status': CategoryProgressStatus.inProgress.firestoreValue,
            'completedActivityIds': <String>[],
            'correctAnswers': 0,
            'totalLessonPages': totalLessonPages,
            'totalActivities': totalActivities,
            'attemptCount': nextAttemptCount,
            'lastActivityAt': null,
            'completedAt': null,
            'updatedAt': FieldValue.serverTimestamp(),
            'latestAnswers': <String, Map<String, dynamic>>{},
          };

          if (!snapshot.exists) {
            transaction.set(document, {
              ..._initialProgressData(
                categoryId: categoryId,
                lessonId: lessonId,
                totalLessonPages: totalLessonPages,
                totalActivities: totalActivities,
                attemptCount: nextAttemptCount,
              ),
              ...attemptData,
            });
            return;
          }

          transaction.update(document, attemptData);
        });
      },
    );
  }

  @override
  Future<void> recordActivityAnswer({
    required String uid,
    required String categoryId,
    required String lessonId,
    required String activityId,
    required String answer,
    required bool isCorrect,
    required int correctAnswers,
    required int totalLessonPages,
    required int totalActivities,
    required bool isCompleted,
  }) {
    return _runProgressOperation(
      CategoryProgressFailureOperation.recordActivityAnswer,
      () async {
        _validateUser(uid);
        final document = _progressDocument(uid, categoryId);
        final answerData = <String, dynamic>{
          'answer': answer,
          'isCorrect': isCorrect,
          'answeredAt': FieldValue.serverTimestamp(),
        };

        await _firestore.runTransaction<void>((transaction) async {
          final snapshot = await transaction.get(document);
          final answerUpdate = <String, dynamic>{
            'categoryId': categoryId,
            'lessonId': lessonId,
            'status': isCompleted
                ? CategoryProgressStatus.completed.firestoreValue
                : CategoryProgressStatus.inProgress.firestoreValue,
            'completedActivityIds': FieldValue.arrayUnion(<String>[activityId]),
            'correctAnswers': correctAnswers,
            'totalLessonPages': totalLessonPages,
            'totalActivities': totalActivities,
            'lastActivityAt': FieldValue.serverTimestamp(),
            'completedAt': isCompleted ? FieldValue.serverTimestamp() : null,
            'updatedAt': FieldValue.serverTimestamp(),
            'latestAnswers.$activityId': answerData,
          };

          if (!snapshot.exists) {
            transaction.set(document, {
              ..._initialProgressData(
                categoryId: categoryId,
                lessonId: lessonId,
                totalLessonPages: totalLessonPages,
                totalActivities: totalActivities,
                attemptCount: 0,
              ),
              'status': isCompleted
                  ? CategoryProgressStatus.completed.firestoreValue
                  : CategoryProgressStatus.inProgress.firestoreValue,
              'completedActivityIds': <String>[activityId],
              'correctAnswers': correctAnswers,
              'totalLessonPages': totalLessonPages,
              'totalActivities': totalActivities,
              'lastActivityAt': FieldValue.serverTimestamp(),
              'completedAt': isCompleted ? FieldValue.serverTimestamp() : null,
              'updatedAt': FieldValue.serverTimestamp(),
              'latestAnswers': <String, Map<String, dynamic>>{
                activityId: answerData,
              },
            });
            return;
          }

          transaction.update(document, answerUpdate);
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

  Map<String, dynamic> _initialProgressData({
    required String categoryId,
    required String lessonId,
    required int totalLessonPages,
    required int totalActivities,
    required int attemptCount,
  }) {
    return {
      'categoryId': categoryId,
      'lessonId': lessonId,
      'status': CategoryProgressStatus.inProgress.firestoreValue,
      'viewedLessonPageIds': <String>[],
      'completedActivityIds': <String>[],
      'correctAnswers': 0,
      'totalLessonPages': totalLessonPages,
      'totalActivities': totalActivities,
      'attemptCount': attemptCount,
      'startedAt': FieldValue.serverTimestamp(),
      'lastActivityAt': null,
      'completedAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
      'latestAnswers': <String, Map<String, dynamic>>{},
    };
  }

  int _existingAttemptCount(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    if (!snapshot.exists) {
      return 0;
    }

    final value = snapshot.data()?['attemptCount'];
    if (value is int && value >= 0) {
      return value;
    }

    return 0;
  }

  CategoryProgressStatus _existingStatus(
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
  recordActivityAnswer,
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
