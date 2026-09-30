import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_yomecuido/data/models/user_profile.dart';
import 'package:demo_yomecuido/data/repositories/account_deletion_repository.dart';
import 'package:demo_yomecuido/data/repositories/auth_repository.dart';
import 'package:demo_yomecuido/data/repositories/firebase_auth_repository.dart';
import 'package:demo_yomecuido/data/repositories/user_profile_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const email = 'persona@example.com';
  const password = 'password123';

  test(
    'successful registration creates Auth, profile, username and ranking',
    () async {
      final firestore = FakeFirebaseFirestore();
      final auth = _MemoryAuth();
      final repository = FirebaseAuthRepository(
        firebaseAuth: auth,
        userProfileRepository: UserProfileRepository(firestore: firestore),
      );

      final user = await repository.registerWithEmailAndPassword(
        username: 'Persona',
        email: email,
        password: password,
      );

      expect(auth.contains(email), isTrue);
      expect(
        (await firestore.collection('users').doc(user.uid).get()).data(),
        containsPair('usernameNormalized', 'persona'),
      );
      expect(
        (await firestore.collection('usernames').doc('persona').get()).data(),
        containsPair('uid', user.uid),
      );
      expect(
        (await firestore.collection('leaderboard').doc(user.uid).get()).data(),
        containsPair('totalPoints', 0),
      );
    },
  );

  test(
    'deleted account releases its username for a new registration',
    () async {
      final firestore = FakeFirebaseFirestore();
      final auth = _MemoryAuth();
      final repository = FirebaseAuthRepository(
        firebaseAuth: auth,
        userProfileRepository: UserProfileRepository(firestore: firestore),
      );
      final first = await repository.registerWithEmailAndPassword(
        username: 'Persona',
        email: email,
        password: password,
      );
      await firestore.collection('users').doc(first.uid).update({
        'accountState': AccountState.deleting,
      });
      final deletionStore = FirestoreAccountDeletionStore(firestore: firestore);
      await deletionStore.deletePersonalData(first.uid, 'persona');
      await deletionStore.verifyPersonalDataRemoved(first.uid, 'persona');
      await deletionStore.deleteProfile(first.uid);
      await auth.currentUser!.delete();

      final second = await repository.registerWithEmailAndPassword(
        username: 'Persona',
        email: 'otra@example.com',
        password: password,
      );
      expect(second.uid, isNot(first.uid));
      expect(
        (await firestore.collection('usernames').doc('persona').get()).data(),
        containsPair('uid', second.uid),
      );
      expect(
        (await firestore.collection('users').doc(second.uid).get()).exists,
        isTrue,
      );
    },
  );

  test(
    'Auth creation failure leaves Firestore empty and permits retry',
    () async {
      final firestore = FakeFirebaseFirestore();
      final auth = _MemoryAuth()..failNextCreate = true;
      final repository = FirebaseAuthRepository(
        firebaseAuth: auth,
        userProfileRepository: UserProfileRepository(firestore: firestore),
      );

      await expectLater(
        repository.registerWithEmailAndPassword(
          username: 'Persona',
          email: email,
          password: password,
        ),
        throwsA(
          isA<AuthException>().having(
            (error) => error.reason,
            'reason',
            AuthFailureReason.networkRequestFailed,
          ),
        ),
      );
      expect(auth.contains(email), isFalse);
      await _expectNoUserDocuments(firestore, 'uid-1', 'persona');

      final retry = await repository.registerWithEmailAndPassword(
        username: 'Persona',
        email: email,
        password: password,
      );
      expect(auth.contains(email), isTrue);
      expect(
        (await firestore.collection('users').doc(retry.uid).get()).exists,
        isTrue,
      );
    },
  );

  test(
    'pre-transaction validation rolls back Auth and permits same email',
    () async {
      final firestore = FakeFirebaseFirestore();
      final auth = _MemoryAuth();
      final repository = FirebaseAuthRepository(
        firebaseAuth: auth,
        userProfileRepository: UserProfileRepository(firestore: firestore),
      );

      await expectLater(
        repository.registerWithEmailAndPassword(
          username: 'x',
          email: email,
          password: password,
        ),
        throwsA(
          isA<AuthException>().having(
            (error) => error.reason,
            'reason',
            AuthFailureReason.usernameInvalid,
          ),
        ),
      );
      expect(auth.contains(email), isFalse);
      await _expectNoUserDocuments(firestore, 'uid-1', 'x');

      final retry = await repository.registerWithEmailAndPassword(
        username: 'Persona',
        email: email,
        password: password,
      );
      expect(auth.contains(email), isTrue);
      expect(
        (await firestore.collection('users').doc(retry.uid).get()).exists,
        isTrue,
      );
    },
  );

  test(
    'transactional username conflict rolls back Auth without new data',
    () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('usernames').doc('persona').set({
        'uid': 'other',
      });
      final auth = _MemoryAuth();
      final repository = FirebaseAuthRepository(
        firebaseAuth: auth,
        userProfileRepository: UserProfileRepository(firestore: firestore),
      );

      await expectLater(
        repository.registerWithEmailAndPassword(
          username: 'Persona',
          email: email,
          password: password,
        ),
        throwsA(
          isA<AuthException>().having(
            (error) => error.reason,
            'reason',
            AuthFailureReason.usernameAlreadyInUse,
          ),
        ),
      );
      expect(auth.contains(email), isFalse);
      expect(
        (await firestore.collection('users').doc('uid-1').get()).exists,
        isFalse,
      );
      expect(
        (await firestore.collection('leaderboard').doc('uid-1').get()).exists,
        isFalse,
      );
      expect(
        (await firestore.collection('usernames').doc('persona').get()).data(),
        containsPair('uid', 'other'),
      );

      final retry = await repository.registerWithEmailAndPassword(
        username: 'Otra',
        email: email,
        password: password,
      );
      expect(
        (await firestore.collection('usernames').doc('otra').get()).data(),
        containsPair('uid', retry.uid),
      );
    },
  );

  test(
    'rejected Firestore transaction rolls back Auth without new data',
    () async {
      final firestore = _RejectedTransactionFirestore();
      final auth = _MemoryAuth();
      final repository = FirebaseAuthRepository(
        firebaseAuth: auth,
        userProfileRepository: UserProfileRepository(firestore: firestore),
      );

      await expectLater(
        repository.registerWithEmailAndPassword(
          username: 'Persona',
          email: email,
          password: password,
        ),
        throwsA(isA<AuthException>()),
      );
      expect(auth.contains(email), isFalse);
      await _expectNoUserDocuments(firestore, 'uid-1', 'persona');

      firestore.rejectWrites = false;
      final retry = await repository.registerWithEmailAndPassword(
        username: 'Persona',
        email: email,
        password: password,
      );
      expect(
        (await firestore.collection('users').doc(retry.uid).get()).exists,
        isTrue,
      );
    },
  );

  test(
    'registration never re-reads the profile after transaction commit',
    () async {
      final firestore = FakeFirebaseFirestore();
      final profileRepository = _FailingFetchProfileRepository(firestore);
      final auth = _MemoryAuth();
      final repository = FirebaseAuthRepository(
        firebaseAuth: auth,
        userProfileRepository: profileRepository,
      );

      final user = await repository.registerWithEmailAndPassword(
        username: 'Persona',
        email: email,
        password: password,
      );

      expect(profileRepository.fetchCalls, 0);
      expect(auth.contains(email), isTrue);
      expect(
        (await firestore.collection('users').doc(user.uid).get()).exists,
        isTrue,
      );
      expect(
        (await firestore.collection('usernames').doc('persona').get()).exists,
        isTrue,
      );
      expect(
        (await firestore.collection('leaderboard').doc(user.uid).get()).exists,
        isTrue,
      );
    },
  );

  test(
    'uncertain commit response preserves Auth for recovery by login',
    () async {
      final firestore = _AfterCommitFailureFirestore();
      final auth = _MemoryAuth();
      final repository = FirebaseAuthRepository(
        firebaseAuth: auth,
        userProfileRepository: UserProfileRepository(firestore: firestore),
      );

      await expectLater(
        repository.registerWithEmailAndPassword(
          username: 'Persona',
          email: email,
          password: password,
        ),
        throwsA(
          isA<AuthException>().having(
            (error) => error.reason,
            'reason',
            AuthFailureReason.registrationNeedsSignIn,
          ),
        ),
      );

      expect(auth.contains(email), isTrue);
      expect(
        (await firestore.collection('users').doc('uid-1').get()).exists,
        isTrue,
      );
      expect(
        (await firestore.collection('usernames').doc('persona').get()).exists,
        isTrue,
      );
      expect(
        (await firestore.collection('leaderboard').doc('uid-1').get()).exists,
        isTrue,
      );
      final signedIn = await repository.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      expect(signedIn.uid, 'uid-1');
    },
  );
}

