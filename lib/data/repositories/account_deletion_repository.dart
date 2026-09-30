import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_profile.dart';
import 'pending_quiz_attempt_repository.dart';

class DeletionProfile {
  const DeletionProfile({
    required this.state,
    required this.usernameNormalized,
  });

  final String state;
  final String? usernameNormalized;
}

abstract class AccountDeletionStore {
  Future<DeletionProfile?> fetchProfile(String uid);
  Future<void> markDeleting(String uid);
  Future<void> deletePersonalData(String uid, String? usernameNormalized);
  Future<void> verifyPersonalDataRemoved(
    String uid,
    String? usernameNormalized,
  );
  Future<void> deleteProfile(String uid);
}

abstract class AccountDeletionIdentity {
  String? get currentUid;
  Future<void> reauthenticate(String password);
  Future<void> deleteCurrentUser();
}

class FirebaseAccountDeletionIdentity implements AccountDeletionIdentity {
  FirebaseAccountDeletionIdentity({FirebaseAuth? auth}) : _auth = auth;

  final FirebaseAuth? _auth;

  FirebaseAuth get _firebaseAuth => _auth ?? FirebaseAuth.instance;

  @override
  String? get currentUid => _firebaseAuth.currentUser?.uid;

  @override
  Future<void> reauthenticate(String password) async {
    final user = _firebaseAuth.currentUser;
    final email = user?.email;
    if (user == null || email == null || email.isEmpty) {
      throw const AccountDeletionException(AccountDeletionFailure.session);
    }
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      );
    } on FirebaseAuthException catch (error) {
      if (error.code == 'wrong-password' ||
          error.code == 'invalid-credential') {
        throw const AccountDeletionException(AccountDeletionFailure.password);
      }
      rethrow;
    }
  }

  @override
  Future<void> deleteCurrentUser() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const AccountDeletionException(AccountDeletionFailure.session);
    }
    await user.delete();
  }
}

class FirestoreAccountDeletionStore implements AccountDeletionStore {
  FirestoreAccountDeletionStore({
    FirebaseFirestore? firestore,
    Future<void> Function(AccountDeletionStage stage)? onStageComplete,
  }) : _firestore = firestore,
       _onStageComplete = onStageComplete;

  final FirebaseFirestore? _firestore;
  final Future<void> Function(AccountDeletionStage stage)? _onStageComplete;

  Future<void> _checkpoint(AccountDeletionStage stage) async {
    await _onStageComplete?.call(stage);
  }

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _profile(String uid) =>
      _db.collection('users').doc(uid);

