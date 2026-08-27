import 'dart:math' as math;

import '../../data/models/final_exam.dart';
import '../../data/models/quiz_question.dart';
import '../../data/repositories/content_repository.dart';

class InsufficientExamQuestionsException implements Exception {
  const InsufficientExamQuestionsException({
    required this.requiredQuestions,
    required this.availableQuestions,
  });

  final int requiredQuestions;
  final int availableQuestions;

  @override
  String toString() {
    return 'InsufficientExamQuestionsException($availableQuestions/'
        '$requiredQuestions)';
  }
}

class ExamQuestionSelector {
  const ExamQuestionSelector({math.Random? random}) : _random = random;

  final math.Random? _random;

  math.Random get _effectiveRandom => _random ?? math.Random();

  Future<List<QuizQuestion>> selectQuestions({
    required ContentRepository contentRepository,
    required FinalExamConfig exam,
  }) async {
    final questions = await contentRepository.loadQuizQuestions(
      exam.categoryId,
    );
    return selectFromBank(questions: questions, exam: exam);
  }

  List<QuizQuestion> selectFromBank({
    required List<QuizQuestion> questions,
    required FinalExamConfig exam,
  }) {
    final categoryQuestions = _uniqueCategoryQuestions(questions, exam);

    if (categoryQuestions.length < exam.questionCount) {
      throw InsufficientExamQuestionsException(
        requiredQuestions: exam.questionCount,
        availableQuestions: categoryQuestions.length,
      );
    }

    final selected = <QuizQuestion>[];
    final selectedIds = <String>{};
    final questionsByActivity = _groupBy<String>(
      categoryQuestions,
      (question) => question.activityId,
    );
    final activityIds = questionsByActivity.keys.toList(growable: false)
      ..shuffle(_effectiveRandom);
    final minimumByActivity = <String, int>{
      for (final activityId in activityIds)
        activityId: math.min(
          exam.minimumQuestionsPerActivity,
          questionsByActivity[activityId]!.length,
        ),
    };

    for (final activityId in activityIds) {
      final candidates = questionsByActivity[activityId]!.toList()
        ..shuffle(_effectiveRandom);
      final requiredFromActivity = minimumByActivity[activityId] ?? 0;
      while (_selectedCountForActivity(selected, activityId) <
              requiredFromActivity &&
          selected.length < exam.questionCount) {
        final next = _bestQuestion(
          candidates.where((question) => !selectedIds.contains(question.id)),
          selected,
          exam,
        );
        if (next == null) {
          break;
        }
        _addQuestion(selected, selectedIds, next);
      }
    }

    final remaining = categoryQuestions.toList()..shuffle(_effectiveRandom);
    while (selected.length < exam.questionCount) {
      final next = _bestQuestion(
        remaining.where((question) => !selectedIds.contains(question.id)),
        selected,
        exam,
      );
      if (next == null) {
        break;
      }
      _addQuestion(selected, selectedIds, next);
    }

    _rebalanceDifficulties(
      selected: selected,
      selectedIds: selectedIds,
      allQuestions: categoryQuestions,
      minimumByActivity: minimumByActivity,
      exam: exam,
    );
    _representMissingValues<String>(
      selected: selected,
      selectedIds: selectedIds,
      allQuestions: categoryQuestions,
      minimumByActivity: minimumByActivity,
      valueOf: (question) => question.capacity,
    );
    _representMissingValues<QuestionType>(
      selected: selected,
      selectedIds: selectedIds,
      allQuestions: categoryQuestions,
      minimumByActivity: minimumByActivity,
      valueOf: (question) => question.type,
    );

    _validateSelection(selected, exam);
    return List<QuizQuestion>.unmodifiable(selected);
  }

  List<QuizQuestion> _uniqueCategoryQuestions(
    List<QuizQuestion> questions,
    FinalExamConfig exam,
  ) {
    final uniqueById = <String, QuizQuestion>{};
    for (final question in questions) {
      if (question.categoryId == exam.categoryId) {
        uniqueById.putIfAbsent(question.id, () => question);
      }
    }
    return uniqueById.values.toList(growable: false);
  }

  QuizQuestion? _bestQuestion(
    Iterable<QuizQuestion> candidates,
    List<QuizQuestion> selected,
    FinalExamConfig exam,
  ) {
    QuizQuestion? best;
    var bestScore = double.negativeInfinity;

    for (final candidate in candidates) {
      final score = _scoreQuestion(candidate, selected, exam);
      if (score > bestScore) {
        best = candidate;
        bestScore = score;
      }
    }

    return best;
  }

  double _scoreQuestion(
    QuizQuestion question,
    List<QuizQuestion> selected,
    FinalExamConfig exam,
  ) {
    final currentDifficultyCount = selected.where((selectedQuestion) {
      return selectedQuestion.difficulty == question.difficulty;
    }).length;
    final targetDifficultyCount =
        exam.targetDifficultyCounts[question.difficulty];
    final difficultyScore = targetDifficultyCount == null
        ? 0.0
        : (targetDifficultyCount - currentDifficultyCount) /
              targetDifficultyCount;
    final hasCapacity = selected.any((selectedQuestion) {
      return selectedQuestion.capacity == question.capacity;
    });
    final hasType = selected.any((selectedQuestion) {
      return selectedQuestion.type == question.type;
    });

    return (difficultyScore * 100) +
        (hasCapacity ? 0 : 12) +
        (hasType ? 0 : 4) +
        _effectiveRandom.nextDouble();
  }

