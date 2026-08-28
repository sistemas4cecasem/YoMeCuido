import 'dart:convert';
import 'dart:io';

import 'package:demo_yomecuido/data/firestore/educational_content_seed.dart';
import 'package:demo_yomecuido/data/models/category.dart';
import 'package:demo_yomecuido/data/models/final_exam.dart';
import 'package:demo_yomecuido/data/models/learning_activity.dart';
import 'package:demo_yomecuido/data/models/lesson_page.dart';
import 'package:demo_yomecuido/data/models/quiz_question.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EducationalContentSeedBuilder', () {
    test('builds a seed plan from the current local JSON content', () async {
      final bundle = await _loadCurrentBundle();
      final plan = EducationalContentSeedBuilder.build(bundle);

      expect(plan.categoryCount, 8);
      expect(plan.lessonPageCount, 4);
      expect(plan.activityCount, 6);
      expect(plan.questionCount, 12);
      expect(plan.examConfigCount, 1);
      expect(plan.documents, hasLength(31));
      expect(plan.paths, contains('categories/relations_violence_digital'));
      expect(
        plan.paths,
        contains(
          'categories/relations_violence_digital/'
          'lessonPages/what_is_digital_violence',
        ),
      );
      expect(
        plan.paths,
        contains(
          'categories/relations_violence_digital/'
          'activities/relations_violence_activity_01',
        ),
      );
      expect(
        plan.paths,
        contains('categories/relations_violence_digital/questions/activity_1'),
      );
      expect(
        plan.paths,
        contains('categories/relations_violence_digital/examConfig/final'),
      );
    });

    test('uses stable paths so repeated builds are idempotent', () async {
      final bundle = await _loadCurrentBundle();
      final firstPlan = EducationalContentSeedBuilder.build(bundle);
      final secondPlan = EducationalContentSeedBuilder.build(bundle);

      expect(secondPlan.paths, firstPlan.paths);
      expect(firstPlan.paths.toSet(), hasLength(firstPlan.paths.length));
    });

    test('preserves option ids and answer fields in question documents', () {
      final plan = EducationalContentSeedBuilder.build(_validBundle());
      final questionDocument = plan.documents.singleWhere(
        (document) => document.path.endsWith('/questions/question_01'),
      );

      expect(questionDocument.data['correctAnswer'], 'safe');
      expect(questionDocument.data['acceptedAnswers'], <String>['safe']);
      expect(questionDocument.data['feedback'], 'Retroalimentacion.');
      expect(questionDocument.data['capacity'], 'responder');
      expect(questionDocument.data['difficulty'], 'básica');
      expect(questionDocument.data['options'], <Map<String, Object?>>[
        <String, Object?>{'id': 'safe', 'text': 'Respuesta segura'},
        <String, Object?>{'id': 'unsafe', 'text': 'Respuesta insegura'},
      ]);
    });

    test('fails when a content id is empty', () {
      final bundle = _validBundle(
        activities: const <LearningActivity>[
          LearningActivity(
            id: '',
            categoryId: _categoryId,
            title: 'Actividad 1',
            order: 1,
          ),
        ],
      );

      expect(
        () => EducationalContentSeedBuilder.build(bundle),
        throwsA(isA<EducationalContentSeedException>()),
      );
    });

    test('fails when a question references an unknown activity', () {
      final bundle = _validBundle(
        questions: const <QuizQuestion>[
          QuizQuestion(
            id: 'question_01',
            categoryId: _categoryId,
            activityId: 'missing_activity',
            type: QuestionType.multipleChoice,
            statement: 'Pregunta',
            options: <QuizOption>[
              QuizOption(id: 'safe', text: 'Respuesta segura'),
            ],
            correctAnswer: 'safe',
            acceptedAnswers: <String>['safe'],
            feedback: 'Retroalimentacion.',
            capacity: 'responder',
            difficulty: 'básica',
          ),
        ],
      );

      expect(
        () => EducationalContentSeedBuilder.build(bundle),
        throwsA(isA<EducationalContentSeedException>()),
      );
    });

    test('fails when correctAnswer does not match an option id', () {
      final bundle = _validBundle(
        questions: const <QuizQuestion>[
          QuizQuestion(
            id: 'question_01',
            categoryId: _categoryId,
            activityId: _activityId,
            type: QuestionType.multipleChoice,
            statement: 'Pregunta',
            options: <QuizOption>[
              QuizOption(id: 'safe', text: 'Respuesta segura'),
            ],
            correctAnswer: 'missing',
            acceptedAnswers: <String>['missing'],
            feedback: 'Retroalimentacion.',
            capacity: 'responder',
            difficulty: 'básica',
          ),
        ],
      );

      expect(
        () => EducationalContentSeedBuilder.build(bundle),
        throwsA(isA<EducationalContentSeedException>()),
      );
    });

    test('fails when an option id is empty', () {
      final bundle = _validBundle(
        questions: const <QuizQuestion>[
          QuizQuestion(
            id: 'question_01',
            categoryId: _categoryId,
            activityId: _activityId,
            type: QuestionType.multipleChoice,
            statement: 'Pregunta',
            options: <QuizOption>[QuizOption(id: '', text: 'Respuesta segura')],
            correctAnswer: 'safe',
            acceptedAnswers: <String>['safe'],
            feedback: 'Retroalimentacion.',
            capacity: 'responder',
            difficulty: 'básica',
          ),
        ],
      );

      expect(
        () => EducationalContentSeedBuilder.build(bundle),
        throwsA(isA<EducationalContentSeedException>()),
      );
    });

    test('fails when exam target counts do not match questionCount', () {
      final bundle = _validBundle(
        examConfig: const FinalExamConfig(
          id: 'relations_violence_final_exam',
          categoryId: _categoryId,
          title: 'Examen final',
          questionCount: 15,
          minimumQuestionsPerActivity: 2,
          targetDifficultyCounts: <String, int>{'básica': 5, 'intermedia': 9},
          order: 7,
        ),
      );

      expect(
        () => EducationalContentSeedBuilder.build(bundle),
        throwsA(isA<EducationalContentSeedException>()),
      );
    });
  });
}

