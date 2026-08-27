import 'package:demo_yomecuido/data/models/final_exam.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FinalExamConfigs', () {
    test('defines the final exam for relations and digital violence', () {
      const exam = FinalExamConfigs.relationsViolence;

      expect(exam.id, 'relations_violence_final_exam');
      expect(exam.categoryId, 'relations_violence_digital');
      expect(exam.title, 'Examen final');
      expect(exam.questionCount, 15);
      expect(exam.minimumQuestionsPerActivity, 2);
      expect(exam.targetDifficultyCounts, <String, int>{
        'básica': 6,
        'intermedia': 9,
      });
      expect(exam.order, 7);
    });

    test('resolves exam configuration by category id', () {
      expect(
        FinalExamConfigs.forCategory('relations_violence_digital'),
        FinalExamConfigs.relationsViolence,
      );
      expect(FinalExamConfigs.forCategory('unknown_category'), isNull);
    });
  });
}
