import 'package:demo_yomecuido/data/firestore/educational_content_firestore_mapper.dart';
import 'package:demo_yomecuido/data/models/category.dart';
import 'package:demo_yomecuido/data/models/final_exam.dart';
import 'package:demo_yomecuido/data/models/learning_activity.dart';
import 'package:demo_yomecuido/data/models/lesson_page.dart';
import 'package:demo_yomecuido/data/models/quiz_question.dart';
import 'package:demo_yomecuido/data/repositories/content_repository.dart';
import 'package:demo_yomecuido/data/repositories/firestore_content_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FirestoreContentRepository', () {
    test(
      'loads categories from Firestore data preserving stable ids',
      () async {
        final repository = FirestoreContentRepository(source: _fakeSource());

        final categories = await repository.loadCategories();

        expect(categories, hasLength(2));
        expect(categories.map((category) => category.id), <String>[
          'relations_violence_digital',
          'account_protection_authentication',
        ]);
        expect(categories.first.status, CategoryStatus.available);
        expect(categories.first.isEnabled, isTrue);
      },
    );

    test('loads ordered lesson pages from category subcollection', () async {
      final repository = FirestoreContentRepository(source: _fakeSource());

      final pages = await repository.loadLessonPages(_categoryId);

      expect(pages.map((page) => page.id), <String>[
        'what_is_digital_violence',
        'control_is_not_care',
      ]);
      expect(pages.map((page) => page.order), <int>[1, 2]);
    });

    test('loads ordered activities from category subcollection', () async {
      final repository = FirestoreContentRepository(source: _fakeSource());

      final activities = await repository.loadActivities(_categoryId);

      expect(activities.map((activity) => activity.id), <String>[
        'relations_violence_activity_01',
        'relations_violence_activity_02',
      ]);
      expect(activities.map((activity) => activity.order), <int>[1, 2]);
    });

    test('filters quiz questions by activityId', () async {
      final repository = FirestoreContentRepository(source: _fakeSource());

      final questions = await repository.loadQuizQuestions(
        _categoryId,
        activityId: 'relations_violence_activity_02',
      );

      expect(questions, hasLength(1));
      expect(questions.single.id, 'activity_2');
      expect(questions.single.activityId, 'relations_violence_activity_02');
      expect(questions.single.options.map((option) => option.id), <String>[
        'true',
        'false',
      ]);
      expect(questions.single.correctAnswer, 'false');
      expect(questions.single.capacity, 'reconocer');
      expect(questions.single.difficulty, 'básica');
    });

    test('loads the full question bank for a category', () async {
      final repository = FirestoreContentRepository(source: _fakeSource());

      final questions = await repository.loadQuizQuestions(_categoryId);

      expect(questions.map((question) => question.id), <String>[
        'activity_1',
        'activity_2',
      ]);
    });

    test('loads final exam config from remote content', () async {
      final repository = FirestoreContentRepository(source: _fakeSource());

      final exam = await repository.loadFinalExamConfig(_categoryId);

      expect(exam, isNotNull);
      expect(exam!.id, FinalExamConfigs.relationsViolence.id);
      expect(exam.categoryId, _categoryId);
      expect(exam.questionCount, 15);
      expect(exam.minimumQuestionsPerActivity, 2);
      expect(exam.targetDifficultyCounts, <String, int>{
        'básica': 6,
        'intermedia': 9,
      });
    });

    test('returns null when final exam config does not exist', () async {
      final repository = FirestoreContentRepository(source: _fakeSource());

      final exam = await repository.loadFinalExamConfig(
        'account_protection_authentication',
      );

      expect(exam, isNull);
    });

    test('throws a controlled error for malformed remote content', () async {
      final source = _FakeFirestoreContentSource(<String, List<_SeedDoc>>{
        'categories': <_SeedDoc>[
          _SeedDoc('wrong_document_id', <String, Object?>{
            ...EducationalContentFirestoreMapper.categoryToMap(
              _availableCategory,
            ),
          }),
        ],
      });
      final repository = FirestoreContentRepository(source: source);

      expect(repository.loadCategories, throwsA(isA<ContentLoadException>()));
    });
  });
}

const _categoryId = 'relations_violence_digital';

