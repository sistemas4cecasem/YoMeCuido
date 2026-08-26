import 'package:demo_yomecuido/data/models/category.dart';
import 'package:demo_yomecuido/data/models/learning_activity.dart';
import 'package:demo_yomecuido/data/models/quiz_question.dart';
import 'package:demo_yomecuido/data/repositories/content_repository.dart';
import 'package:demo_yomecuido/data/repositories/local_content_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalContentRepository repository;

  setUp(() {
    repository = LocalContentRepository();
  });

  group('LocalContentRepository', () {
    test('loads exactly eight categories', () async {
      final categories = await repository.loadCategories();

      expect(categories, hasLength(8));
      expect(categories.first.title, 'Relaciones y violencia digital');
    });

    test('loads only one enabled category', () async {
      final categories = await repository.loadCategories();
      final enabledCategories = categories.where((category) {
        return category.isEnabled;
      }).toList();

      expect(enabledCategories, hasLength(1));
      expect(enabledCategories.single.id, 'relations_violence_digital');
      expect(enabledCategories.single.status, CategoryStatus.available);
      expect(
        categories.where((category) => category.isComingSoon),
        hasLength(7),
      );
    });

    test('loads exactly four lesson pages', () async {
      final pages = await repository.loadLessonPages(
        LocalContentRepository.relationsViolenceCategoryId,
      );

      expect(pages, hasLength(4));
      expect(pages.map((page) => page.order), [1, 2, 3, 4]);
    });

    test('loads the current normalized learning activity', () async {
      final activities = await repository.loadActivities(
        LocalContentRepository.relationsViolenceCategoryId,
      );

      expect(activities, hasLength(1));
      expect(activities.single.id, 'relations_violence_activity_01');
      expect(
        activities.single.categoryId,
        LocalContentRepository.relationsViolenceCategoryId,
      );
      expect(activities.single.title, 'Actividad 1');
      expect(activities.single.order, 1);
      expect(activities.single, isA<LearningActivity>());
    });

    test('loads exactly twelve quiz questions', () async {
      final questions = await repository.loadQuizQuestions(
        LocalContentRepository.relationsViolenceCategoryId,
      );

      expect(questions, hasLength(12));
      expect(questions.map((question) => question.id).toSet(), hasLength(12));
      expect(
        questions.every(
          (question) =>
              question.categoryId ==
                  LocalContentRepository.relationsViolenceCategoryId &&
              question.activityId == 'relations_violence_activity_01',
        ),
        isTrue,
      );
    });

    test('decodes all supported question types', () async {
      final questions = await repository.loadQuizQuestions(
        LocalContentRepository.relationsViolenceCategoryId,
      );
      final types = questions.map((question) => question.type).toSet();

      expect(
        types,
        containsAll(<QuestionType>{
          QuestionType.multipleChoice,
          QuestionType.trueFalse,
          QuestionType.fillBlank,
        }),
      );
    });

    test('preserves normalized quiz question fields', () async {
      final questions = await repository.loadQuizQuestions(
        LocalContentRepository.relationsViolenceCategoryId,
      );
      final question = questions.first;

      expect(question.id, 'activity_1');
      expect(question.categoryId, 'relations_violence_digital');
      expect(question.activityId, 'relations_violence_activity_01');
      expect(question.type, QuestionType.multipleChoice);
      expect(question.options, hasLength(4));
      expect(question.correctAnswer, 'control_passwords_threaten_messages');
      expect(question.acceptedAnswers, <String>[
        'control_passwords_threaten_messages',
      ]);
      expect(
        question.feedback,
        'El control, la vigilancia y las amenazas mediante tecnología son '
        'formas de violencia.',
      );
      expect(question.capacity, 'reconocer');
      expect(question.difficulty, 'básica');
    });

    test('validates answer ids and approved fill blank variants', () async {
      final questions = await repository.loadQuizQuestions(
        LocalContentRepository.relationsViolenceCategoryId,
      );
      final multipleChoice = questions.first;
      final trueFalse = questions.firstWhere((question) {
        return question.type == QuestionType.trueFalse;
      });
      final sextortion = questions.firstWhere((question) {
        return question.id == 'activity_6';
      });

      expect(
        multipleChoice.isCorrectAnswer('control_passwords_threaten_messages'),
        isTrue,
      );
      expect(trueFalse.isCorrectAnswer('false'), isTrue);
      expect(sextortion.isCorrectAnswer(' Sextorsión '), isTrue);
      expect(sextortion.isCorrectAnswer('sextorsion'), isTrue);
      expect(sextortion.isCorrectAnswer('sextor'), isFalse);
    });

    test('throws a controlled error for unsupported content', () async {
      expect(
        () => repository.loadLessonPages('locked_category'),
        throwsA(isA<ContentLoadException>()),
      );
    });
  });
}
