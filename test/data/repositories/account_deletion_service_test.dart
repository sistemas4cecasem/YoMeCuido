import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:demo_yomecuido/data/models/pending_quiz_attempt.dart';
import 'package:demo_yomecuido/data/models/user_profile.dart';
import 'package:demo_yomecuido/data/repositories/account_deletion_repository.dart';
import 'package:demo_yomecuido/data/repositories/pending_quiz_attempt_repository.dart';
import 'package:demo_yomecuido/shared/services/observability_service.dart';

void main() {
  test('wrong password never enters deleting', () async {
    final fixture = _Fixture();
    fixture.identity.rejectPassword = true;
    await expectLater(
      fixture.service.start('wrong'),
      throwsA(
        isA<AccountDeletionException>().having(
          (e) => e.reason,
          'reason',
          AccountDeletionFailure.password,
        ),
      ),
    );
    expect(fixture.store.state, AccountState.active);
    expect(fixture.store.eventsOnly, isEmpty);
  });

  test('reauthentication precedes durable state and Auth is last', () async {
    final fixture = _Fixture();
    await fixture.service.start('secret');
    expect(fixture.events, [
      'reauth',
      'suspend',
      'mark',
      'delete-data',
      'verify',
      'delete-profile',
      'clear-pending',
      'delete-auth',
    ]);
    expect(fixture.identity.deleted, isTrue);
    expect(fixture.store.state, isNull);
  });

  for (final stage in [
    'delete-data',
    'verify',
    'delete-profile',
    'clear-pending',
    'delete-auth',
  ]) {
    test('restart resumes after interruption at $stage', () async {
      final fixture = _Fixture();
      fixture.store.failOnceAt = stage;
      fixture.pending.failOnce = stage == 'clear-pending';
      fixture.identity.failOnce = stage == 'delete-auth';
      if (stage == 'clear-pending' || stage == 'delete-auth') {
        fixture.store.failOnceAt = null;
      }
      await expectLater(fixture.service.start('secret'), throwsException);
      expect(fixture.store.state, isNot(AccountState.active));
      final restarted = fixture.newService();
      await restarted.resume();
      expect(fixture.identity.deleted, isTrue);
      expect(fixture.store.state, isNull);
      expect(fixture.store.eventsOnly.where((e) => e == 'mark'), hasLength(1));
    });
  }

  test('Auth recent-login failure retries only Auth after reauth', () async {
    final fixture = _Fixture();
    fixture.identity.failWithRecentLogin = true;
    await expectLater(
      fixture.service.start('secret'),
      throwsA(
        isA<AccountDeletionException>().having(
          (e) => e.reason,
          'reason',
          AccountDeletionFailure.recentLogin,
        ),
      ),
    );
    final firestoreEvents = List<String>.of(fixture.store.eventsOnly);
    await fixture.newService().retryAuthOnly('secret');
    expect(fixture.store.eventsOnly, firestoreEvents);
    expect(fixture.identity.reauthCount, 2);
    expect(fixture.identity.deleted, isTrue);
  });

  test('Auth-only restart never recreates a profile', () async {
    final fixture = _Fixture();
    fixture.store.state = null;
    await fixture.newService().retryAuthOnly('secret');
    expect(fixture.store.eventsOnly, isEmpty);
    expect(fixture.identity.deleted, isTrue);
  });

  for (final observerMode in ['throw', 'pending']) {
    for (final stage in ['delete-data', 'clear-pending', 'delete-auth']) {
      test(
        'observer $observerMode never delays deletion/retry at $stage',
        () async {
          final observer = _Observer(mode: observerMode);
          final fixture = _Fixture(observer: observer);
          fixture.store.failOnceAt = stage == 'delete-data' ? stage : null;
          fixture.pending.failOnce = stage == 'clear-pending';
          fixture.identity.failOnce = stage == 'delete-auth';
          await expectLater(
            fixture.service
                .start('private-password')
                .timeout(const Duration(seconds: 2)),
            throwsA(isA<AccountDeletionException>()),
          );
          expect(observer.events, hasLength(1));
          expect(
            observer.events.single.operation,
            ObservabilityOperation.deleteAccount,
          );
          expect(observer.events.single.fatal, isFalse);
          await fixture.service.resume().timeout(const Duration(seconds: 2));
          expect(fixture.identity.deleted, isTrue);
          expect(fixture.store.state, isNull);
          expect(
            fixture.store.eventsOnly.where((e) => e == 'mark'),
            hasLength(1),
          );
          expect(fixture.events.last, 'delete-auth');
          expect(observer.events, hasLength(1));
        },
      );
    }
  }

  test('password and recent-login failures are not reported', () async {
    final observer = _Observer();
    final fixture = _Fixture(observer: observer);
    fixture.identity.rejectPassword = true;
    await expectLater(fixture.service.start('wrong'), throwsException);
    expect(observer.events, isEmpty);
    fixture.identity.rejectPassword = false;
    fixture.identity.failWithRecentLogin = true;
    await expectLater(fixture.service.start('secret'), throwsException);
    expect(observer.events, isEmpty);
    await fixture.service.retryAuthOnly('secret');
    expect(observer.events, isEmpty);
    expect(fixture.identity.deleted, isTrue);
  });

  test(
    'transient Auth network failure retains recovery without reporting',
    () async {
      final observer = _Observer();
      final fixture = _Fixture(observer: observer);
      fixture.identity.authFailure = FirebaseAuthException(
        code: 'network-request-failed',
        message: 'private-token uid-private',
      );
      await expectLater(
        fixture.service.start('secret'),
        throwsA(
          isA<AccountDeletionException>().having(
            (e) => e.reason,
            'reason',
            AccountDeletionFailure.remote,
          ),
        ),
      );
      expect(observer.events, isEmpty);
      expect(fixture.store.state, isNull);
      fixture.identity.authFailure = null;
      await fixture.service.retryAuthOnly('secret');
      expect(fixture.identity.deleted, isTrue);
      expect(fixture.store.eventsOnly.where((e) => e == 'mark'), hasLength(1));
    },
  );

  test(
    'unexpected Firebase Auth message is classified without leaking',
    () async {
      final observer = _Observer();
      final fixture = _Fixture(observer: observer);
      fixture.identity.authFailure = FirebaseAuthException(
        code: 'internal-error',
        message: 'private-token uid-private persona@example.com',
      );
      await expectLater(fixture.service.start('secret'), throwsException);
      await expectLater(fixture.service.resume(), throwsException);
      expect(observer.events, hasLength(1));
      expect(observer.events.single.code, ObservabilityErrorCode.unexpected);
      fixture.identity.authFailure = null;
      await fixture.service.retryAuthOnly('secret');
      expect(fixture.identity.deleted, isTrue);
    },
  );

  test(
    'observer failure preserves original local exception and deletion order',
    () async {
      final observer = _Observer(mode: 'throw');
      final fixture = _Fixture(observer: observer);
      final error = StateError('uid-private answers-private');
      fixture.pending.error = error;
      await expectLater(fixture.service.start('secret'), throwsA(same(error)));
      expect(fixture.identity.deleted, isFalse);
      expect(fixture.store.state, isNull);
      expect(
        observer.events.single.code,
        ObservabilityErrorCode.invariantViolation,
      );
      fixture.pending.error = null;
      await fixture.service.resume();
      expect(fixture.events.last, 'delete-auth');
      expect(fixture.identity.deleted, isTrue);
    },
  );
}

