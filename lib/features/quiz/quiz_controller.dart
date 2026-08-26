import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../data/models/quiz_question.dart';
import '../../data/models/quiz_result.dart';

typedef QuizShuffle = void Function<T>(List<T> items);

class QuizController extends ChangeNotifier {
  QuizController({
    required List<QuizQuestion> questions,
    bool shuffleQuestions = false,
    bool shuffleOptions = false,
    math.Random? random,
    QuizShuffle? shuffle,
  }) : _sourceQuestions = List<QuizQuestion>.unmodifiable(questions),
       _shuffleQuestions = shuffleQuestions,
       _shuffleOptions = shuffleOptions,
       _shuffle = shuffle ?? _randomShuffle(random) {
    if (_sourceQuestions.isEmpty) {
      throw ArgumentError('QuizController requires at least one question.');
    }
    _questions = _prepareQuestions();
  }

  final List<QuizQuestion> _sourceQuestions;
  final bool _shuffleQuestions;
  final bool _shuffleOptions;
  final QuizShuffle _shuffle;
  late List<QuizQuestion> _questions;

  int _currentIndex = 0;
  String? _selectedOptionId;
  String _writtenAnswer = '';
  bool _isAnswerConfirmed = false;
  bool? _isCurrentAnswerCorrect;
  int _correctAnswers = 0;
  bool _isFinished = false;
  QuizResult? _result;

  int get totalQuestions => _questions.length;

  int get currentIndex => _currentIndex;

  int get currentQuestionNumber => _currentIndex + 1;

  QuizQuestion get _currentQuestion => _questions[_currentIndex];

  String get currentQuestionId => _currentQuestion.id;

  QuestionType get currentQuestionType => _currentQuestion.type;

  String get currentStatement => _currentQuestion.statement;

  List<QuizOption> get currentOptions => _currentQuestion.options;

  String get currentCorrectAnswerText {
    if (_currentQuestion.type == QuestionType.fillBlank) {
      return _currentQuestion.correctAnswer;
    }

    return _currentQuestion.options
        .firstWhere((option) => option.id == _currentQuestion.correctAnswer)
        .text;
  }

  String? get selectedOptionId => _selectedOptionId;

  String get writtenAnswer => _writtenAnswer;

  bool get isAnswerConfirmed => _isAnswerConfirmed;

  bool? get isCurrentAnswerCorrect => _isCurrentAnswerCorrect;

  int get correctAnswers => _correctAnswers;

  bool get isFinished => _isFinished;

  bool get isLastQuestion => _currentIndex == totalQuestions - 1;

  String? get currentFeedback {
    if (!_isAnswerConfirmed) {
      return null;
    }

    return _currentQuestion.feedback;
  }

  int get answeredQuestions {
    if (_isFinished || _isAnswerConfirmed) {
      return _currentIndex + 1;
    }

    return _currentIndex;
  }

  double get progress => currentQuestionNumber / totalQuestions;

  bool get canSubmitAnswer {
    if (_isAnswerConfirmed || _isFinished) {
      return false;
    }

    return switch (_currentQuestion.type) {
      QuestionType.multipleChoice ||
      QuestionType.trueFalse => _selectedOptionId != null,
      QuestionType.fillBlank => _writtenAnswer.trim().isNotEmpty,
    };
  }

  QuizResult get quizResult {
    final result = _result;
    if (result == null) {
      throw StateError('Quiz result is only available after completion.');
    }

    return result;
  }

  void selectOption(String optionId) {
    if (_isAnswerConfirmed || _isFinished) {
      return;
    }
    if (_currentQuestion.type == QuestionType.fillBlank) {
      throw StateError('Fill blank questions do not accept option answers.');
    }
    if (!_currentQuestion.options.any((option) => option.id == optionId)) {
      throw ArgumentError('Unknown option id "$optionId".');
    }

    _selectedOptionId = _selectedOptionId == optionId ? null : optionId;
    notifyListeners();
  }

  void updateWrittenAnswer(String value) {
    if (_isAnswerConfirmed || _isFinished) {
      return;
    }
    if (_currentQuestion.type != QuestionType.fillBlank) {
      throw StateError('Choice questions do not accept written answers.');
    }

    _writtenAnswer = value;
    notifyListeners();
  }

