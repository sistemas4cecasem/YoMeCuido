import 'package:flutter/foundation.dart';

import '../../data/models/quiz_question.dart';
import '../../data/models/quiz_result.dart';

class QuizController extends ChangeNotifier {
  QuizController({required List<QuizQuestion> questions})
    : _questions = List<QuizQuestion>.unmodifiable(questions) {
    if (_questions.length != expectedQuestionCount) {
      throw ArgumentError(
        'QuizController requires exactly $expectedQuestionCount questions.',
      );
    }
  }

  static const expectedQuestionCount = 12;

  final List<QuizQuestion> _questions;

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

  int get currentActivityNumber => _currentIndex + 1;

  QuizQuestion get _currentQuestion => _questions[_currentIndex];

  String get currentQuestionId => _currentQuestion.id;

  QuestionType get currentQuestionType => _currentQuestion.type;

  String get currentStatement => _currentQuestion.statement;

  List<QuizOption> get currentOptions => _currentQuestion.options;

  String? get selectedOptionId => _selectedOptionId;

  String get writtenAnswer => _writtenAnswer;

  bool get isAnswerConfirmed => _isAnswerConfirmed;

  bool? get isCurrentAnswerCorrect => _isCurrentAnswerCorrect;

  int get correctAnswers => _correctAnswers;

  bool get isFinished => _isFinished;

  bool get isLastActivity => _currentIndex == totalQuestions - 1;

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

  double get progress => currentActivityNumber / totalQuestions;

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

    _selectedOptionId = optionId;
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
    if (isLastActivity) {
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
}
