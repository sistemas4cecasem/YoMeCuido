import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/auth_user.dart';
import 'auth_repository.dart';
import 'user_profile_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    FirebaseAuth? firebaseAuth,
    UserProfileRepository? userProfileRepository,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _userProfileRepository =
           userProfileRepository ?? UserProfileRepository();

  final FirebaseAuth _firebaseAuth;
  final UserProfileRepository _userProfileRepository;

  @override
  AuthUser? get currentUser => _firebaseAuth.currentUser?.toAuthUser();

  @override
  Stream<AuthUser?> authStateChanges() {
    return _firebaseAuth.userChanges().map((user) {
      if (user == null) {
        return null;
      }

      return user.toAuthUser();
    });
  }

  @override
  Future<AuthUser> registerWithEmailAndPassword({
    required String username,
    required String email,
    required String password,
  }) async {
    return _runAuthOperation(() async {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = _requireUser(credential.user);
      try {
        await _userProfileRepository.createProfileForNewUser(
          uid: user.uid,
          email: user.email,
          username: username,
        );
      } on UserProfileException {
        await _deleteNewlyCreatedUser(user);
        rethrow;
      }
      return user.toAuthUser();
    });
  }

  @override
  Future<AuthUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return _runAuthOperation(() async {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = _requireUser(credential.user);
      return user.toAuthUser();
    });
  }

  @override
  Future<void> signOut() {
    return _runAuthOperation(_firebaseAuth.signOut);
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) {
    return _runAuthOperation(
      () => _firebaseAuth.sendPasswordResetEmail(email: email),
    );
  }

  @override
  Future<void> sendEmailVerification() {
    return _runAuthOperation(() async {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        throw const AuthException(AuthFailureReason.unknown);
      }

      await user.sendEmailVerification();
    });
  }

  @override
  Future<AuthUser?> reloadCurrentUser() {
    return _runAuthOperation(() async {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        return null;
      }

      await user.reload();
      final reloadedUser = _firebaseAuth.currentUser;
      if (reloadedUser == null) {
        return null;
      }

      return reloadedUser.toAuthUser();
    });
  }

  Future<T> _runAuthOperation<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on AuthException {
      rethrow;
    } on FirebaseAuthException catch (exception) {
      throw AuthException.fromFirebaseCode(exception.code);
    } on UserProfileException catch (exception) {
      exception.logForDebug();
      throw AuthException(_mapProfileFailure(exception.reason));
    } catch (_) {
      throw const AuthException(AuthFailureReason.unknown);
    }
  }

  User _requireUser(User? user) {
    if (user == null) {
      throw const AuthException(AuthFailureReason.unknown);
    }

    return user;
  }

  Future<void> _deleteNewlyCreatedUser(User user) async {
    try {
      await user.delete();
    } on FirebaseAuthException catch (exception) {
      if (kDebugMode) {
        debugPrint(
          '[Auth] Could not delete partially initialized user '
          '${user.uid}: ${exception.code}',
        );
      }
      await _firebaseAuth.signOut();
    }
  }

  AuthFailureReason _mapProfileFailure(UserProfileFailureReason reason) {
    return switch (reason) {
      UserProfileFailureReason.invalidUsername =>
        AuthFailureReason.usernameInvalid,
      UserProfileFailureReason.usernameAlreadyInUse =>
        AuthFailureReason.usernameAlreadyInUse,
      _ => AuthFailureReason.userProfileUnavailable,
    };
  }
}

extension on User {
  AuthUser toAuthUser() {
    return AuthUser(uid: uid, email: email, isEmailVerified: emailVerified);
  }
}