const _categoryId = 'relations_violence_digital';
const _activityId = 'relations_violence_activity_01';

Future<EducationalContentSeedBundle> _loadCurrentBundle() async {
  final categories = await _loadList(
    'tool/seed/content/categories.json',
    'categories',
    Category.fromJson,
  );
  final lessonPages = await _loadList(
    'tool/seed/content/relations_violence_lesson.json',
    'lessonPages',
    LessonPage.fromJson,
  );
  final activities = await _loadList(
    'tool/seed/content/relations_violence_activities.json',
    'activities',
    LearningActivity.fromJson,
  );
  final questions = await _loadList(
    'tool/seed/content/relations_violence_questions.json',
    'questions',
    QuizQuestion.fromJson,
  );

  return EducationalContentSeedBundle(
    categories: categories,
    lessonPagesByCategory: <String, List<LessonPage>>{_categoryId: lessonPages},
    activitiesByCategory: <String, List<LearningActivity>>{
      _categoryId: activities,
    },
    questionsByCategory: <String, List<QuizQuestion>>{_categoryId: questions},
    examConfigsByCategory: <String, FinalExamConfig>{
      _categoryId: FinalExamConfigs.relationsViolence,
    },
  );
}

Future<List<T>> _loadList<T>(
  String path,
  String listKey,
  T Function(Map<String, Object?> json) parser,
) async {
  final decoded = jsonDecode(await File(path).readAsString());
  final root = decoded as Map<String, Object?>;
  final list = root[listKey] as List<Object?>;
  return list
      .map((item) => parser(item as Map<String, Object?>))
      .toList(growable: false);
}

EducationalContentSeedBundle _validBundle({
  List<LearningActivity>? activities,
  List<QuizQuestion>? questions,
  FinalExamConfig? examConfig,
}) {
  const category = Category(
    id: _categoryId,
    title: 'Relaciones y violencia digital',
    description: 'Descripcion.',
    iconName: 'shield_outlined',
    status: CategoryStatus.available,
    isEnabled: true,
    indicators: <String>['12 actividades'],
    objectives: <String>['Reconocer riesgos.'],
    warning: 'Advertencia.',
    lessonId: 'relations_violence',
  );
  const page = LessonPage(
    id: 'what_is_digital_violence',
    order: 1,
    title: 'Que es',
    body: 'Contenido.',
  );
  const defaultActivities = <LearningActivity>[
    LearningActivity(
      id: _activityId,
      categoryId: _categoryId,
      title: 'Actividad 1',
      order: 1,
    ),
  ];
  const defaultQuestions = <QuizQuestion>[
    QuizQuestion(
      id: 'question_01',
      categoryId: _categoryId,
      activityId: _activityId,
      type: QuestionType.multipleChoice,
      statement: 'Pregunta',
      options: <QuizOption>[
        QuizOption(id: 'safe', text: 'Respuesta segura'),
        QuizOption(id: 'unsafe', text: 'Respuesta insegura'),
      ],
      correctAnswer: 'safe',
      acceptedAnswers: <String>['safe'],
      feedback: 'Retroalimentacion.',
      capacity: 'responder',
      difficulty: 'básica',
    ),
  ];
  const defaultExamConfig = FinalExamConfig(
    id: 'relations_violence_final_exam',
    categoryId: _categoryId,
    title: 'Examen final',
    questionCount: 1,
    minimumQuestionsPerActivity: 1,
    targetDifficultyCounts: <String, int>{'básica': 1},
    order: 7,
  );

  return EducationalContentSeedBundle(
    categories: const <Category>[category],
    lessonPagesByCategory: const <String, List<LessonPage>>{
      _categoryId: <LessonPage>[page],
    },
    activitiesByCategory: <String, List<LearningActivity>>{
      _categoryId: activities ?? defaultActivities,
    },
    questionsByCategory: <String, List<QuizQuestion>>{
      _categoryId: questions ?? defaultQuestions,
    },
    examConfigsByCategory: <String, FinalExamConfig>{
      _categoryId: examConfig ?? defaultExamConfig,
    },
  );
}
