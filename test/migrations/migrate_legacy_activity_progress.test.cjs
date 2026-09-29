const assert = require('node:assert/strict');
const test = require('node:test');
const {
  scoreSetsFromLegacy,
  planDocument,
} = require('../../tool/migrations/migrate_legacy_activity_progress.cjs');

const activityId = 'accounts_auth_activity_01';
const questionIds = Array.from({ length: 10 }, (_, index) =>
  `q${String(index + 1).padStart(2, '0')}`);

function score(questionId, points, attempt) {
  return { mapValue: { fields: {
    questionId: { stringValue: questionId },
    pointsAwarded: { integerValue: String(points) },
    awardedAttempt: attempt == null
      ? { nullValue: null } : { integerValue: String(attempt) },
  } } };
}

function legacyDocument(values, attempts = 3) {
  const questionScores = Object.fromEntries(questionIds.map((id, index) =>
    [id, score(id, values[index][0], values[index][1])]));
  const total = values.reduce((sum, [points]) => sum + points, 0);
  return {
    name: `projects/demo/databases/(default)/documents/users/synthetic/categoryProgress/account_protection_authentication/activities/${activityId}`,
    fields: {
      activityId: { stringValue: activityId },
      status: { stringValue: 'completed' },
      attemptCount: { integerValue: String(attempts) },
      activityPoints: { integerValue: String(total) },
      questionScores: { mapValue: { fields: questionScores } },
      bestCorrectAnswers: { integerValue: '8' },
      bestTotalQuestions: { integerValue: '10' },
      bestPercentage: { integerValue: '80' },
      lastAttemptAt: { timestampValue: '2026-09-01T00:00:00Z' },
      completedAt: { timestampValue: '2026-09-01T00:00:00Z' },
      updatedAt: { timestampValue: '2026-09-01T00:00:00Z' },
    },
  };
}

test('converts 10, 5, 1 and 0 point questions without double award', () => {
  const values = [[10, 1], [5, 2], [1, 3], [0, null],
    [10, 1], [5, 2], [1, 3], [0, null], [10, 1], [0, null]];
  const document = legacyDocument(values);
  const plan = planDocument(document, questionIds);
  assert.equal(plan.points, 42);
  assert.equal(plan.attempts, 3);
  assert.deepEqual(plan.fields.scoredAt10QuestionIds.arrayValue.values.map(v => v.stringValue),
    ['q01', 'q05', 'q09']);
  assert.deepEqual(plan.fields.scoredAt5QuestionIds.arrayValue.values.map(v => v.stringValue),
    ['q02', 'q06']);
  assert.deepEqual(plan.fields.scoredAt1QuestionIds.arrayValue.values.map(v => v.stringValue),
    ['q03', 'q07']);
  assert.equal(plan.fields.questionScores, undefined);
  assert.deepEqual(plan.fields.activeAttempt, { nullValue: null });
  assert.deepEqual(plan.fields.attemptCount, document.fields.attemptCount);
  assert.deepEqual(plan.fields.activityPoints, document.fields.activityPoints);
});

test('already migrated document is an idempotent no-op', () => {
  const document = legacyDocument(questionIds.map(() => [10, 1]), 2);
  const first = planDocument(document, questionIds);
  const second = planDocument({ ...document, fields: first.fields }, questionIds);
  assert.equal(second.legacy, false);
  assert.deepEqual(second.fields, first.fields);
  assert.equal(second.attempts, 2);
});

test('already migrated document stays a no-op after a new reservation', () => {
  const document = legacyDocument(questionIds.map(() => [10, 1]), 2);
  const migrated = planDocument(document, questionIds);
  migrated.fields.status = { stringValue: 'inProgress' };
  migrated.fields.attemptCount = { integerValue: '3' };
  migrated.fields.activeAttempt = { mapValue: { fields: {
    attemptId: { stringValue: 'synthetic-attempt' },
    attemptNumber: { integerValue: '3' },
    reservedAt: { timestampValue: '2026-09-03T00:00:00Z' },
    pointValue: { integerValue: '1' },
  } } };
  const second = planDocument({ ...document, fields: migrated.fields }, questionIds);
  assert.equal(second.legacy, false);
  assert.equal(second.attempts, 3);
  assert.deepEqual(second.fields, migrated.fields);
});

test('rejects inconsistent score history and attempt counts', () => {
  const values = questionIds.map(() => [10, 1]);
  const document = legacyDocument(values);
  document.fields.activityPoints.integerValue = '99';
  assert.throws(() => planDocument(document, questionIds));
  document.fields.activityPoints.integerValue = '100';
  document.fields.attemptCount.integerValue = '0';
  assert.throws(() => planDocument(document, questionIds));
  document.fields.attemptCount.integerValue = '1';
  document.fields.questionScores.mapValue.fields.q01 = score('q01', 5, 2);
  assert.throws(() => planDocument(document, questionIds));
});

test('zero point answers stay out of every awarded set', () => {
  const entries = Object.fromEntries(questionIds.map((id, index) =>
    [id, score(id, index === 0 ? 10 : 0, index === 0 ? 1 : null)]));
  const { sets, total } = scoreSetsFromLegacy({ mapValue: { fields: entries } },
    questionIds, 2);
  assert.deepEqual(sets[10], ['q01']);
  assert.deepEqual(sets[5], []);
  assert.deepEqual(sets[1], []);
  assert.equal(total, 10);
});
