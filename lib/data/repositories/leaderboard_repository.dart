import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/leaderboard_entry.dart';

abstract class LeaderboardRepository {
  static const leaderboardCollection = 'leaderboard';
  static const defaultLimit = 50;

  Stream<List<LeaderboardEntry>> watchTopEntries({int limit = defaultLimit});

  Future<LeaderboardUserPosition?> fetchUserPosition({
    required String uid,
    required String username,
    required int totalPoints,
  });

  Future<void> ensureEntryForCurrentUser({
    required String uid,
    required String username,
    required int totalPoints,
  });
}

class FirestoreLeaderboardRepository implements LeaderboardRepository {
  FirestoreLeaderboardRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _leaderboard =>
      _firestore.collection(LeaderboardRepository.leaderboardCollection);

  @override
  Stream<List<LeaderboardEntry>> watchTopEntries({
    int limit = LeaderboardRepository.defaultLimit,
  }) {
    final resolvedLimit = limit <= 0
        ? LeaderboardRepository.defaultLimit
        : limit;
    return _leaderboard
        .where('totalPoints', isGreaterThan: 0)
        .orderBy('totalPoints', descending: true)
        .limit(resolvedLimit)
        .snapshots()
        .map((snapshot) {
          final entries = snapshot.docs
              .map(LeaderboardEntry.fromFirestore)
              .toList(growable: false);
          return _sortTiesByUsername(entries);
        });
  }

  @override
  Future<LeaderboardUserPosition?> fetchUserPosition({
    required String uid,
    required String username,
    required int totalPoints,
  }) async {
    final normalizedUid = uid.trim();
    final normalizedUsername = username.trim();
    if (normalizedUid.isEmpty ||
        normalizedUsername.isEmpty ||
        totalPoints <= 0) {
      return null;
    }

    final higherPointsCount = await _leaderboard
        .where('totalPoints', isGreaterThan: totalPoints)
        .count()
        .get();
    return LeaderboardUserPosition(
      entry: LeaderboardEntry(
        userId: normalizedUid,
        username: normalizedUsername,
        totalPoints: totalPoints,
      ),
      position: (higherPointsCount.count ?? 0) + 1,
    );
  }

  @override
  Future<void> ensureEntryForCurrentUser({
    required String uid,
    required String username,
    required int totalPoints,
  }) async {
    final normalizedUid = uid.trim();
    final normalizedUsername = username.trim();
    if (normalizedUid.isEmpty ||
        normalizedUsername.isEmpty ||
        totalPoints < 0) {
      return;
    }

    await _leaderboard.doc(normalizedUid).set({
      'username': normalizedUsername,
      'totalPoints': totalPoints,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

List<LeaderboardEntry> _sortTiesByUsername(List<LeaderboardEntry> entries) {
  final sorted = List<LeaderboardEntry>.of(entries);
  sorted.sort((a, b) {
    final byPoints = b.totalPoints.compareTo(a.totalPoints);
    if (byPoints != 0) {
      return byPoints;
    }
    final byUsername = a.username.toLowerCase().compareTo(
      b.username.toLowerCase(),
    );
    if (byUsername != 0) {
      return byUsername;
    }
    return a.userId.compareTo(b.userId);
  });
  return List<LeaderboardEntry>.unmodifiable(sorted);
}
