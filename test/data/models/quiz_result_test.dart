import 'package:demo_yomecuido/data/models/quiz_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QuizResult', () {
    test('classifies equivalent eighty percent scores with the same level', () {
      final results = <QuizResult>[
        QuizResult.fromScore(correctAnswers: 8, totalQuestions: 10),
        QuizResult.fromScore(correctAnswers: 12, totalQuestions: 15),
        QuizResult.fromScore(correctAnswers: 4, totalQuestions: 5),
      ];

      expect(results.map((result) => result.percentage), everyElement(80));
      expect(
        results.map((result) => result.level),
        everyElement(QuizResultLevel.high),
      );
      expect(
        results.map((result) => result.closingMessage).toSet(),
        hasLength(1),
      );
    });

    test('classifies perfect scores consistently across totals', () {
      final tenQuestions = QuizResult.fromScore(
        correctAnswers: 10,
        totalQuestions: 10,
      );
      final fifteenQuestions = QuizResult.fromScore(
        correctAnswers: 15,
        totalQuestions: 15,
      );

      expect(tenQuestions.percentage, 100);
      expect(fifteenQuestions.percentage, 100);
      expect(tenQuestions.level, QuizResultLevel.high);
      expect(fifteenQuestions.level, tenQuestions.level);
    });

    test('supports minimum scores without division errors', () {
      final tenQuestions = QuizResult.fromScore(
        correctAnswers: 0,
        totalQuestions: 10,
      );
      final fifteenQuestions = QuizResult.fromScore(
        correctAnswers: 0,
        totalQuestions: 15,
      );
      final emptyResult = QuizResult.fromScore(
        correctAnswers: 0,
        totalQuestions: 0,
      );

      expect(tenQuestions.percentage, 0);
      expect(fifteenQuestions.percentage, 0);
      expect(emptyResult.percentage, 0);
      expect(emptyResult.progressFraction, 0);
      expect(emptyResult.level, QuizResultLevel.low);
    });

    test('calculates percentages for different question totals', () {
      final totals = <QuizResult>[
        QuizResult.fromScore(correctAnswers: 3, totalQuestions: 5),
        QuizResult.fromScore(correctAnswers: 8, totalQuestions: 10),
        QuizResult.fromScore(correctAnswers: 9, totalQuestions: 12),
        QuizResult.fromScore(correctAnswers: 12, totalQuestions: 15),
      ];

      expect(totals.map((result) => result.percentage), <int>[60, 80, 75, 80]);
      expect(totals.map((result) => result.totalQuestions), <int>[
        5,
        10,
        12,
        15,
      ]);
    });

    test('rounds fractional percentages consistently', () {
      final sevenOfTen = QuizResult.fromScore(
        correctAnswers: 7,
        totalQuestions: 10,
      );
      final elevenOfFifteen = QuizResult.fromScore(
        correctAnswers: 11,
        totalQuestions: 15,
      );

      expect(sevenOfTen.percentage, 70);
      expect(elevenOfFifteen.percentage, 73);
      expect(sevenOfTen.level, QuizResultLevel.medium);
      expect(elevenOfFifteen.level, QuizResultLevel.medium);
    });

    test('uses exact percentage boundaries for each level', () {
      final lowBoundary = QuizResult.fromScore(
        correctAnswers: 59,
        totalQuestions: 100,
      );
      final mediumBoundary = QuizResult.fromScore(
        correctAnswers: 60,
        totalQuestions: 100,
      );
      final highBoundary = QuizResult.fromScore(
        correctAnswers: 80,
        totalQuestions: 100,
      );

      expect(lowBoundary.level, QuizResultLevel.low);
      expect(mediumBoundary.level, QuizResultLevel.medium);
      expect(highBoundary.level, QuizResultLevel.high);
    });

    test('keeps absolute values available for display', () {
      final result = QuizResult.fromScore(
        correctAnswers: 9,
        totalQuestions: 12,
      );

      expect(result.correctAnswers, 9);
      expect(result.totalQuestions, 12);
      expect(result.percentage, 75);
      expect(result.level, QuizResultLevel.medium);
    });

    test('rejects invalid score ranges', () {
      expect(
        () => QuizResult.fromScore(correctAnswers: 1, totalQuestions: 0),
        throwsArgumentError,
      );
      expect(
        () => QuizResult.fromScore(correctAnswers: -1, totalQuestions: 10),
        throwsArgumentError,
      );
      expect(
        () => QuizResult.fromScore(correctAnswers: 0, totalQuestions: -1),
        throwsArgumentError,
      );
    });
  });
}