const _availableCategory = Category(
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

const _lockedCategory = Category(
  id: 'account_protection_authentication',
  title: 'Protección de cuentas y autenticación',
  description: 'Esta categoría estará disponible próximamente.',
  iconName: 'lock_outline',
  status: CategoryStatus.comingSoon,
  isEnabled: false,
  indicators: <String>[],
  objectives: <String>[],
);

FirestoreContentSource _fakeSource() {
  const pageOne = LessonPage(
    id: 'what_is_digital_violence',
    order: 1,
    title: 'Que es',
    body: 'Contenido uno.',
  );
  const pageTwo = LessonPage(
    id: 'control_is_not_care',
    order: 2,
    title: 'Control',
    body: 'Contenido dos.',
  );
  const activityOne = LearningActivity(
    id: 'relations_violence_activity_01',
    categoryId: _categoryId,
    title: 'Actividad 1',
    order: 1,
  );
  const activityTwo = LearningActivity(
    id: 'relations_violence_activity_02',
    categoryId: _categoryId,
    title: 'Actividad 2',
    order: 2,
  );
  const questionOne = QuizQuestion(
    id: 'activity_1',
    categoryId: _categoryId,
    activityId: 'relations_violence_activity_01',
    type: QuestionType.multipleChoice,
    statement: 'Pregunta uno',
    options: <QuizOption>[
      QuizOption(id: 'safe', text: 'Segura'),
      QuizOption(id: 'unsafe', text: 'Insegura'),
    ],
    correctAnswer: 'safe',
    acceptedAnswers: <String>['safe'],
    feedback: 'Retroalimentacion.',
    capacity: 'responder',
    difficulty: 'intermedia',
  );
  const questionTwo = QuizQuestion(
    id: 'activity_2',
    categoryId: _categoryId,
    activityId: 'relations_violence_activity_02',
    type: QuestionType.trueFalse,
    statement: 'Pregunta dos',
    options: <QuizOption>[
      QuizOption(id: 'true', text: 'Verdadero'),
      QuizOption(id: 'false', text: 'Falso'),
    ],
    correctAnswer: 'false',
    acceptedAnswers: <String>['false'],
    feedback: 'Retroalimentacion.',
    capacity: 'reconocer',
    difficulty: 'básica',
  );

  return _FakeFirestoreContentSource(<String, List<_SeedDoc>>{
    'categories': <_SeedDoc>[
      _SeedDoc(
        _lockedCategory.id,
        EducationalContentFirestoreMapper.categoryToMap(
          _lockedCategory,
          order: 2,
        ),
      ),
      _SeedDoc(
        _availableCategory.id,
        EducationalContentFirestoreMapper.categoryToMap(
          _availableCategory,
          order: 1,
        ),
      ),
    ],
    'categories/$_categoryId/lessonPages': <_SeedDoc>[
      _SeedDoc(
        pageTwo.id,
        EducationalContentFirestoreMapper.lessonPageToMap(pageTwo),
      ),
      _SeedDoc(
        pageOne.id,
        EducationalContentFirestoreMapper.lessonPageToMap(pageOne),
      ),
    ],
    'categories/$_categoryId/activities': <_SeedDoc>[
      _SeedDoc(
        activityTwo.id,
        EducationalContentFirestoreMapper.activityToMap(activityTwo),
      ),
      _SeedDoc(
        activityOne.id,
        EducationalContentFirestoreMapper.activityToMap(activityOne),
      ),
    ],
    'categories/$_categoryId/questions': <_SeedDoc>[
      _SeedDoc(
        questionOne.id,
        EducationalContentFirestoreMapper.questionToMap(questionOne),
      ),
      _SeedDoc(
        questionTwo.id,
        EducationalContentFirestoreMapper.questionToMap(questionTwo),
      ),
    ],
    'categories/$_categoryId/examConfig': <_SeedDoc>[
      _SeedDoc(
        'final',
        EducationalContentFirestoreMapper.examConfigToMap(
          FinalExamConfigs.relationsViolence,
        ),
      ),
    ],
  });
}

class _FakeFirestoreContentSource implements FirestoreContentSource {
  const _FakeFirestoreContentSource(this.collections);

  final Map<String, List<_SeedDoc>> collections;

  @override
  Future<List<FirestoreContentDocument>> listCollection(
    String path, {
    String? orderBy,
  }) async {
    final docs = [...collections[path] ?? const <_SeedDoc>[]];
    if (orderBy != null) {
      docs.sort((a, b) {
        final left = a.data[orderBy] as int;
        final right = b.data[orderBy] as int;
        return left.compareTo(right);
      });
    }

    return docs.map((doc) => doc.toContentDocument()).toList(growable: false);
  }

  @override
  Future<List<FirestoreContentDocument>> queryCollection(
    String path, {
    required String field,
    required Object? isEqualTo,
  }) async {
    return (collections[path] ?? const <_SeedDoc>[])
        .where((doc) => doc.data[field] == isEqualTo)
        .map((doc) => doc.toContentDocument())
        .toList(growable: false);
  }

  @override
  Future<FirestoreContentDocument?> readDocument(String path) async {
    final segments = path.split('/');
    final documentId = segments.removeLast();
    final collectionPath = segments.join('/');
    for (final doc in collections[collectionPath] ?? const <_SeedDoc>[]) {
      if (doc.id == documentId) {
        return doc.toContentDocument();
      }
    }
    return null;
  }
}

class _SeedDoc {
  const _SeedDoc(this.id, this.data);

  final String id;
  final Map<String, Object?> data;

  FirestoreContentDocument toContentDocument() {
    return FirestoreContentDocument(id: id, data: data);
  }
}
