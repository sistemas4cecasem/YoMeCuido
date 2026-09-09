import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_yomecuido/data/models/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserProfile', () {
    test('reads complete profiles', () {
      final profile = UserProfile.fromMap({
        'username': 'DiegoNais',
        'usernameNormalized': 'diegonais',
        'email': 'persona@example.com',
        'role': UserProfileRole.user,
        'totalPoints': 850,
        'createdAt': Timestamp.fromDate(DateTime(2026)),
        'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 2)),
      });

      expect(profile.username, 'DiegoNais');
      expect(profile.usernameNormalized, 'diegonais');
      expect(profile.email, 'persona@example.com');
      expect(profile.role, UserProfileRole.user);
      expect(profile.totalPoints, 850);
      expect(profile.hasUsername, isTrue);
    });

    test('reads legacy profiles without username', () {
      final profile = UserProfile.fromMap({
        'email': 'persona@example.com',
        'createdAt': Timestamp.fromDate(DateTime(2026)),
        'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 2)),
      });

      expect(profile.username, isNull);
      expect(profile.usernameNormalized, isNull);
      expect(profile.role, UserProfileRole.user);
      expect(profile.totalPoints, 0);
      expect(profile.hasUsername, isFalse);
    });

    test('serializes complete profiles', () {
      final profile = UserProfile(
        username: 'DiegoNais',
        usernameNormalized: 'diegonais',
        email: 'persona@example.com',
        role: UserProfileRole.user,
        totalPoints: 850,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026, 1, 2),
      );

      final data = profile.toFirestore();

      expect(data['username'], 'DiegoNais');
      expect(data['usernameNormalized'], 'diegonais');
      expect(data['email'], 'persona@example.com');
      expect(data['role'], UserProfileRole.user);
      expect(data['totalPoints'], 850);
      expect(data['createdAt'], isA<Timestamp>());
      expect(data['updatedAt'], isA<Timestamp>());
    });

    test('round-trips total points without losing profile fields', () {
      final profile = UserProfile(
        username: 'DiegoNais',
        usernameNormalized: 'diegonais',
        email: 'persona@example.com',
        role: UserProfileRole.user,
        totalPoints: 850,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026, 1, 2),
      );

      final rebuilt = UserProfile.fromMap(profile.toFirestore());

      expect(rebuilt.username, profile.username);
      expect(rebuilt.usernameNormalized, profile.usernameNormalized);
      expect(rebuilt.email, profile.email);
      expect(rebuilt.role, profile.role);
      expect(rebuilt.totalPoints, profile.totalPoints);
    });

    test('rejects negative total points', () {
      expect(
        () => UserProfile.fromMap({
          'username': 'DiegoNais',
          'usernameNormalized': 'diegonais',
          'email': 'persona@example.com',
          'role': UserProfileRole.user,
          'totalPoints': -100,
          'createdAt': Timestamp.fromDate(DateTime(2026)),
          'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 2)),
        }),
        throwsFormatException,
      );
    });
  });
}
