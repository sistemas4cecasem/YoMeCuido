import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore/educational_content_firestore_mapper.dart';
import '../models/category.dart';
import '../models/final_exam.dart';
import '../models/learning_activity.dart';
import '../models/lesson_page.dart';
import '../models/quiz_question.dart';
import 'content_repository.dart';

class FirestoreContentRepository implements ContentRepository {
  FirestoreContentRepository({FirestoreContentSource? source})
    : _source = source ?? CloudFirestoreContentSource();

  static const categoriesCollection = 'categories';
  static const lessonPagesCollection = 'lessonPages';
  static const activitiesCollection = 'activities';
  static const questionsCollection = 'questions';
  static const examConfigCollection = 'examConfig';
  static const finalExamDocumentId = 'final';

  final FirestoreContentSource _source;

  @override
  Future<List<Category>> loadCategories() async {
    return _load(() async {
      final documents = await _source.listCollection(
        categoriesCollection,
        orderBy: 'order',
      );
      return documents
          .map((document) {
            return EducationalContentFirestoreMapper.categoryFromMap(
              document.data,
              documentId: document.id,
            );
          })
          .toList(growable: false);
    });
  }

  @override
  Future<List<LessonPage>> loadLessonPages(String categoryId) async {
    return _load(() async {
      final documents = await _source.listCollection(
        _categoryCollectionPath(categoryId, lessonPagesCollection),
        orderBy: 'order',
      );
      final pages = documents
          .map((document) {
            return EducationalContentFirestoreMapper.lessonPageFromMap(
              document.data,
              documentId: document.id,
            );
          })
          .toList(growable: false);

      return pages..sort((a, b) => a.order.compareTo(b.order));
    });
  }

  @override
  Future<List<LearningActivity>> loadActivities(String categoryId) async {
    return _load(() async {
      final documents = await _source.listCollection(
        _categoryCollectionPath(categoryId, activitiesCollection),
        orderBy: 'order',
      );
      final activities = documents
          .map((document) {
            return EducationalContentFirestoreMapper.activityFromMap(
              document.data,
              documentId: document.id,
              categoryId: categoryId,
            );
          })
          .toList(growable: false);

      return activities..sort((a, b) => a.order.compareTo(b.order));
    });
  }

  @override
  Future<List<QuizQuestion>> loadQuizQuestions(
    String categoryId, {
    String? activityId,
  }) async {
    return _load(() async {
      final questionsPath = _categoryCollectionPath(
        categoryId,
        questionsCollection,
      );
      final documents = activityId == null
          ? await _source.listCollection(questionsPath)
          : await _source.queryCollection(
              questionsPath,
              field: 'activityId',
              isEqualTo: activityId,
            );

      return documents
          .map((document) {
            return EducationalContentFirestoreMapper.questionFromMap(
              document.data,
              documentId: document.id,
              categoryId: categoryId,
            );
          })
          .toList(growable: false);
    });
  }

  @override
  Future<FinalExamConfig?> loadFinalExamConfig(String categoryId) async {
    return _load(() async {
      final document = await _source.readDocument(
        '${_categoryCollectionPath(categoryId, examConfigCollection)}/'
        '$finalExamDocumentId',
      );
      if (document == null) {
        return null;
      }

      return EducationalContentFirestoreMapper.examConfigFromMap(
        document.data,
        documentId: document.id,
        categoryId: categoryId,
      );
    });
  }

  Future<T> _load<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on ContentLoadException {
      rethrow;
    } catch (_) {
      throw const ContentLoadException();
    }
  }

  String _categoryCollectionPath(String categoryId, String collectionId) {
    return '$categoriesCollection/$categoryId/$collectionId';
  }
}

class FirestoreContentDocument {
  const FirestoreContentDocument({required this.id, required this.data});

  final String id;
  final Map<String, Object?> data;
}

abstract class FirestoreContentSource {
  Future<List<FirestoreContentDocument>> listCollection(
    String path, {
    String? orderBy,
  });

  Future<List<FirestoreContentDocument>> queryCollection(
    String path, {
    required String field,
    required Object? isEqualTo,
  });

  Future<FirestoreContentDocument?> readDocument(String path);
}

class CloudFirestoreContentSource implements FirestoreContentSource {
  CloudFirestoreContentSource({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<List<FirestoreContentDocument>> listCollection(
    String path, {
    String? orderBy,
  }) async {
    Query<Map<String, dynamic>> query = _firestore.collection(path);
    if (orderBy != null) {
      query = query.orderBy(orderBy);
    }

    final snapshot = await query.get();
    return snapshot.docs.map(_fromSnapshot).toList(growable: false);
  }

  @override
  Future<List<FirestoreContentDocument>> queryCollection(
    String path, {
    required String field,
    required Object? isEqualTo,
  }) async {
    final snapshot = await _firestore
        .collection(path)
        .where(field, isEqualTo: isEqualTo)
        .get();
    return snapshot.docs.map(_fromSnapshot).toList(growable: false);
  }

  @override
  Future<FirestoreContentDocument?> readDocument(String path) async {
    final snapshot = await _firestore.doc(path).get();
    final data = snapshot.data();
    if (data == null) {
      return null;
    }

    return FirestoreContentDocument(
      id: snapshot.id,
      data: _normalizeData(data),
    );
  }

  FirestoreContentDocument _fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return FirestoreContentDocument(
      id: snapshot.id,
      data: _normalizeData(snapshot.data()),
    );
  }

  Map<String, Object?> _normalizeData(Map<String, dynamic> data) {
    return data.map((key, value) => MapEntry(key, _normalizeValue(value)));
  }

  Object? _normalizeValue(Object? value) {
    if (value is Map) {
      final normalized = <String, Object?>{};
      for (final entry in value.entries) {
        final key = entry.key;
        if (key is! String) {
          throw const FormatException('Firestore map keys must be strings.');
        }
        normalized[key] = _normalizeValue(entry.value);
      }
      return normalized;
    }
    if (value is List) {
      return value.map(_normalizeValue).toList(growable: false);
    }

    return value;
  }
}