Future<void> _expectNoUserDocuments(
  FakeFirebaseFirestore firestore,
  String uid,
  String username,
) async {
  expect((await firestore.collection('users').doc(uid).get()).exists, isFalse);
  expect(
    (await firestore.collection('usernames').doc(username).get()).exists,
    isFalse,
  );
  expect(
    (await firestore.collection('leaderboard').doc(uid).get()).exists,
    isFalse,
  );
}

class _FailingFetchProfileRepository extends UserProfileRepository {
  _FailingFetchProfileRepository(FirebaseFirestore firestore)
    : super(firestore: firestore);

  int fetchCalls = 0;

  @override
  Future<UserProfile?> fetchProfile(String uid) async {
    fetchCalls += 1;
    throw StateError('The post-commit read must not run.');
  }
}

class _AfterCommitFailureFirestore extends FakeFirebaseFirestore {
  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    await super.runTransaction<T>(
      transactionHandler,
      timeout: timeout,
      maxAttempts: maxAttempts,
    );
    throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
  }
}

class _RejectedTransactionFirestore extends FakeFirebaseFirestore {
  bool rejectWrites = true;

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) {
    if (rejectWrites) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
    }
    return super.runTransaction<T>(
      transactionHandler,
      timeout: timeout,
      maxAttempts: maxAttempts,
    );
  }
}

