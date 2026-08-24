import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/user_profile.dart';

class UserProfileRepository {
  UserProfileRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static const usersCollection = 'users';

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(usersCollection);

  Future<UserProfile?> fetchProfile(String uid) async {
    try {
      final snapshot = await _users.doc(uid).get();
      if (!snapshot.exists) {
        return null;
      }

      return UserProfile.fromFirestore(snapshot);
    } on FirebaseException catch (exception, stackTrace) {
      throw UserProfileException.fromFirebaseException(
        UserProfileFailureOperation.fetch,
        exception,
        stackTrace,
      );
    } on FormatException catch (exception, stackTrace) {
      throw UserProfileException(
        UserProfileFailureReason.invalidDocument,
        operation: UserProfileFailureOperation.fetch,
        technicalMessage: exception.message,
        stackTrace: stackTrace,
      );
    } catch (error, stackTrace) {
      throw UserProfileException(
        UserProfileFailureReason.unexpected,
        operation: UserProfileFailureOperation.fetch,
        technicalMessage: error.toString(),
        stackTrace: stackTrace,
      );
    }
  }

  Future<UserProfile> ensureProfile({
    required String uid,
    required String? email,
  }) async {
    if (uid.trim().isEmpty) {
      throw const UserProfileException(
        UserProfileFailureReason.unauthenticated,
        operation: UserProfileFailureOperation.ensure,
      );
    }

    final existingProfile = await fetchProfile(uid);
    if (existingProfile != null) {
      return existingProfile;
    }

    final normalizedEmail = email?.trim();
    if (normalizedEmail == null || normalizedEmail.isEmpty) {
      throw const UserProfileException(
        UserProfileFailureReason.missingEmail,
        operation: UserProfileFailureOperation.ensure,
      );
    }

    final document = _users.doc(uid);
    try {
      await _firestore.runTransaction<void>((transaction) async {
        final snapshot = await transaction.get(document);
        if (snapshot.exists) {
          return;
        }

        transaction.set(document, {
          'email': normalizedEmail,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } on FirebaseException catch (exception, stackTrace) {
      throw UserProfileException.fromFirebaseException(
        UserProfileFailureOperation.create,
        exception,
        stackTrace,
      );
    } catch (error, stackTrace) {
      throw UserProfileException(
        UserProfileFailureReason.unexpected,
        operation: UserProfileFailureOperation.create,
        technicalMessage: error.toString(),
        stackTrace: stackTrace,
      );
    }

    final createdProfile = await fetchProfile(uid);
    if (createdProfile == null) {
      throw const UserProfileException(
        UserProfileFailureReason.missingAfterCreate,
        operation: UserProfileFailureOperation.fetch,
      );
    }

    return createdProfile;
  }
}

enum UserProfileFailureReason {
  unauthenticated,
  missingEmail,
  permissionDenied,
  notFound,
  invalidDocument,
  missingAfterCreate,
  firebase,
  unexpected,
}

enum UserProfileFailureOperation { fetch, create, ensure }

class UserProfileException implements Exception {
  const UserProfileException(
    this.reason, {
    required this.operation,
    this.firebaseCode,
    this.technicalMessage,
    this.stackTrace,
  });

  factory UserProfileException.fromFirebaseException(
    UserProfileFailureOperation operation,
    FirebaseException exception,
    StackTrace stackTrace,
  ) {
    final reason = switch (exception.code) {
      'permission-denied' => UserProfileFailureReason.permissionDenied,
      'not-found' => UserProfileFailureReason.notFound,
      _ => UserProfileFailureReason.firebase,
    };

    return UserProfileException(
      reason,
      operation: operation,
      firebaseCode: exception.code,
      technicalMessage: exception.message,
      stackTrace: stackTrace,
    );
  }

  final UserProfileFailureReason reason;
  final UserProfileFailureOperation operation;
  final String? firebaseCode;
  final String? technicalMessage;
  final StackTrace? stackTrace;

  void logForDebug() {
    if (!kDebugMode) {
      return;
    }

    debugPrint(
      '[UserProfile] $operation failed: $reason'
      '${firebaseCode == null ? '' : ' ($firebaseCode)'}'
      '${technicalMessage == null ? '' : ' - $technicalMessage'}',
    );
    final stackTrace = this.stackTrace;
    if (stackTrace != null) {
      debugPrint('[UserProfile] StackTrace: $stackTrace');
    }
  }

  @override
  String toString() {
    return 'UserProfileException($operation, $reason, $firebaseCode, '
        '$technicalMessage)';
  }
}
