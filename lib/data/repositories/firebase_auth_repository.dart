import 'package:firebase_auth/firebase_auth.dart';

import '../models/auth_user.dart';
import 'auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({FirebaseAuth? firebaseAuth})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _firebaseAuth;

  @override
  AuthUser? get currentUser => _firebaseAuth.currentUser?.toAuthUser();

  @override
  Stream<AuthUser?> authStateChanges() {
    return _firebaseAuth.userChanges().map((user) => user?.toAuthUser());
  }

  @override
  Future<AuthUser> registerWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return _runAuthOperation(() async {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      return _requireUser(credential.user);
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

      return _requireUser(credential.user);
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
      return _firebaseAuth.currentUser?.toAuthUser();
    });
  }

  Future<T> _runAuthOperation<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on AuthException {
      rethrow;
    } on FirebaseAuthException catch (exception) {
      throw AuthException.fromFirebaseCode(exception.code);
    } catch (_) {
      throw const AuthException(AuthFailureReason.unknown);
    }
  }

  AuthUser _requireUser(User? user) {
    if (user == null) {
      throw const AuthException(AuthFailureReason.unknown);
    }

    return user.toAuthUser();
  }
}

extension on User {
  AuthUser toAuthUser() {
    return AuthUser(uid: uid, email: email, isEmailVerified: emailVerified);
  }
}
