import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/username.dart';
import '../models/user_profile.dart';

class UserProfileRepository {
  UserProfileRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  @protected
  UserProfileRepository.testing() : _firestore = null;

  static const usersCollection = 'users';
  static const usernamesCollection = 'usernames';

  final FirebaseFirestore? _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _requireFirestore.collection(usersCollection);

  CollectionReference<Map<String, dynamic>> get _usernames =>
      _requireFirestore.collection(usernamesCollection);

  FirebaseFirestore get _requireFirestore {
    final firestore = _firestore;
    if (firestore == null) {
      throw StateError('UserProfileRepository has no Firestore instance.');
    }
    return firestore;
  }

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

  Future<UserProfile> createProfileForNewUser({
    required String uid,
    required String? email,
    required String username,
  }) async {
    return _reserveUsernameAndUpsertProfile(
      uid: uid,
      email: email,
      username: username,
      operation: UserProfileFailureOperation.create,
      requireMissingCompleteProfile: true,
    );
  }

  Future<UserProfile> completeProfile({
    required String uid,
    required String? email,
    required String username,
  }) {
    return _reserveUsernameAndUpsertProfile(
      uid: uid,
      email: email,
      username: username,
      operation: UserProfileFailureOperation.complete,
      requireMissingCompleteProfile: false,
    );
  }

  Future<UserProfile> changeUsername({
    required String uid,
    required String? email,
    required String username,
  }) {
    return _reserveUsernameAndUpsertProfile(
      uid: uid,
      email: email,
      username: username,
      operation: UserProfileFailureOperation.changeUsername,
      requireMissingCompleteProfile: false,
      allowUsernameChange: true,
    );
  }

  Future<UserProfile> _reserveUsernameAndUpsertProfile({
    required String uid,
    required String? email,
    required String username,
    required UserProfileFailureOperation operation,
    required bool requireMissingCompleteProfile,
    bool allowUsernameChange = false,
  }) async {
    _validateUid(uid, operation);
    final normalizedEmail = _normalizeEmail(email, operation);
    final trimmedUsername = username.trim();
    final usernameError = Username.validate(trimmedUsername);
    if (usernameError != null) {
      throw UserProfileException(
        UserProfileFailureReason.invalidUsername,
        operation: operation,
        technicalMessage: usernameError.userMessage,
      );
    }
    final usernameNormalized = Username.normalize(trimmedUsername);
    final profileDocument = _users.doc(uid);
    final usernameDocument = _usernames.doc(usernameNormalized);

    try {
      await _requireFirestore.runTransaction<void>((transaction) async {
        final profileSnapshot = await transaction.get(profileDocument);
        final usernameSnapshot = await transaction.get(usernameDocument);

        if (usernameSnapshot.exists) {
          final claimedUid = usernameSnapshot.data()?['uid'];
          if (claimedUid != uid) {
            throw const UserProfileException(
              UserProfileFailureReason.usernameAlreadyInUse,
              operation: UserProfileFailureOperation.reserveUsername,
            );
          }
        }

        if (profileSnapshot.exists) {
          final profile = UserProfile.fromFirestore(profileSnapshot);
          if (profile.hasUsername) {
            if (allowUsernameChange) {
              if (profile.username == trimmedUsername) return;
              if (!usernameSnapshot.exists) {
                transaction.set(usernameDocument, {'uid': uid});
              }
              transaction.update(profileDocument, {
                'username': trimmedUsername,
                'usernameNormalized': usernameNormalized,
                'updatedAt': FieldValue.serverTimestamp(),
              });
              if (profile.usernameNormalized != usernameNormalized) {
                transaction.delete(_usernames.doc(profile.usernameNormalized!));
              }
              return;
            }
            if (requireMissingCompleteProfile ||
                profile.usernameNormalized != usernameNormalized) {
              throw const UserProfileException(
                UserProfileFailureReason.profileAlreadyComplete,
                operation: UserProfileFailureOperation.create,
              );
            }
            return;
          }
        }

        if (allowUsernameChange) {
          throw const UserProfileException(
            UserProfileFailureReason.invalidDocument,
            operation: UserProfileFailureOperation.changeUsername,
          );
        }

        if (!usernameSnapshot.exists) {
          transaction.set(usernameDocument, {'uid': uid});
        }

        if (profileSnapshot.exists) {
          transaction.update(profileDocument, {
            'username': trimmedUsername,
            'usernameNormalized': usernameNormalized,
            'email': normalizedEmail,
            'role': UserProfileRole.user,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          return;
        }

        transaction.set(profileDocument, {
          'username': trimmedUsername,
          'usernameNormalized': usernameNormalized,
          'email': normalizedEmail,
          'role': UserProfileRole.user,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } on FirebaseException catch (exception, stackTrace) {
      throw UserProfileException.fromFirebaseException(
        operation,
        exception,
        stackTrace,
      );
    } on FormatException catch (exception, stackTrace) {
      throw UserProfileException(
        UserProfileFailureReason.invalidDocument,
        operation: operation,
        technicalMessage: exception.message,
        stackTrace: stackTrace,
      );
    } on UserProfileException {
      rethrow;
    } catch (error, stackTrace) {
      throw UserProfileException(
        UserProfileFailureReason.unexpected,
        operation: operation,
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

  void _validateUid(String uid, UserProfileFailureOperation operation) {
    if (uid.trim().isEmpty) {
      throw UserProfileException(
        UserProfileFailureReason.unauthenticated,
        operation: operation,
      );
    }
  }

  String _normalizeEmail(String? email, UserProfileFailureOperation operation) {
    final normalizedEmail = email?.trim();
    if (normalizedEmail == null || normalizedEmail.isEmpty) {
      throw UserProfileException(
        UserProfileFailureReason.missingEmail,
        operation: operation,
      );
    }
    return normalizedEmail;
  }
}

enum UserProfileFailureReason {
  unauthenticated,
  missingEmail,
  invalidUsername,
  usernameAlreadyInUse,
  profileAlreadyComplete,
  permissionDenied,
  notFound,
  invalidDocument,
  missingAfterCreate,
  firebase,
  unexpected,
}

enum UserProfileFailureOperation {
  fetch,
  create,
  complete,
  reserveUsername,
  changeUsername,
}

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

  String get userMessage {
    return switch (reason) {
      UserProfileFailureReason.invalidUsername =>
        technicalMessage ?? 'El nombre de usuario no es válido.',
      UserProfileFailureReason.usernameAlreadyInUse =>
        'Este nombre de usuario ya está en uso.',
      UserProfileFailureReason.missingEmail =>
        'No pudimos confirmar el correo de tu cuenta.',
      UserProfileFailureReason.permissionDenied =>
        'No pudimos guardar tu perfil. Revisa tu sesión e intenta nuevamente.',
      UserProfileFailureReason.unauthenticated =>
        'Debes iniciar sesión para completar tu perfil.',
      _ => 'No pudimos preparar tu perfil. Intenta nuevamente.',
    };
  }

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
