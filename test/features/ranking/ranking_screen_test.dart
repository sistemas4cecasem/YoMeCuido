import 'dart:async';

import 'package:demo_yomecuido/app/app_strings.dart';
import 'package:demo_yomecuido/core/theme/app_theme.dart';
import 'package:demo_yomecuido/data/models/auth_user.dart';
import 'package:demo_yomecuido/data/models/leaderboard_entry.dart';
import 'package:demo_yomecuido/data/models/user_profile.dart';
import 'package:demo_yomecuido/data/repositories/leaderboard_repository.dart';
import 'package:demo_yomecuido/features/ranking/ranking_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows loading and then a real ranking without private data', (
    tester,
  ) async {
    final repository = _FakeLeaderboardRepository();
    await _pumpRanking(tester, repository);

    expect(find.byType(CircularProgressIndicator), findsWidgets);

    repository.emit(const <LeaderboardEntry>[
      LeaderboardEntry(userId: 'uid-a', username: 'Ana', totalPoints: 1000),
      LeaderboardEntry(userId: 'uid-b', username: 'Beto', totalPoints: 800),
      LeaderboardEntry(userId: 'uid-123', username: 'Dego', totalPoints: 800),
      LeaderboardEntry(userId: 'uid-d', username: 'Dani', totalPoints: 700),
    ]);
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.rankingTitle), findsOneWidget);
    expect(find.text(AppStrings.generalRankingTitle), findsOneWidget);
    expect(find.text(AppStrings.comingSoon), findsNothing);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Beto'), findsOneWidget);
    expect(find.text('Dego'), findsWidgets);
    expect(find.text('1.000 puntos'), findsOneWidget);
    expect(find.text('800 puntos'), findsWidgets);
    expect(find.text('#2'), findsNothing);
    expect(find.text(AppStrings.currentUserBadge), findsWidgets);
    expect(find.text('persona@example.com'), findsNothing);
    expect(find.text(UserProfileRole.user), findsNothing);
    expect(find.byIcon(Icons.emoji_events), findsOneWidget);
    expect(find.byIcon(Icons.military_tech), findsWidgets);
    expect(repository.ensureEntryCalls, 0);
  });

  testWidgets('keeps the last visible ranking when the stream fails later', (
    tester,
  ) async {
    final repository = _FakeLeaderboardRepository();
    await _pumpRanking(tester, repository);

    repository.emit(const <LeaderboardEntry>[
      LeaderboardEntry(userId: 'uid-a', username: 'Ana', totalPoints: 1000),
      LeaderboardEntry(userId: 'uid-123', username: 'Dego', totalPoints: 540),
    ]);
    await tester.pumpAndSettle();

    repository.emitError(Exception('late ranking stream failure'));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.rankingLoadError), findsNothing);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Dego'), findsWidgets);
    expect(find.text('540 puntos'), findsWidgets);
  });

  testWidgets('shows an empty state when there are no participants', (
    tester,
  ) async {
    final repository = _FakeLeaderboardRepository();
    await _pumpRanking(tester, repository);

    repository.emit(const <LeaderboardEntry>[]);
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.emptyRankingTitle), findsOneWidget);
    expect(find.text(AppStrings.emptyRankingBody), findsOneWidget);
  });

  testWidgets('shows a separate position card outside the top', (tester) async {
    final repository = _FakeLeaderboardRepository(
      position: const LeaderboardUserPosition(
        entry: LeaderboardEntry(
          userId: 'uid-123',
          username: 'Dego',
          totalPoints: 540,
        ),
        position: 123,
      ),
    );
    await _pumpRanking(tester, repository);

    repository.emit(const <LeaderboardEntry>[
      LeaderboardEntry(userId: 'uid-a', username: 'Ana', totalPoints: 1000),
      LeaderboardEntry(userId: 'uid-b', username: 'Beto', totalPoints: 900),
    ]);
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.yourRankingPositionTitle), findsOneWidget);
    expect(find.text('#123'), findsOneWidget);
    expect(find.text('Dego'), findsOneWidget);
    expect(find.text('540 puntos'), findsOneWidget);
  });

  testWidgets('shows no position for a current user with zero points', (
    tester,
  ) async {
    final repository = _FakeLeaderboardRepository();
    await _pumpRanking(tester, repository, totalPoints: 0);

    repository.emit(const <LeaderboardEntry>[
      LeaderboardEntry(userId: 'uid-a', username: 'Ana', totalPoints: 1000),
    ]);
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.noRankingPositionTitle), findsOneWidget);
    expect(find.text(AppStrings.noRankingPositionBody), findsOneWidget);
  });
}

Future<void> _pumpRanking(
  WidgetTester tester,
  _FakeLeaderboardRepository repository, {
  int totalPoints = 540,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.data(),
      home: RankingScreen(
        user: const AuthUser(
          uid: 'uid-123',
          email: 'persona@example.com',
          isEmailVerified: true,
        ),
        profile: const UserProfile(
          username: 'Dego',
          usernameNormalized: 'dego',
          email: 'persona@example.com',
          role: UserProfileRole.user,
          totalPoints: 540,
          createdAt: null,
          updatedAt: null,
        ),
        totalPoints: totalPoints,
        leaderboardRepository: repository,
      ),
    ),
  );
}

class _FakeLeaderboardRepository implements LeaderboardRepository {
  _FakeLeaderboardRepository({this.position});

  final LeaderboardUserPosition? position;
  final _controller = StreamController<List<LeaderboardEntry>>();
  int ensureEntryCalls = 0;

  void emit(List<LeaderboardEntry> entries) {
    _controller.add(entries);
  }

  void emitError(Object error) {
    _controller.addError(error);
  }

  @override
  Stream<List<LeaderboardEntry>> watchTopEntries({
    int limit = LeaderboardRepository.defaultLimit,
  }) {
    return _controller.stream;
  }

  @override
  Future<LeaderboardUserPosition?> fetchUserPosition({
    required String uid,
    required String username,
    required int totalPoints,
  }) async {
    if (totalPoints <= 0) {
      return null;
    }
    return position;
  }

  @override
  Future<void> ensureEntryForCurrentUser({
    required String uid,
    required String username,
    required int totalPoints,
  }) async {
    ensureEntryCalls += 1;
  }
}