class _MemoryAuth extends Fake implements FirebaseAuth {
  final Map<String, _MemoryUser> _users = {};
  int _nextUid = 1;
  bool failNextCreate = false;
  _MemoryUser? _currentUser;

  bool contains(String email) => _users.containsKey(email);

  @override
  User? get currentUser => _currentUser;

  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (failNextCreate) {
      failNextCreate = false;
      throw FirebaseAuthException(code: 'network-request-failed');
    }
    if (_users.containsKey(email)) {
      throw FirebaseAuthException(code: 'email-already-in-use');
    }
    final user = _MemoryUser('uid-${_nextUid++}', email, () {
      _users.remove(email);
      _currentUser = null;
    });
    _users[email] = user;
    _currentUser = user;
    return _MemoryCredential(user);
  }

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final user = _users[email];
    if (user == null) throw FirebaseAuthException(code: 'user-not-found');
    _currentUser = user;
    return _MemoryCredential(user);
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
  }
}

class _MemoryCredential extends Fake implements UserCredential {
  _MemoryCredential(this._user);
  final User _user;

  @override
  User? get user => _user;
}

class _MemoryUser extends Fake implements User {
  _MemoryUser(this.uid, this.email, this._onDelete);

  @override
  final String uid;
  @override
  final String email;
  final void Function() _onDelete;

  @override
  bool get emailVerified => false;

  @override
  Future<void> delete() async => _onDelete();
}