  bool submitAnswer() {
    if (!canSubmitAnswer) {
      return false;
    }

    final answer = switch (_currentQuestion.type) {
      QuestionType.multipleChoice ||
      QuestionType.trueFalse => _selectedOptionId!,
      QuestionType.fillBlank => _writtenAnswer,
    };
    final isCorrect = _isCorrectAnswer(_currentQuestion, answer);

    _isAnswerConfirmed = true;
    _isCurrentAnswerCorrect = isCorrect;
    if (isCorrect) {
      _correctAnswers += 1;
    }
    if (isLastQuestion) {
      _finishQuiz();
    }

    notifyListeners();
    return true;
  }

  bool goToNextActivity() {
    if (!_isAnswerConfirmed || _isFinished) {
      return false;
    }

    _currentIndex += 1;
    _selectedOptionId = null;
    _writtenAnswer = '';
    _isAnswerConfirmed = false;
    _isCurrentAnswerCorrect = null;

    notifyListeners();
    return true;
  }

  void reset() {
    _questions = _prepareQuestions();
    _currentIndex = 0;
    _selectedOptionId = null;
    _writtenAnswer = '';
    _isAnswerConfirmed = false;
    _isCurrentAnswerCorrect = null;
    _correctAnswers = 0;
    _isFinished = false;
    _result = null;

    notifyListeners();
  }

  QuizResult generateResult() {
    if (!_isFinished) {
      throw StateError('Cannot generate a result before quiz completion.');
    }

    return quizResult;
  }

  bool _isCorrectAnswer(QuizQuestion question, String answer) {
    if (question.type != QuestionType.fillBlank) {
      return question.isCorrectAnswer(answer);
    }

    final normalizedAnswer = _normalizeFillBlankAnswer(answer);
    final acceptedAnswers = question.acceptedAnswers
        .map(_normalizeFillBlankAnswer)
        .toList(growable: false);
    final acceptedAnswerSet = acceptedAnswers.toSet();

    return acceptedAnswers.any((acceptedAnswer) {
      if (acceptedAnswer == normalizedAnswer) {
        return true;
      }

      final unaccentedAcceptedAnswer = _removeSpanishDiacritics(acceptedAnswer);
      return acceptedAnswerSet.contains(unaccentedAcceptedAnswer) &&
          unaccentedAcceptedAnswer ==
              _removeSpanishDiacritics(normalizedAnswer);
    });
  }

  String _normalizeFillBlankAnswer(String value) {
    return value.trim().toLowerCase();
  }

  String _removeSpanishDiacritics(String value) {
    return value
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n');
  }

  void _finishQuiz() {
    _isFinished = true;
    _result = QuizResult.fromScore(
      correctAnswers: _correctAnswers,
      totalQuestions: totalQuestions,
    );
  }

  List<QuizQuestion> _prepareQuestions() {
    final questions = _sourceQuestions
        .map((question) {
          return _shuffleOptions ? _withPreparedOptions(question) : question;
        })
        .toList(growable: false);

    if (_shuffleQuestions) {
      _shuffle(questions);
    }

    return List<QuizQuestion>.unmodifiable(questions);
  }

  QuizQuestion _withPreparedOptions(QuizQuestion question) {
    if (question.type != QuestionType.multipleChoice) {
      return question;
    }

    final options = question.options.toList(growable: false);
    _shuffle(options);

    return QuizQuestion(
      id: question.id,
      categoryId: question.categoryId,
      activityId: question.activityId,
      type: question.type,
      statement: question.statement,
      options: List<QuizOption>.unmodifiable(options),
      correctAnswer: question.correctAnswer,
      acceptedAnswers: question.acceptedAnswers,
      feedback: question.feedback,
      capacity: question.capacity,
      difficulty: question.difficulty,
    );
  }

  static QuizShuffle _randomShuffle(math.Random? random) {
    final selectedRandom = random ?? math.Random();

    return <T>(List<T> items) {
      items.shuffle(selectedRandom);
    };
  }
}
