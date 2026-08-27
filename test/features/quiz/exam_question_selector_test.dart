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
    test('selects a balanced set in the ideal case', () async {
      final repository = _FakeExamContentRepository(_buildIdealBank());
      final selector = ExamQuestionSelector(random: math.Random(1));

      final selected = await selector.selectQuestions(
        contentRepository: repository,
        exam: FinalExamConfigs.relationsViolence,
      );

      _expectValidSelection(selected);
      expect(
        _countsBy(selected, (question) => question.activityId).values,
        everyElement(greaterThanOrEqualTo(2)),
      );
      expect(_countsBy(selected, (question) => question.difficulty), {
        'básica': 6,
        'intermedia': 9,
      });
      expect(
        _countsBy(selected, (question) => question.capacity).keys,
        containsAll(<String>['reconocer', 'responder', 'prevenir']),
      );
      expect(
        _countsBy(selected, (question) => question.type).keys,
        containsAll(QuestionType.values),
      );
      expect(repository.requestedActivityId, isNull);
    });

    test('different seeds can produce another valid balanced set', () async {
      final bank = _buildIdealBank(extraPerActivity: 2);
      final firstSelector = ExamQuestionSelector(random: math.Random(1));
      final secondSelector = ExamQuestionSelector(random: math.Random(2));

      final first = firstSelector.selectFromBank(
        questions: bank,
        exam: FinalExamConfigs.relationsViolence,
      );
      final second = secondSelector.selectFromBank(
        questions: bank,
        exam: FinalExamConfigs.relationsViolence,
      );

      _expectValidSelection(first);
      _expectValidSelection(second);
      expect(
        first.map((question) => question.id).toList(),
        isNot(second.map((question) => question.id).toList()),
      );
    });

    test('redistributes when one activity has fewer than two questions', () {
      final bank = <QuizQuestion>[
        _question(number: 1, activityNumber: 1, difficulty: 'intermedia'),
        for (var activity = 2; activity <= 6; activity += 1)
          ..._activityQuestions(activity, count: 4),
      ];
      final selector = ExamQuestionSelector(random: math.Random(3));

      final selected = selector.selectFromBank(
        questions: bank,
        exam: FinalExamConfigs.relationsViolence,
      );

      _expectValidSelection(selected);
      final counts = _countsBy(selected, (question) => question.activityId);
      expect(counts[_activityId(1)], 1);
      for (var activity = 2; activity <= 6; activity += 1) {
        expect(counts[_activityId(activity)], greaterThanOrEqualTo(2));
      }
    });

    test(
      'completes without failing when intermediate questions are scarce',
      () {
        final bank = <QuizQuestion>[
          for (var activity = 1; activity <= 6; activity += 1)
            ..._activityQuestions(
              activity,
              count: 3,
              intermediateCount: activity <= 2 ? 1 : 0,
            ),
        ];
        final selector = ExamQuestionSelector(random: math.Random(4));

        final selected = selector.selectFromBank(
          questions: bank,
          exam: FinalExamConfigs.relationsViolence,
        );

        _expectValidSelection(selected);
        expect(_countsBy(selected, (question) => question.difficulty), {
          'básica': 13,
          'intermedia': 2,
        });
      },
    );

    test('does not block selection when one capacity is absent', () {
      final bank = _buildIdealBank()
          .where((question) {
            return question.capacity != 'prevenir';
          })
          .toList(growable: false);
      final selector = ExamQuestionSelector(random: math.Random(5));

      final selected = selector.selectFromBank(
        questions: bank,
        exam: FinalExamConfigs.relationsViolence,
      );

      _expectValidSelection(selected);
      expect(
        _countsBy(selected, (question) => question.capacity).keys,
        containsAll(<String>['reconocer', 'responder']),
      );
      expect(
        _countsBy(selected, (question) => question.capacity).keys,
        isNot(contains('prevenir')),
      );
    });

    test('returns the exact bank of 15 without duplicates', () {
      final bank = <QuizQuestion>[
        for (var activity = 1; activity <= 6; activity += 1)
          ..._activityQuestions(activity, count: activity <= 3 ? 3 : 2),
      ];
      final selector = ExamQuestionSelector(random: math.Random(6));

      final selected = selector.selectFromBank(
        questions: bank,
        exam: FinalExamConfigs.relationsViolence,
      );

      _expectValidSelection(selected);
      expect(
        selected.map((question) => question.id).toSet(),
        bank.map((question) => question.id).toSet(),
      );
    });

    test(
      'does not duplicate questions when the bank is globally insufficient',
      () async {
        final repository = _FakeExamContentRepository(_buildFlatQuestions(12));
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

void _expectValidSelection(List<QuizQuestion> selected) {
  expect(selected, hasLength(FinalExamConfigs.relationsViolence.questionCount));
  expect(
    selected.map((question) => question.id).toSet(),
    hasLength(FinalExamConfigs.relationsViolence.questionCount),
  );
  expect(
    selected.every(
      (question) =>
          question.categoryId == FinalExamConfigs.relationsViolence.categoryId,
    ),
    isTrue,
  );
}

Map<T, int> _countsBy<T>(
  List<QuizQuestion> questions,
  T Function(QuizQuestion question) keyOf,
) {
  final counts = <T, int>{};
  for (final question in questions) {
    counts.update(keyOf(question), (count) => count + 1, ifAbsent: () => 1);
  }
  return counts;
}

List<QuizQuestion> _buildIdealBank({int extraPerActivity = 0}) {
  return <QuizQuestion>[
    for (var activity = 1; activity <= 6; activity += 1)
      ..._activityQuestions(activity, count: 4 + extraPerActivity),
  ];
}

List<QuizQuestion> _activityQuestions(
  int activity, {
  required int count,
  int? intermediateCount,
}) {
  final desiredIntermediateCount = intermediateCount ?? (count / 2).ceil();
  return <QuizQuestion>[
    for (var index = 1; index <= count; index += 1)
      _question(
        number: (activity * 100) + index,
        activityNumber: activity,
        difficulty: index <= desiredIntermediateCount ? 'intermedia' : 'básica',
        capacity: switch (index % 3) {
          0 => 'prevenir',
          1 => 'reconocer',
          _ => 'responder',
        },
        type: switch (index % 3) {
          0 => QuestionType.fillBlank,
          1 => QuestionType.multipleChoice,
          _ => QuestionType.trueFalse,
        },
      ),
  ];
}

List<QuizQuestion> _buildFlatQuestions(int count) {
  return List<QuizQuestion>.generate(count, (index) {
    return _question(
      number: index + 1,
      activityNumber: 1,
      difficulty: 'básica',
    );
  });
}

QuizQuestion _question({
  required int number,
  required int activityNumber,
  required String difficulty,
  String capacity = 'responder',
  QuestionType type = QuestionType.multipleChoice,
}) {
  return QuizQuestion(
    id: 'question_$number',
    categoryId: FinalExamConfigs.relationsViolence.categoryId,
    activityId: _activityId(activityNumber),
    type: type,
    statement: 'Pregunta $number',
    options: type == QuestionType.fillBlank
        ? const <QuizOption>[]
        : <QuizOption>[
            QuizOption(id: 'correct_$number', text: 'Correcta'),
            QuizOption(id: 'incorrect_$number', text: 'Incorrecta'),
          ],
    correctAnswer: type == QuestionType.fillBlank
        ? 'respuesta'
        : 'correct_$number',
    acceptedAnswers: type == QuestionType.fillBlank
        ? const <String>['respuesta']
        : <String>['correct_$number'],
    feedback: 'Retroalimentacion.',
    capacity: capacity,
    difficulty: difficulty,
  );
}

String _activityId(int number) {
  return 'relations_violence_activity_${number.toString().padLeft(2, '0')}';
}
