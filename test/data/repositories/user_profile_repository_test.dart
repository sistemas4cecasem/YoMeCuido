import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_yomecuido/data/repositories/user_profile_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('changeUsername keeps users and leaderboard synchronized', () async {
    final firestore = FakeFirebaseFirestore();
    final repository = UserProfileRepository(firestore: firestore);
    await firestore.collection('users').doc('uid-a').set({
      'username': 'diegonais',
      'usernameNormalized': 'diegonais',
      'email': 'persona@example.com',
      'role': 'user',
      'totalPoints': 540,
      'createdAt': Timestamp.fromDate(DateTime.utc(2026, 9, 1)),
      'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 9, 1)),
    });
    await firestore.collection('usernames').doc('diegonais').set({
      'uid': 'uid-a',
    });
    await firestore.collection('leaderboard').doc('uid-a').set({
      'username': 'diegonais',
      'totalPoints': 540,
      'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 9, 1)),
    });

    final profile = await repository.changeUsername(
      uid: 'uid-a',
      email: 'persona@example.com',
      username: 'diegof',
    );

    final userData = (await firestore.collection('users').doc('uid-a').get())
        .data()!;
    final leaderboardData =
        (await firestore.collection('leaderboard').doc('uid-a').get()).data()!;
    expect(profile.username, 'diegof');
    expect(userData['username'], 'diegof');
    expect(leaderboardData['username'], 'diegof');
    expect(leaderboardData['totalPoints'], 540);
    expect(leaderboardData.containsKey('email'), isFalse);
    expect(leaderboardData.containsKey('role'), isFalse);
  });

  test('changeUsername removes legacy private leaderboard fields', () async {
    final firestore = FakeFirebaseFirestore();
    final repository = UserProfileRepository(firestore: firestore);
    await firestore.collection('users').doc('uid-a').set({
      'username': 'diegonais',
      'usernameNormalized': 'diegonais',
      'email': 'persona@example.com',
      'role': 'user',
      'totalPoints': 540,
      'createdAt': Timestamp.fromDate(DateTime.utc(2026, 9, 1)),
      'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 9, 1)),
    });
    await firestore.collection('usernames').doc('diegonais').set({
      'uid': 'uid-a',
    });
    await firestore.collection('leaderboard').doc('uid-a').set({
      'username': 'diegonais',
      'totalPoints': 540,
      'email': 'persona@example.com',
      'role': 'user',
      'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 9, 1)),
    });

    await repository.changeUsername(
      uid: 'uid-a',
      email: 'persona@example.com',
      username: 'diegof',
    );

    final leaderboardData =
        (await firestore.collection('leaderboard').doc('uid-a').get()).data()!;
    expect(leaderboardData['username'], 'diegof');
    expect(leaderboardData['totalPoints'], 540);
    expect(leaderboardData.containsKey('email'), isFalse);
    expect(leaderboardData.containsKey('role'), isFalse);
  });
}
