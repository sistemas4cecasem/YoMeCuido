import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/category.dart';
import '../models/final_exam.dart';
import '../models/learning_activity.dart';
import '../models/lesson_page.dart';
import '../models/quiz_question.dart';
import 'educational_content_firestore_mapper.dart';

class EducationalContentFirestoreRepository {
  EducationalContentFirestoreRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static const categoriesCollection = 'categories';
  static const lessonPagesCollection = 'lessonPages';
  static const activitiesCollection = 'activities';
  static const questionsCollection = 'questions';
  static const examConfigCollection = 'examConfig';
  static const finalExamDocumentId = 'final';

  final FirebaseFirestore _firestore;

  Future<List<Category>> loadCategories() async {
    final snapshot = await _categories.orderBy('order').get();
    return snapshot.docs
        .map((document) {
          return EducationalContentFirestoreMapper.categoryFromMap(
            document.data(),
            documentId: document.id,
          );
        })
        .toList(growable: false);
  }

  Future<Category> loadCategory(String categoryId) async {
    final document = await _category(categoryId).get();
    final data = document.data();
    if (data == null) {
      throw const EducationalContentNotFoundException('Category not found.');
    }
    return EducationalContentFirestoreMapper.categoryFromMap(
      data,
      documentId: document.id,
    );
  }

  Future<List<LessonPage>> loadLessonPages(String categoryId) async {
    final snapshot = await _lessonPages(categoryId).orderBy('order').get();
    return snapshot.docs
        .map((document) {
          return EducationalContentFirestoreMapper.lessonPageFromMap(
            document.data(),
            documentId: document.id,
          );
        })
        .toList(growable: false);
  }

  Future<List<LearningActivity>> loadActivities(String categoryId) async {
    final snapshot = await _activities(categoryId).orderBy('order').get();
    return snapshot.docs
        .map((document) {
          return EducationalContentFirestoreMapper.activityFromMap(
            document.data(),
            documentId: document.id,
            categoryId: categoryId,
          );
        })
        .toList(growable: false);
  }

  Future<List<QuizQuestion>> loadQuestions(
    String categoryId, {
    String? activityId,
  }) async {
    Query<Map<String, Object?>> query = _questions(categoryId);
    if (activityId != null) {
      query = query.where('activityId', isEqualTo: activityId);
    }
    final snapshot = await query.get();
    return snapshot.docs
        .map((document) {
          return EducationalContentFirestoreMapper.questionFromMap(
            document.data(),
            documentId: document.id,
            categoryId: categoryId,
          );
        })
        .toList(growable: false);
  }

  Future<FinalExamConfig> loadFinalExamConfig(String categoryId) async {
    final document = await _examConfig(categoryId).get();
    final data = document.data();
    if (data == null) {
      throw const EducationalContentNotFoundException(
        'Final exam config not found.',
      );
    }
    return EducationalContentFirestoreMapper.examConfigFromMap(
      data,
      documentId: document.id,
      categoryId: categoryId,
    );
  }

  Future<void> saveCategoryFixture({
    required Category category,
    required List<LessonPage> lessonPages,
    required List<LearningActivity> activities,
    required List<QuizQuestion> questions,
    required FinalExamConfig examConfig,
  }) async {
    final batch = _firestore.batch();
    batch.set(
      _category(category.id),
      EducationalContentFirestoreMapper.categoryToMap(category),
    );
    for (final page in lessonPages) {
      batch.set(
        _lessonPages(category.id).doc(page.id),
        EducationalContentFirestoreMapper.lessonPageToMap(page),
      );
    }
    for (final activity in activities) {
      batch.set(
        _activities(category.id).doc(activity.id),
        EducationalContentFirestoreMapper.activityToMap(activity),
      );
    }
    for (final question in questions) {
      batch.set(
        _questions(category.id).doc(question.id),
        EducationalContentFirestoreMapper.questionToMap(question),
      );
    }
    batch.set(
      _examConfig(category.id),
      EducationalContentFirestoreMapper.examConfigToMap(examConfig),
    );
    await batch.commit();
  }

  CollectionReference<Map<String, Object?>> get _categories {
    return _firestore.collection(categoriesCollection);
  }

  DocumentReference<Map<String, Object?>> _category(String categoryId) {
    return _categories.doc(categoryId);
  }

  CollectionReference<Map<String, Object?>> _lessonPages(String categoryId) {
    return _category(categoryId).collection(lessonPagesCollection);
  }

  CollectionReference<Map<String, Object?>> _activities(String categoryId) {
    return _category(categoryId).collection(activitiesCollection);
  }

  CollectionReference<Map<String, Object?>> _questions(String categoryId) {
    return _category(categoryId).collection(questionsCollection);
  }

  DocumentReference<Map<String, Object?>> _examConfig(String categoryId) {
    return _category(
      categoryId,
    ).collection(examConfigCollection).doc(finalExamDocumentId);
  }
}

class EducationalContentNotFoundException implements Exception {
  const EducationalContentNotFoundException(this.message);

  final String message;

  @override
  String toString() => message;
}
