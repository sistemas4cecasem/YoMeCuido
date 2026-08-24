import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  const UserProfile({
    required this.email,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfile.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    if (data == null) {
      throw const FormatException('User profile document is empty.');
    }

    return UserProfile(
      email: _readString(data, 'email'),
      createdAt: _readTimestamp(data, 'createdAt'),
      updatedAt: _readTimestamp(data, 'updatedAt'),
    );
  }

  final String email;
  final DateTime createdAt;
  final DateTime updatedAt;

  static String _readString(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }

    throw FormatException('Invalid user profile "$key".');
  }

  static DateTime _readTimestamp(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is Timestamp) {
      return value.toDate();
    }

    throw FormatException('Invalid user profile "$key".');
  }
}
