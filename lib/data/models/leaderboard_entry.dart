import 'package:cloud_firestore/cloud_firestore.dart';

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.userId,
    required this.username,
    required this.totalPoints,
  }) : assert(totalPoints >= 0, 'totalPoints cannot be negative.');

  factory LeaderboardEntry.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    if (data == null) {
      throw const FormatException('Leaderboard document is empty.');
    }

    return LeaderboardEntry.fromMap(snapshot.id, data);
  }

  factory LeaderboardEntry.fromMap(String userId, Map<String, dynamic> data) {
    return LeaderboardEntry(
      userId: _readId(userId),
      username: _readString(data, 'username'),
      totalPoints: _readNonNegativeInt(data, 'totalPoints'),
    );
  }

  final String userId;
  final String username;
  final int totalPoints;

  bool get participates => totalPoints > 0;

  static String _readId(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Invalid leaderboard user id.');
    }
    return trimmed;
  }

  static String _readString(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
    throw FormatException('Invalid leaderboard "$key".');
  }

  static int _readNonNegativeInt(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is int && value >= 0) {
      return value;
    }
    throw FormatException('Invalid leaderboard "$key".');
  }
}

class LeaderboardUserPosition {
  const LeaderboardUserPosition({required this.entry, required this.position})
    : assert(position > 0, 'position must be positive.');

  final LeaderboardEntry entry;
  final int position;
}
