import 'package:flutter_test/flutter_test.dart';
import 'package:demo_yomecuido/data/models/category_progress.dart';
import 'package:demo_yomecuido/data/models/scored_question_sets.dart';

void main() {
  test(
    'legacy scores convert deterministically without zero-point entries',
    () {
      const legacy = {
        'q01': QuestionScoreRecord(
          questionId: 'q01',
          pointsAwarded: 10,
          awardedAttempt: 1,
        ),
        'q02': QuestionScoreRecord(
          questionId: 'q02',
          pointsAwarded: 5,
          awardedAttempt: 2,
        ),
        'q03': QuestionScoreRecord(
          questionId: 'q03',
          pointsAwarded: 1,
          awardedAttempt: 3,
        ),
        'q04': QuestionScoreRecord.notAwarded(questionId: 'q04'),
      };
      final sets = ScoredQuestionSets.fromLegacy(legacy);
      expect(sets.toFirestoreFields(), {
        'scoredAt10QuestionIds': ['q01'],
        'scoredAt5QuestionIds': ['q02'],
        'scoredAt1QuestionIds': ['q03'],
      });
      expect(
        sets.toLocalQuestionScores().keys,
        containsAll(['q01', 'q02', 'q03']),
      );
      expect(sets.toLocalQuestionScores().containsKey('q04'), isFalse);
    },
  );

  test('one question cannot appear in two sets', () {
    expect(
      () => ScoredQuestionSets(
        scoredAt10QuestionIds: ['q01'],
        scoredAt5QuestionIds: ['q01'],
        scoredAt1QuestionIds: const [],
      ),
      throwsFormatException,
    );
  });
}
