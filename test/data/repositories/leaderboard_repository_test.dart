import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_yomecuido/data/models/leaderboard_entry.dart';
import 'package:demo_yomecuido/data/repositories/leaderboard_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('LeaderboardEntry parses only public ranking fields', () {
    final entry = LeaderboardEntry.fromMap('uid-a', const {
      'username': 'PersonaA',
      'totalPoints': 120,
    });

    expect(entry.userId, 'uid-a');
    expect(entry.username, 'PersonaA');
    expect(entry.totalPoints, 120);
    expect(entry.participates, isTrue);
  });

  test(
    'watchTopEntries returns positive scores ordered descending with limit',
    () async {
      final firestore = FakeFirebaseFirestore();
      final repository = FirestoreLeaderboardRepository(firestore: firestore);
      await _seedLeaderboard(firestore);

      final entries = await repository.watchTopEntries(limit: 3).first;

      expect(entries.map((entry) => entry.username), <String>[
        'Ana',
        'Beto',
        'Cami',
      ]);
      expect(entries.map((entry) => entry.totalPoints), <int>[1000, 800, 800]);
      expect(entries.any((entry) => entry.totalPoints == 0), isFalse);
    },
  );

  test('watchTopEntries skips malformed legacy entries', () async {
    final firestore = FakeFirebaseFirestore();
    final repository = FirestoreLeaderboardRepository(firestore: firestore);
    await _seedLeaderboard(firestore);
    await firestore.collection('leaderboard').doc('uid-legacy').set({
      'username': '',
      'totalPoints': 600,
      'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 9, 15)),
    });

    final entries = await repository.watchTopEntries().first;

    expect(entries.map((entry) => entry.userId), isNot(contains('uid-legacy')));
    expect(
      entries.map((entry) => entry.username),
      containsAll(<String>['Ana', 'Beto', 'Cami', 'Dani']),
    );
  });

  test('fetchUserPosition uses competitive ranking for ties', () async {
    final firestore = FakeFirebaseFirestore();
    final repository = FirestoreLeaderboardRepository(firestore: firestore);
    await _seedLeaderboard(firestore);

    final position = await repository.fetchUserPosition(
      uid: 'uid-c',
      username: 'Cami',
      totalPoints: 800,
    );

    expect(position?.position, 2);
  });

  test(
    'fetchUserPosition resolves a user outside the top without loading all',
    () async {
      final firestore = FakeFirebaseFirestore();
      final repository = FirestoreLeaderboardRepository(firestore: firestore);
      await _seedLeaderboard(firestore);

      final position = await repository.fetchUserPosition(
        uid: 'uid-z',
        username: 'Zoe',
        totalPoints: 200,
      );

      expect(position?.position, 5);
      expect(position?.entry.username, 'Zoe');
    },
  );

  test('fetchUserPosition omits users with zero points', () async {
    final firestore = FakeFirebaseFirestore();
    final repository = FirestoreLeaderboardRepository(firestore: firestore);
    await _seedLeaderboard(firestore);

    final position = await repository.fetchUserPosition(
      uid: 'uid-empty',
      username: 'Cero',
      totalPoints: 0,
    );

    expect(position, isNull);
  });

  test('ensureEntryForCurrentUser creates a minimal own entry', () async {
    final firestore = FakeFirebaseFirestore();
    final repository = FirestoreLeaderboardRepository(firestore: firestore);

    await repository.ensureEntryForCurrentUser(
      uid: 'uid-a',
      username: 'Ana',
      totalPoints: 540,
    );

    final data = (await firestore.collection('leaderboard').doc('uid-a').get())
        .data()!;
    expect(data['username'], 'Ana');
    expect(data['totalPoints'], 540);
    expect(data.containsKey('email'), isFalse);
    expect(data.containsKey('role'), isFalse);
  });

  test('ensureEntryForCurrentUser removes legacy private fields', () async {
    final firestore = FakeFirebaseFirestore();
    final repository = FirestoreLeaderboardRepository(firestore: firestore);
    await firestore.collection('leaderboard').doc('uid-a').set({
      'username': 'Ana vieja',
      'totalPoints': 120,
      'email': 'ana@example.com',
      'role': 'user',
      'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 9, 1)),
    });

    await repository.ensureEntryForCurrentUser(
      uid: 'uid-a',
      username: 'Ana',
      totalPoints: 540,
    );

    final data = (await firestore.collection('leaderboard').doc('uid-a').get())
        .data()!;
    expect(data['username'], 'Ana');
    expect(data['totalPoints'], 540);
    expect(data.containsKey('email'), isFalse);
    expect(data.containsKey('role'), isFalse);
  });
}

Future<void> _seedLeaderboard(FakeFirebaseFirestore firestore) async {
  final entries = <String, Map<String, Object?>>{
    'uid-a': {'username': 'Ana', 'totalPoints': 1000},
    'uid-b': {'username': 'Beto', 'totalPoints': 800},
    'uid-c': {'username': 'Cami', 'totalPoints': 800},
    'uid-d': {'username': 'Dani', 'totalPoints': 700},
    'uid-e': {'username': 'Eli', 'totalPoints': 0},
  };
  for (final entry in entries.entries) {
    await firestore.collection('leaderboard').doc(entry.key).set({
      ...entry.value,
      'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 9, 15)),
    });
  }
}
