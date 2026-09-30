import 'package:demo_yomecuido/data/models/category_progress.dart';
import 'package:demo_yomecuido/data/models/pending_quiz_attempt.dart';
import 'package:demo_yomecuido/data/repositories/pending_quiz_attempt_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('account deletion removes pending only for its uid', () async {
    final previous = SharedPreferencesAsyncPlatform.instance;
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    addTearDown(() => SharedPreferencesAsyncPlatform.instance = previous);
    final repository = SharedPreferencesPendingQuizAttemptRepository(
      preferences: SharedPreferencesAsync(),
    );
    await repository.upsert(_attempt('uid-a', 'attempt-a'));
    await repository.upsert(_attempt('uid-b', 'attempt-b'));
    await repository.removeForUid('uid-a');
    expect((await repository.loadAll()).map((a) => a.uid), ['uid-b']);
    await repository.removeForUid('uid-a');
    expect((await repository.loadAll()).map((a) => a.uid), ['uid-b']);
  });

  for (final raw in [
    '{"uid":"private"}',
    '[42]',
    '[{"uid":"private","answers":[]}]',
  ]) {
    test('invalid pending shape preserves raw storage: $raw', () async {
      final previous = SharedPreferencesAsyncPlatform.instance;
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      addTearDown(() => SharedPreferencesAsyncPlatform.instance = previous);
      final preferences = SharedPreferencesAsync();
      const key = 'pending_quiz_attempts_v1';
      await preferences.setString(key, raw);
      final repository = SharedPreferencesPendingQuizAttemptRepository(
        preferences: preferences,
      );
      await expectLater(repository.loadAll(), throwsFormatException);
      await expectLater(
        repository.upsert(_attempt('uid-a', 'attempt-a')),
        throwsFormatException,
      );
      await expectLater(repository.remove('attempt-a'), throwsFormatException);
      await expectLater(
        repository.removeForUid('uid-a'),
        throwsFormatException,
      );
      expect(await preferences.getString(key), raw);
    });
  }
}

PendingQuizAttempt _attempt(String uid, String id) {
  final now = DateTime.utc(2026, 9, 29);
  return PendingQuizAttempt(
    uid: uid,
    attemptId: id,
    type: QuizAttemptType.activity,
    categoryId: 'category',
    lessonId: 'lesson',
    activityId: 'activity',
    examId: null,
    questionIds: const ['question'],
    answers: [
      CategoryProgressAnswer(
        questionId: 'question',
        answer: 'option',
        isCorrect: true,
        answeredAt: now,
      ),
    ],
    correctAnswers: 1,
    totalQuestions: 1,
    percentage: 100,
    totalActivities: 1,
    startedAt: now,
    completedAt: now,
  );
}
