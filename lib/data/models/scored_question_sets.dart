import 'activity_scoring_policy.dart';
import 'category_progress.dart';

/// Compact authoritative score state. A zero-point answer is absent from all sets.
class ScoredQuestionSets {
  ScoredQuestionSets({
    required Iterable<String> scoredAt10QuestionIds,
    required Iterable<String> scoredAt5QuestionIds,
    required Iterable<String> scoredAt1QuestionIds,
  }) : scoredAt10QuestionIds = Set.unmodifiable(scoredAt10QuestionIds),
       scoredAt5QuestionIds = Set.unmodifiable(scoredAt5QuestionIds),
       scoredAt1QuestionIds = Set.unmodifiable(scoredAt1QuestionIds) {
    final all = <String>{
      ...this.scoredAt10QuestionIds,
      ...this.scoredAt5QuestionIds,
      ...this.scoredAt1QuestionIds,
    };
    if (all.length !=
        this.scoredAt10QuestionIds.length +
            this.scoredAt5QuestionIds.length +
            this.scoredAt1QuestionIds.length) {
      throw const FormatException(
        'A question cannot belong to two score sets.',
      );
    }
  }

  factory ScoredQuestionSets.fromLegacy(
    Map<String, QuestionScoreRecord> questionScores,
  ) {
    final ten = <String>[];
    final five = <String>[];
    final one = <String>[];
    for (final entry in questionScores.entries) {
      switch (entry.value.pointsAwarded) {
        case ActivityScoringPolicy.firstAttemptPoints:
          ten.add(entry.key);
          break;
        case ActivityScoringPolicy.secondAttemptPoints:
          five.add(entry.key);
          break;
        case ActivityScoringPolicy.thirdAttemptPoints:
          one.add(entry.key);
          break;
        case 0:
          break;
        default:
          throw FormatException('Invalid legacy score for ${entry.key}.');
      }
    }
    return ScoredQuestionSets(
      scoredAt10QuestionIds: ten,
      scoredAt5QuestionIds: five,
      scoredAt1QuestionIds: one,
    );
  }

  final Set<String> scoredAt10QuestionIds;
  final Set<String> scoredAt5QuestionIds;
  final Set<String> scoredAt1QuestionIds;

  Map<String, Object> toFirestoreFields() => {
    'scoredAt10QuestionIds': scoredAt10QuestionIds.toList(),
    'scoredAt5QuestionIds': scoredAt5QuestionIds.toList(),
    'scoredAt1QuestionIds': scoredAt1QuestionIds.toList(),
  };

  Map<String, QuestionScoreRecord> toLocalQuestionScores() => {
    for (final id in scoredAt10QuestionIds)
      id: QuestionScoreRecord(
        questionId: id,
        pointsAwarded: 10,
        awardedAttempt: 1,
      ),
    for (final id in scoredAt5QuestionIds)
      id: QuestionScoreRecord(
        questionId: id,
        pointsAwarded: 5,
        awardedAttempt: 2,
      ),
    for (final id in scoredAt1QuestionIds)
      id: QuestionScoreRecord(
        questionId: id,
        pointsAwarded: 1,
        awardedAttempt: 3,
      ),
  };
}