  Future<DocumentSnapshot<Map<String, dynamic>>> _serverDocument(
    DocumentReference<Map<String, dynamic>> reference,
  ) async {
    final snapshot = await reference.get(
      const GetOptions(source: Source.server),
    );
    if (snapshot.metadata.isFromCache || snapshot.metadata.hasPendingWrites) {
      throw const AccountDeletionException(AccountDeletionFailure.remote);
    }
    return snapshot;
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _serverCollection(
    Query<Map<String, dynamic>> reference,
  ) async {
    final snapshot = await reference.get(
      const GetOptions(source: Source.server),
    );
    if (snapshot.metadata.isFromCache || snapshot.metadata.hasPendingWrites) {
      throw const AccountDeletionException(AccountDeletionFailure.remote);
    }
    return snapshot;
  }

  @override
  Future<DeletionProfile?> fetchProfile(String uid) async {
    final snapshot = await _serverDocument(_profile(uid));
    if (!snapshot.exists) return null;
    final data = snapshot.data()!;
    final state = data['accountState'] ?? AccountState.active;
    if (state != AccountState.active && state != AccountState.deleting) {
      throw const AccountDeletionException(AccountDeletionFailure.remote);
    }
    final username = data['usernameNormalized'];
    return DeletionProfile(
      state: state as String,
      usernameNormalized: username is String ? username : null,
    );
  }

  @override
  Future<void> markDeleting(String uid) async {
    try {
      await _profile(uid).update({
        'accountState': AccountState.deleting,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // A transport error may arrive after the server committed the update.
      final profile = await fetchProfile(uid);
      if (profile?.state != AccountState.deleting) rethrow;
    }
    final profile = await fetchProfile(uid);
    if (profile?.state != AccountState.deleting) {
      throw const AccountDeletionException(AccountDeletionFailure.remote);
    }
  }

  @override
  Future<void> deletePersonalData(
    String uid,
    String? usernameNormalized,
  ) async {
    final categories = _profile(uid).collection('categoryProgress');
    for (final category in (await _serverCollection(categories)).docs) {
      final activities = category.reference.collection('activities');
      for (final activity in (await _serverCollection(activities)).docs) {
        await _deleteCollection(
          activity.reference.collection('answerSubmissions'),
        );
        await _deleteCollection(activity.reference.collection('attempts'));
        await _verifyEmpty(activity.reference.collection('answerSubmissions'));
        await _verifyEmpty(activity.reference.collection('attempts'));
        await activity.reference.delete();
      }
      await _checkpoint(AccountDeletionStage.activities);
      final exams = category.reference.collection('exams');
      for (final exam in (await _serverCollection(exams)).docs) {
        final attempts = exam.reference.collection('attempts');
        for (final attempt in (await _serverCollection(attempts)).docs) {
          await _deleteCollection(attempt.reference.collection('proofs'));
          await _verifyEmpty(attempt.reference.collection('proofs'));
        }
        await _deleteCollection(exam.reference.collection('answerSubmissions'));
        await _deleteCollection(attempts);
        await _verifyEmpty(exam.reference.collection('answerSubmissions'));
        await _verifyEmpty(attempts);
        await exam.reference.delete();
      }
      await _checkpoint(AccountDeletionStage.exams);
      await _verifyEmpty(activities);
      await _verifyEmpty(exams);
      await category.reference.delete();
      await _checkpoint(AccountDeletionStage.categoryProgress);
    }
    await _verifyEmpty(categories);
    await _db.collection('leaderboard').doc(uid).delete();
    await _checkpoint(AccountDeletionStage.leaderboard);
    if (usernameNormalized != null) {
      final username = _db.collection('usernames').doc(usernameNormalized);
      if ((await _serverDocument(username)).exists) {
        await username.delete();
      }
    }
    await _checkpoint(AccountDeletionStage.username);
  }

  Future<void> _deleteCollection(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    while (true) {
      final documents = (await _serverCollection(collection.limit(100))).docs;
      if (documents.isEmpty) return;
      for (final document in documents) {
        await document.reference.delete();
      }
    }
  }

  Future<void> _verifyEmpty(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    if ((await _serverCollection(collection.limit(1))).docs.isNotEmpty) {
      throw const AccountDeletionException(AccountDeletionFailure.remote);
    }
  }

  @override
  Future<void> verifyPersonalDataRemoved(
    String uid,
    String? usernameNormalized,
  ) async {
    await _verifyEmpty(_profile(uid).collection('categoryProgress'));
    if ((await _serverDocument(
      _db.collection('leaderboard').doc(uid),
    )).exists) {
      throw const AccountDeletionException(AccountDeletionFailure.remote);
    }
    if (usernameNormalized != null &&
        (await _serverDocument(
          _db.collection('usernames').doc(usernameNormalized),
        )).exists) {
      throw const AccountDeletionException(AccountDeletionFailure.remote);
    }
  }

  @override
  Future<void> deleteProfile(String uid) async {
    await _profile(uid).delete();
    if (await fetchProfile(uid) != null) {
      throw const AccountDeletionException(AccountDeletionFailure.remote);
    }
    await _checkpoint(AccountDeletionStage.profile);
  }
}

enum AccountDeletionStage {
  activities,
  exams,
  categoryProgress,
  leaderboard,
  username,
  profile,
}

enum AccountDeletionFailure { password, recentLogin, session, remote }

class AccountDeletionException implements Exception {
  const AccountDeletionException(this.reason);

  final AccountDeletionFailure reason;

  String get userMessage => switch (reason) {
    AccountDeletionFailure.password => 'La contraseña no es correcta.',
    AccountDeletionFailure.recentLogin =>
      'Vuelve a ingresar tu contraseña para finalizar la eliminación.',
    AccountDeletionFailure.session =>
      'Tu sesión cambió. Inicia sesión para continuar la eliminación.',
    AccountDeletionFailure.remote =>
      'No pudimos completar la eliminación. Puedes volver a intentarlo.',
  };
}

class AccountDeletionService {
  AccountDeletionService({
    required AccountDeletionIdentity identity,
    required AccountDeletionStore store,
    required PendingQuizAttemptRepository pending,
    Future<void> Function(String uid)? suspendPendingSync,
  }) : _identity = identity,
       _store = store,
       _pending = pending,
       _suspendPendingSync = suspendPendingSync;

  final AccountDeletionIdentity _identity;
  final AccountDeletionStore _store;
  final PendingQuizAttemptRepository _pending;
  final Future<void> Function(String uid)? _suspendPendingSync;

  String _uid() {
    final uid = _identity.currentUid;
    if (uid == null || uid.isEmpty) {
      throw const AccountDeletionException(AccountDeletionFailure.session);
    }
    return uid;
  }

  Future<DeletionProfile?> inspectCurrentProfile() =>
      _store.fetchProfile(_uid());

  Future<void> start(String password) async {
    final uid = _uid();
    final profile = await _store.fetchProfile(uid);
    if (profile == null || profile.state != AccountState.active) {
      throw const AccountDeletionException(AccountDeletionFailure.remote);
    }
    await _identity.reauthenticate(password);
    if (_uid() != uid) {
      throw const AccountDeletionException(AccountDeletionFailure.session);
    }
    await _suspendPendingSync?.call(uid);
    await _store.markDeleting(uid);
    await resume();
  }

  Future<void> resume() async {
    final uid = _uid();
    final profile = await _store.fetchProfile(uid);
    if (profile != null) {
      if (profile.state != AccountState.deleting) {
        throw const AccountDeletionException(AccountDeletionFailure.remote);
      }
      await _store.deletePersonalData(uid, profile.usernameNormalized);
      await _store.verifyPersonalDataRemoved(uid, profile.usernameNormalized);
      await _store.deleteProfile(uid);
    }
    await _pending.removeForUid(uid);
    if (_uid() != uid) {
      throw const AccountDeletionException(AccountDeletionFailure.session);
    }
    try {
      await _identity.deleteCurrentUser();
    } on FirebaseAuthException catch (error) {
      if (error.code == 'requires-recent-login') {
        throw const AccountDeletionException(
          AccountDeletionFailure.recentLogin,
        );
      }
      throw const AccountDeletionException(AccountDeletionFailure.remote);
    }
  }

  Future<void> retryAuthOnly(String password) async {
    final uid = _uid();
    if (await _store.fetchProfile(uid) != null) {
      throw const AccountDeletionException(AccountDeletionFailure.remote);
    }
    await _identity.reauthenticate(password);
    if (_uid() != uid) {
      throw const AccountDeletionException(AccountDeletionFailure.session);
    }
    await _pending.removeForUid(uid);
    try {
      await _identity.deleteCurrentUser();
    } on FirebaseAuthException catch (error) {
      if (error.code == 'requires-recent-login') {
        throw const AccountDeletionException(
          AccountDeletionFailure.recentLogin,
        );
      }
      throw const AccountDeletionException(AccountDeletionFailure.remote);
    }
  }
}