  void _rebalanceDifficulties({
    required List<QuizQuestion> selected,
    required Set<String> selectedIds,
    required List<QuizQuestion> allQuestions,
    required Map<String, int> minimumByActivity,
    required FinalExamConfig exam,
  }) {
    for (final target in exam.targetDifficultyCounts.entries) {
      while (_selectedCountBy(
            selected,
            (question) => question.difficulty == target.key,
          ) <
          target.value) {
        final incoming = _bestReplacementCandidate<String>(
          selected: selected,
          selectedIds: selectedIds,
          allQuestions: allQuestions,
          expectedValue: target.key,
          valueOf: (question) => question.difficulty,
        );
        if (incoming == null) {
          break;
        }
        final outgoingIndex = _replacementIndexFor(
          selected: selected,
          incoming: incoming,
          minimumByActivity: minimumByActivity,
          shouldRemove: (question) {
            final targetForCurrent =
                exam.targetDifficultyCounts[question.difficulty];
            if (question.difficulty == target.key) {
              return false;
            }
            if (targetForCurrent == null) {
              return true;
            }
            return _selectedCountBy(
                  selected,
                  (selectedQuestion) =>
                      selectedQuestion.difficulty == question.difficulty,
                ) >
                targetForCurrent;
          },
        );
        if (outgoingIndex == null) {
          break;
        }
        _replaceQuestion(selected, selectedIds, outgoingIndex, incoming);
      }
    }
  }

  void _representMissingValues<T>({
    required List<QuizQuestion> selected,
    required Set<String> selectedIds,
    required List<QuizQuestion> allQuestions,
    required Map<String, int> minimumByActivity,
    required T Function(QuizQuestion question) valueOf,
  }) {
    final availableValues = allQuestions.map(valueOf).toSet();
    if (availableValues.length > selected.length) {
      return;
    }

    for (final value in availableValues) {
      if (selected.any((question) => valueOf(question) == value)) {
        continue;
      }

      final incoming = _bestReplacementCandidate<T>(
        selected: selected,
        selectedIds: selectedIds,
        allQuestions: allQuestions,
        expectedValue: value,
        valueOf: valueOf,
      );
      if (incoming == null) {
        continue;
      }

      final outgoingIndex = _replacementIndexFor(
        selected: selected,
        incoming: incoming,
        minimumByActivity: minimumByActivity,
        shouldRemove: (question) {
          final valueCount = _selectedCountBy(
            selected,
            (selectedQuestion) =>
                valueOf(selectedQuestion) == valueOf(question),
          );
          return valueOf(question) != value && valueCount > 1;
        },
      );
      if (outgoingIndex == null) {
        continue;
      }
      _replaceQuestion(selected, selectedIds, outgoingIndex, incoming);
    }
  }

  QuizQuestion? _bestReplacementCandidate<T>({
    required List<QuizQuestion> selected,
    required Set<String> selectedIds,
    required List<QuizQuestion> allQuestions,
    required T expectedValue,
    required T Function(QuizQuestion question) valueOf,
  }) {
    final candidates = allQuestions.where((question) {
      return !selectedIds.contains(question.id) &&
          valueOf(question) == expectedValue;
    }).toList()..shuffle(_effectiveRandom);
    if (candidates.isEmpty) {
      return null;
    }
    return candidates.first;
  }

  int? _replacementIndexFor({
    required List<QuizQuestion> selected,
    required QuizQuestion incoming,
    required Map<String, int> minimumByActivity,
    required bool Function(QuizQuestion question) shouldRemove,
  }) {
    final indexes = List<int>.generate(selected.length, (index) => index)
      ..shuffle(_effectiveRandom);

    for (final index in indexes) {
      final outgoing = selected[index];
      if (!shouldRemove(outgoing)) {
        continue;
      }
      if (_canRemoveQuestion(selected, outgoing, incoming, minimumByActivity)) {
        return index;
      }
    }

    return null;
  }

  bool _canRemoveQuestion(
    List<QuizQuestion> selected,
    QuizQuestion outgoing,
    QuizQuestion incoming,
    Map<String, int> minimumByActivity,
  ) {
    if (outgoing.activityId == incoming.activityId) {
      return true;
    }

    final requiredForActivity = minimumByActivity[outgoing.activityId] ?? 0;
    return _selectedCountForActivity(selected, outgoing.activityId) >
        requiredForActivity;
  }

  void _addQuestion(
    List<QuizQuestion> selected,
    Set<String> selectedIds,
    QuizQuestion question,
  ) {
    selected.add(question);
    selectedIds.add(question.id);
  }

  void _replaceQuestion(
    List<QuizQuestion> selected,
    Set<String> selectedIds,
    int outgoingIndex,
    QuizQuestion incoming,
  ) {
    selectedIds.remove(selected[outgoingIndex].id);
    selected[outgoingIndex] = incoming;
    selectedIds.add(incoming.id);
  }

  void _validateSelection(List<QuizQuestion> selected, FinalExamConfig exam) {
    final selectedIds = selected.map((question) => question.id).toSet();
    if (selected.length != exam.questionCount ||
        selectedIds.length != exam.questionCount ||
        selected.any((question) => question.categoryId != exam.categoryId)) {
      throw StateError('Invalid balanced exam question selection.');
    }
  }

  int _selectedCountForActivity(
    List<QuizQuestion> selected,
    String activityId,
  ) {
    return _selectedCountBy(
      selected,
      (question) => question.activityId == activityId,
    );
  }

  int _selectedCountBy(
    List<QuizQuestion> selected,
    bool Function(QuizQuestion question) test,
  ) {
    return selected.where(test).length;
  }

  Map<K, List<QuizQuestion>> _groupBy<K>(
    List<QuizQuestion> questions,
    K Function(QuizQuestion question) keyOf,
  ) {
    final grouped = <K, List<QuizQuestion>>{};
    for (final question in questions) {
      grouped
          .putIfAbsent(keyOf(question), () => <QuizQuestion>[])
          .add(question);
    }
    return grouped;
  }
}
