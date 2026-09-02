import 'package:demo_yomecuido/data/models/learning_activity.dart';
import 'package:demo_yomecuido/data/models/quiz_question.dart';
import 'package:demo_yomecuido/features/quiz/activity_question_selector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ActivityQuestionSelector', () {
    test('selects the fixed bank of ten questions by activity id', () {
      final questions = _buildQuestions(60);
      const selector = ActivityQuestionSelector();

      final firstActivityQuestions = selector.selectFromBank(
        questions: questions,
        categoryId: _categoryId,
        activity: _activity(1),
      );
      final secondActivityQuestions = selector.selectFromBank(
        questions: questions,
        categoryId: _categoryId,
        activity: _activity(2),
      );

      expect(firstActivityQuestions.map((question) => question.id), <String>[
        for (var index = 1; index <= 10; index += 1)
          'relations_violence_q${index.toString().padLeft(2, '0')}',
      ]);
      expect(secondActivityQuestions.map((question) => question.id), <String>[
        for (var index = 11; index <= 20; index += 1)
          'relations_violence_q${index.toString().padLeft(2, '0')}',
      ]);
      expect(
        firstActivityQuestions
            .map((question) => question.id)
            .toSet()
            .intersection(
              secondActivityQuestions.map((question) => question.id).toSet(),
            ),
        isEmpty,
      );
    });

    test('counts ten questions for each activity in a sixty-question bank', () {
      final questions = _buildQuestions(60);
      const selector = ActivityQuestionSelector();

      final counts = selector.countQuestionsByActivity(
        questions: questions,
        categoryId: _categoryId,
        activities: <LearningActivity>[
          for (var order = 1; order <= 6; order += 1) _activity(order),
        ],
      );

      expect(counts.values, everyElement(10));
    });
  });
}

const _categoryId = 'relations_violence_digital';

LearningActivity _activity(int order) {
  return LearningActivity(
    id: 'relations_violence_activity_${order.toString().padLeft(2, '0')}',
    categoryId: _categoryId,
    title: 'Actividad $order',
    order: order,
  );
}

List<QuizQuestion> _buildQuestions(int count) {
  return <QuizQuestion>[
    for (var index = count; index >= 1; index -= 1)
      QuizQuestion(
        id: 'relations_violence_q${index.toString().padLeft(2, '0')}',
        categoryId: _categoryId,
        activityId:
            'relations_violence_activity_${(((index - 1) ~/ 10) + 1).toString().padLeft(2, '0')}',
        type: QuestionType.multipleChoice,
        statement: 'Pregunta $index',
        options: <QuizOption>[
          QuizOption(id: 'correct_$index', text: 'Correcta'),
          QuizOption(id: 'incorrect_$index', text: 'Incorrecta'),
        ],
        correctAnswer: 'correct_$index',
        acceptedAnswers: <String>['correct_$index'],
        feedback: 'Retroalimentacion.',
        capacity: 'responder',
        difficulty: 'básica',
      ),
  ];
}
