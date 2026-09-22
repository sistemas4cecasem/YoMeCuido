import 'package:demo_yomecuido/data/repositories/offline_activity_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'asset carga exactamente 20 preguntas de opción múltiple válidas',
    () async {
      final repository = AssetOfflineActivityRepository(
        assetBundle: rootBundle,
      );

      final questions = await repository.loadQuestions();

      expect(questions, hasLength(20));
      expect(questions.map((question) => question.id).toSet(), hasLength(20));
      for (final question in questions) {
        expect(question.id, startsWith('offline_activity_q'));
        expect(question.statement.trim(), isNotEmpty);
        expect(question.options, hasLength(4));
        expect(
          question.options.map((option) => option.id).toSet(),
          hasLength(question.options.length),
        );
        expect(
          question.options.map((option) => option.id),
          contains(question.correctAnswer),
        );
        for (final option in question.options) {
          expect(option.text.trim(), isNotEmpty);
        }
      }
    },
  );

  test('rechaza bancos sin exactamente 20 preguntas', () async {
    final bundle = _StringAssetBundle('[]');
    final repository = AssetOfflineActivityRepository(assetBundle: bundle);

    expect(
      repository.loadQuestions(),
      throwsA(isA<OfflineActivityLoadException>()),
    );
  });

  test('rechaza respuestas correctas fuera de las opciones', () async {
    final bundle = _StringAssetBundle('''
[
  {
    "id": "offline_activity_q01",
    "statement": "Pregunta",
    "options": [
      {"id": "a", "text": "Uno"},
      {"id": "b", "text": "Dos"},
      {"id": "c", "text": "Tres"},
      {"id": "d", "text": "Cuatro"}
    ],
    "correctAnswer": "z"
  }
]
''');
    final repository = AssetOfflineActivityRepository(assetBundle: bundle);

    expect(
      repository.loadQuestions(),
      throwsA(isA<OfflineActivityLoadException>()),
    );
  });
}

class _StringAssetBundle extends CachingAssetBundle {
  _StringAssetBundle(this.value);

  final String value;

  @override
  Future<ByteData> load(String key) async {
    final bytes = Uint8List.fromList(value.codeUnits);
    return ByteData.sublistView(bytes);
  }
}
