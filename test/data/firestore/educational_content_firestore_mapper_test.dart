import 'package:demo_yomecuido/data/firestore/educational_content_firestore_mapper.dart';
import 'package:demo_yomecuido/data/models/category.dart';
import 'package:demo_yomecuido/data/models/final_exam.dart';
import 'package:demo_yomecuido/data/models/learning_activity.dart';
import 'package:demo_yomecuido/data/models/lesson_page.dart';
import 'package:demo_yomecuido/data/models/quiz_question.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EducationalContentFirestoreMapper', () {
    test('preserves category fields and stable document id', () {
      const category = Category(
        id: 'relations_violence_digital',
        title: 'Relaciones y violencia digital',
        description: 'Descripcion',
        iconName: 'shield_outlined',
        status: CategoryStatus.available,
        isEnabled: true,
        indicators: <String>['12 actividades'],
        objectives: <String>['Reconocer riesgos.'],
        warning: 'Contenido sensible.',
        lessonId: 'relations_violence',
      );

      final data = EducationalContentFirestoreMapper.categoryToMap(
        category,
        order: 1,
      );
      final rebuilt = EducationalContentFirestoreMapper.categoryFromMap(
        data,
        documentId: category.id,
      );

      expect(data['id'], category.id);
      expect(data['order'], 1);
      expect(rebuilt.id, category.id);
      expect(rebuilt.title, category.title);
      expect(rebuilt.status, CategoryStatus.available);
      expect(rebuilt.warning, category.warning);
      expect(rebuilt.lessonId, category.lessonId);
    });

    test('preserves lesson page order and document id', () {
      const page = LessonPage(
        id: 'what_is_digital_violence',
        order: 1,
        title: 'Que es la violencia digital',
        body: 'Contenido teorico.',
      );

      final data = EducationalContentFirestoreMapper.lessonPageToMap(page);
      final rebuilt = EducationalContentFirestoreMapper.lessonPageFromMap(
        data,
        documentId: page.id,
      );

      expect(rebuilt.id, page.id);
      expect(rebuilt.order, 1);
      expect(rebuilt.title, page.title);
      expect(rebuilt.body, page.body);
    });

    test('preserves activity id and parent category relationship', () {
      const activity = LearningActivity(
        id: 'relations_violence_activity_01',
        categoryId: 'relations_violence_digital',
        title: 'Actividad 1',
        order: 1,
      );

      final data = EducationalContentFirestoreMapper.activityToMap(activity);
      final rebuilt = EducationalContentFirestoreMapper.activityFromMap(
        data,
        documentId: activity.id,
        categoryId: activity.categoryId,
      );

      expect(rebuilt.id, activity.id);
      expect(rebuilt.categoryId, activity.categoryId);
      expect(rebuilt.order, activity.order);
    });

    test(
      'preserves question options, ids, feedback, capacity and difficulty',
      () {
        const question = QuizQuestion(
          id: 'question_01',
          categoryId: 'relations_violence_digital',
          activityId: 'relations_violence_activity_01',
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
          difficulty: 'intermedia',
        );

        final data = EducationalContentFirestoreMapper.questionToMap(question);
        final rebuilt = EducationalContentFirestoreMapper.questionFromMap(
          data,
          documentId: question.id,
          categoryId: question.categoryId,
        );

        expect(rebuilt.id, question.id);
        expect(rebuilt.categoryId, question.categoryId);
        expect(rebuilt.activityId, question.activityId);
        expect(rebuilt.type, QuestionType.multipleChoice);
        expect(rebuilt.options.map((option) => option.id), <String>[
          'safe',
          'unsafe',
        ]);
        expect(rebuilt.correctAnswer, 'safe');
        expect(rebuilt.feedback, question.feedback);
        expect(rebuilt.capacity, question.capacity);
        expect(rebuilt.difficulty, question.difficulty);
      },
    );

    test('preserves fill blank accepted answers', () {
      const question = QuizQuestion(
        id: 'question_fill',
        categoryId: 'relations_violence_digital',
        activityId: 'relations_violence_activity_01',
        type: QuestionType.fillBlank,
        statement: 'Completa.',
        options: <QuizOption>[],
        correctAnswer: 'sextorsión',
        acceptedAnswers: <String>['sextorsión', 'sextorsion'],
        feedback: 'Retroalimentacion.',
        capacity: 'reconocer',
        difficulty: 'intermedia',
      );

      final data = EducationalContentFirestoreMapper.questionToMap(question);
      final rebuilt = EducationalContentFirestoreMapper.questionFromMap(
        data,
        documentId: question.id,
        categoryId: question.categoryId,
      );

      expect(rebuilt.options, isEmpty);
      expect(rebuilt.acceptedAnswers, <String>['sextorsión', 'sextorsion']);
      expect(rebuilt.correctAnswer, 'sextorsión');
    });

    test('preserves final exam configuration', () {
      const exam = FinalExamConfigs.relationsViolence;

      final data = EducationalContentFirestoreMapper.examConfigToMap(exam);
      final rebuilt = EducationalContentFirestoreMapper.examConfigFromMap(
        data,
        documentId: 'final',
        categoryId: exam.categoryId,
      );

      expect(data['targetBasicQuestions'], 6);
      expect(data['targetIntermediateQuestions'], 9);
      expect(rebuilt.id, exam.id);
      expect(rebuilt.categoryId, exam.categoryId);
      expect(rebuilt.questionCount, 15);
      expect(rebuilt.minimumQuestionsPerActivity, 2);
      expect(rebuilt.targetDifficultyCounts, <String, int>{
        'básica': 6,
        'intermedia': 9,
      });
    });
  });
}
