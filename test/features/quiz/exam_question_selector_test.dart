import 'dart:math' as math;

import 'package:demo_yomecuido/data/models/category.dart';
import 'package:demo_yomecuido/data/models/final_exam.dart';
import 'package:demo_yomecuido/data/models/learning_activity.dart';
import 'package:demo_yomecuido/data/models/lesson_page.dart';
import 'package:demo_yomecuido/data/models/quiz_question.dart';
import 'package:demo_yomecuido/data/repositories/content_repository.dart';
import 'package:demo_yomecuido/features/quiz/exam_question_selector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExamQuestionSelector', () {
    test('selects 15 unique questions for the configured category', () async {
      final repository = _FakeExamContentRepository(_buildQuestions(20));
      final selector = ExamQuestionSelector(random: math.Random(1));

      final selected = await selector.selectQuestions(
        contentRepository: repository,
        exam: FinalExamConfigs.relationsViolence,
      );

      expect(selected, hasLength(15));
      expect(selected.map((question) => question.id).toSet(), hasLength(15));
      expect(
        selected.every(
          (question) =>
              question.categoryId ==
              FinalExamConfigs.relationsViolence.categoryId,
        ),
        isTrue,
      );
      expect(repository.requestedActivityId, isNull);
    });

    test(
      'does not duplicate questions when the bank is insufficient',
      () async {
        final repository = _FakeExamContentRepository(_buildQuestions(12));
        const selector = ExamQuestionSelector();

        expect(
          () => selector.selectQuestions(
            contentRepository: repository,
            exam: FinalExamConfigs.relationsViolence,
          ),
          throwsA(
            isA<InsufficientExamQuestionsException>()
                .having(
                  (exception) => exception.availableQuestions,
                  'availableQuestions',
                  12,
                )
                .having(
                  (exception) => exception.requiredQuestions,
                  'requiredQuestions',
                  15,
                ),
          ),
        );
      },
    );
  });
}

class _FakeExamContentRepository implements ContentRepository {
  _FakeExamContentRepository(this.questions);

  final List<QuizQuestion> questions;
  String? requestedActivityId;

  @override
  Future<List<Category>> loadCategories() {
    throw UnimplementedError();
  }

  @override
  Future<List<LearningActivity>> loadActivities(String categoryId) {
    throw UnimplementedError();
  }

  @override
  Future<List<LessonPage>> loadLessonPages(String categoryId) {
    throw UnimplementedError();
  }

  @override
  Future<List<QuizQuestion>> loadQuizQuestions(
    String categoryId, {
    String? activityId,
  }) async {
    requestedActivityId = activityId;
    return questions;
  }
}

List<QuizQuestion> _buildQuestions(int count) {
  return List<QuizQuestion>.generate(count, (index) {
    final questionNumber = index + 1;
    return QuizQuestion(
      id: 'question_$questionNumber',
      categoryId: FinalExamConfigs.relationsViolence.categoryId,
      activityId: 'relations_violence_activity_01',
      type: QuestionType.multipleChoice,
      statement: 'Pregunta $questionNumber',
      options: <QuizOption>[
        QuizOption(id: 'correct_$questionNumber', text: 'Correcta'),
        QuizOption(id: 'incorrect_$questionNumber', text: 'Incorrecta'),
      ],
      correctAnswer: 'correct_$questionNumber',
      acceptedAnswers: <String>['correct_$questionNumber'],
      feedback: 'Retroalimentacion.',
      capacity: 'responder',
      difficulty: 'basica',
    );
  });
}
