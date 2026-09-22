import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/offline_activity_question.dart';

abstract class OfflineActivityRepository {
  Future<List<OfflineActivityQuestion>> loadQuestions();
}

class AssetOfflineActivityRepository implements OfflineActivityRepository {
  const AssetOfflineActivityRepository({
    AssetBundle? assetBundle,
    this.assetPath = 'assets/data/offline_activity_questions.json',
  }) : _assetBundle = assetBundle;

  final AssetBundle? _assetBundle;
  final String assetPath;

  @override
  Future<List<OfflineActivityQuestion>> loadQuestions() async {
    try {
      final bundle = _assetBundle ?? rootBundle;
      final rawJson = await bundle.loadString(assetPath);
      final decoded = jsonDecode(rawJson);
      if (decoded is! List<Object?>) {
        throw const FormatException('Offline activity must be a list.');
      }

      final questions = decoded
          .map((item) {
            if (item is Map<String, Object?>) {
              return OfflineActivityQuestion.fromJson(item);
            }
            throw const FormatException('Invalid offline question object.');
          })
          .toList(growable: false);

      _validateQuestionBank(questions);
      return questions;
    } catch (_) {
      throw const OfflineActivityLoadException();
    }
  }

  void _validateQuestionBank(List<OfflineActivityQuestion> questions) {
    if (questions.length != 20) {
      throw const FormatException('Offline activity requires 20 questions.');
    }
    final ids = questions.map((question) => question.id).toSet();
    if (ids.length != questions.length) {
      throw const FormatException('Offline question ids must be unique.');
    }
  }
}

class OfflineActivityLoadException implements Exception {
  const OfflineActivityLoadException();

  @override
  String toString() => 'No pudimos cargar la actividad sin conexión.';
}
