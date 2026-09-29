const assert = require('node:assert/strict');
const test = require('node:test');
const { localInventory, fieldValue } = require('../../tool/migrations/backfill_activity_answer_keys.cjs');

test('canonical inventory produces one protected key for every ten-question activity', () => {
  const inventory = localInventory();
  assert.equal(inventory.categories.length, 16);
  assert.equal(inventory.activities.length, 96);
  assert.equal(inventory.questions.length, 960);
  assert.equal(inventory.keys.size, 96);
  for (const [path, { key, questions }] of inventory.keys) {
    assert.equal(path, `categories/${key.categoryId}/answerKeys/${key.activityId}`);
    assert.equal(key.questionIds.length, 10);
    assert.equal(new Set(key.questionIds).size, 10);
    assert.equal(Object.keys(key.correctAnswersByQuestionId).length, 10);
    assert.ok(key.questionIds.every(id => questions.some(question => question.id === id)));
    assert.ok(questions.every(question =>
      key.correctAnswersByQuestionId[question.id] === question.correctAnswer));
  }
});

test('Firestore encoding preserves the protected key field structure', () => {
  const encoded = fieldValue({
    questionIds: ['first', 'second'],
    acceptedAnswersByQuestionId: { second: ['variant'] },
  });
  assert.ok(encoded.mapValue.fields.questionIds.arrayValue);
  assert.ok(encoded.mapValue.fields.acceptedAnswersByQuestionId.mapValue);
  assert.equal(encoded.mapValue.fields.questionIds.arrayValue.values.length, 2);
});