class _Fixture {
  _Fixture({this.observer = const NoOpObservabilityService()}) {
    service = newService();
  }

  final events = <String>[];
  final ObservabilityService observer;
  late final store = _Store(events);
  late final identity = _Identity(events);
  late final pending = _Pending(events);
  late final AccountDeletionService service;

  AccountDeletionService newService() => AccountDeletionService(
    observabilityService: observer,
    identity: identity,
    store: store,
    pending: pending,
    suspendPendingSync: (_) async => events.add('suspend'),
  );
}

class _Store implements AccountDeletionStore {
  _Store(this.events);
  final List<String> events;
  String? state = AccountState.active;
  String? failOnceAt;
  final storeEvents = <String>[];

  List<String> get eventsOnly => storeEvents;

  void _record(String stage) {
    events.add(stage);
    storeEvents.add(stage);
    if (failOnceAt == stage) {
      failOnceAt = null;
      throw const AccountDeletionException(AccountDeletionFailure.remote);
    }
  }

  @override
  Future<DeletionProfile?> fetchProfile(String uid) async => state == null
      ? null
      : DeletionProfile(state: state!, usernameNormalized: 'example');

  @override
  Future<void> markDeleting(String uid) async {
    _record('mark');
    state = AccountState.deleting;
  }

  @override
  Future<void> deletePersonalData(
    String uid,
    String? usernameNormalized,
  ) async {
    _record('delete-data');
  }

  @override
  Future<void> verifyPersonalDataRemoved(
    String uid,
    String? usernameNormalized,
  ) async {
    _record('verify');
  }

  @override
  Future<void> deleteProfile(String uid) async {
    _record('delete-profile');
    state = null;
  }
}

class _Identity implements AccountDeletionIdentity {
  _Identity(this.events);
  final List<String> events;
  bool rejectPassword = false;
  bool failWithRecentLogin = false;
  bool failOnce = false;
  bool deleted = false;
  int reauthCount = 0;
  FirebaseAuthException? authFailure;

  @override
  String? get currentUid => deleted ? null : 'uid-a';

  @override
  Future<void> reauthenticate(String password) async {
    events.add('reauth');
    reauthCount += 1;
    if (rejectPassword) {
      throw const AccountDeletionException(AccountDeletionFailure.password);
    }
  }

  @override
  Future<void> deleteCurrentUser() async {
    events.add('delete-auth');
    if (authFailure != null) throw authFailure!;
    if (failWithRecentLogin) {
      failWithRecentLogin = false;
      throw FirebaseAuthException(code: 'requires-recent-login');
    }
    if (failOnce) {
      failOnce = false;
      throw const AccountDeletionException(AccountDeletionFailure.remote);
    }
    deleted = true;
  }
}

class _Pending implements PendingQuizAttemptRepository {
  _Pending(this.events);
  final List<String> events;
  bool failOnce = false;
  Object? error;

  @override
  Future<void> removeForUid(String uid) async {
    events.add('clear-pending');
    if (error != null) throw error!;
    if (failOnce) {
      failOnce = false;
      throw const AccountDeletionException(AccountDeletionFailure.remote);
    }
  }

  @override
  Future<List<PendingQuizAttempt>> loadAll() async => [];

  @override
  Future<void> remove(String attemptId) async {}

  @override
  Future<void> upsert(PendingQuizAttempt attempt) async {}
}

class _Observer implements ObservabilityService {
  _Observer({this.mode = 'normal'});
  final String mode;
  final events = <ObservabilityEvent>[];
  final pending = Completer<void>();

  @override
  Future<void> record(ObservabilityEvent event) {
    events.add(event);
    if (mode == 'throw') throw StateError('private-observer');
    if (mode == 'pending') return pending.future;
    return Future<void>.value();
  }
}
