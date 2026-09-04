import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  const UserProfile({
    required this.username,
    required this.usernameNormalized,
    required this.email,
    required this.role,
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

    return UserProfile.fromMap(data);
  }

  factory UserProfile.fromMap(Map<String, dynamic> data) {
    return UserProfile(
      username: _readNullableString(data, 'username'),
      usernameNormalized: _readNullableString(data, 'usernameNormalized'),
      email: _readString(data, 'email'),
      role: _readNullableString(data, 'role') ?? UserProfileRole.user,
      createdAt: _readTimestamp(data, 'createdAt'),
      updatedAt: _readTimestamp(data, 'updatedAt'),
    );
  }

  final String? username;
  final String? usernameNormalized;
  final String email;
  final String role;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get hasUsername {
    return username != null &&
        username!.trim().isNotEmpty &&
        usernameNormalized != null &&
        usernameNormalized!.trim().isNotEmpty;
  }

  Map<String, dynamic> toFirestore() {
    return {
      'username': username,
      'usernameNormalized': usernameNormalized,
      'email': email,
      'role': role,
      'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
    };
  }

  static String _readString(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }

    throw FormatException('Invalid user profile "$key".');
  }

  static String? _readNullableString(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value == null) {
      return null;
    }
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }

    throw FormatException('Invalid user profile "$key".');
  }

  static DateTime? _readTimestamp(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value == null) {
      return null;
    }
    if (value is Timestamp) {
      return value.toDate();
    }

    throw FormatException('Invalid user profile "$key".');
  }
}

abstract final class UserProfileRole {
  static const user = 'user';
}
