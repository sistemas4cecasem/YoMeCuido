import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/pending_quiz_attempt.dart';

abstract class PendingQuizAttemptRepository {
  Future<List<PendingQuizAttempt>> loadAll();

  Future<void> upsert(PendingQuizAttempt attempt);

  Future<void> remove(String attemptId);

  Future<void> removeForUid(String uid) async {
    final attempts = await loadAll();
    for (final attempt in attempts.where((attempt) => attempt.uid == uid)) {
      await remove(attempt.attemptId);
    }
  }
}

class SharedPreferencesPendingQuizAttemptRepository
    implements PendingQuizAttemptRepository {
  SharedPreferencesPendingQuizAttemptRepository({
    SharedPreferencesAsync? preferences,
  }) : _preferences = preferences;

  static const _storageKey = 'pending_quiz_attempts_v1';

  SharedPreferencesAsync? _preferences;

  @override
  Future<List<PendingQuizAttempt>> loadAll() async {
    final preferences = _safePreferences();
    if (preferences == null) {
      return const <PendingQuizAttempt>[];
    }

    final raw = await preferences.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <PendingQuizAttempt>[];
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const <PendingQuizAttempt>[];
    }

    final attempts = <PendingQuizAttempt>[];
    for (final item in decoded) {
      if (item is! Map) {
        continue;
      }
      try {
        attempts.add(
          PendingQuizAttempt.fromJson(Map<String, Object?>.from(item)),
        );
      } on FormatException {
        continue;
      }
    }
    return List<PendingQuizAttempt>.unmodifiable(attempts);
  }

  @override
  Future<void> upsert(PendingQuizAttempt attempt) async {
    final attempts = await loadAll();
    final next = <PendingQuizAttempt>[
      for (final existing in attempts)
        if (existing.attemptId != attempt.attemptId) existing,
      attempt,
    ];
    await _save(next);
  }

  @override
  Future<void> remove(String attemptId) async {
    final attempts = await loadAll();
    await _save(
      attempts
          .where((attempt) => attempt.attemptId != attemptId)
          .toList(growable: false),
    );
  }

  @override
  Future<void> removeForUid(String uid) async {
    final attempts = await loadAll();
    await _save(attempts.where((attempt) => attempt.uid != uid).toList());
  }

  Future<void> _save(List<PendingQuizAttempt> attempts) {
    final preferences = _safePreferences();
    if (preferences == null) {
      return Future<void>.value();
    }
    return preferences.setString(
      _storageKey,
      jsonEncode([for (final attempt in attempts) attempt.toJson()]),
    );
  }

  SharedPreferencesAsync? _safePreferences() {
    final existing = _preferences;
    if (existing != null) {
      return existing;
    }
    try {
      return _preferences = SharedPreferencesAsync();
    } on StateError {
      return null;
    }
  }
}
