#!/usr/bin/env node
// Creates only missing activity answer keys from the current canonical seed JSON.
const assert = require('node:assert/strict');
const { execFileSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');
const { isDeepStrictEqual } = require('node:util');

const projectId = 'yomecuido-1dc1a';
const root = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents`;
const contentDirectory = path.join(__dirname, '../seed/content');

function readList(filename, listKey) {
  const decoded = JSON.parse(fs.readFileSync(
    path.join(contentDirectory, filename), 'utf8'));
  const items = Array.isArray(decoded) ? decoded : decoded[listKey];
  assert.ok(Array.isArray(items), `Invalid ${filename} list`);
  return items;
}

function ensureUnique(values, label) {
  assert.equal(new Set(values).size, values.length, `Duplicate ${label}`);
}

function localInventory() {
  const files = fs.readdirSync(contentDirectory);
  const categories = readList('categories.json', 'categories');
  const activities = files.filter(file => file.endsWith('_activities.json'))
    .flatMap(file => readList(file, 'activities'));
  const questions = files.filter(file => file.endsWith('_questions.json'))
    .flatMap(file => readList(file, 'questions'));
  assert.equal(categories.length, 16, 'Expected 16 canonical categories');
  assert.equal(activities.length, 96, 'Expected 96 canonical activities');
  assert.equal(questions.length, 960, 'Expected 960 canonical questions');
  ensureUnique(categories.map(category => category.id), 'category ID');
  ensureUnique(activities.map(activity => activity.id), 'activity ID');
  ensureUnique(questions.map(question => question.id), 'question ID');
  const byCategory = new Map(categories.map(category => [category.id, []]));
  const byActivity = new Map(activities.map(activity => [activity.id, []]));
  for (const activity of activities) {
    assert.ok(byCategory.has(activity.categoryId), 'Activity has unknown category');
    byCategory.get(activity.categoryId).push(activity);
  }
  for (const [categoryId, entries] of byCategory) {
    assert.equal(entries.length, 6, `Expected 6 activities in ${categoryId}`);
  }
  for (const question of questions) {
    const activity = activities.find(item => item.id === question.activityId);
    assert.ok(activity && activity.categoryId === question.categoryId,
      'Question references unknown activity');
    assert.ok(typeof question.correctAnswer === 'string' && question.correctAnswer,
      'Canonical question answer missing');
    if (question.type === 'fillBlank') {
      assert.equal(question.options.length, 0, 'Fill blank has options');
      assert.ok(question.acceptedAnswers.includes(question.correctAnswer),
        'Canonical fill blank variant missing');
    } else {
      assert.ok(question.options.some(option => option.id === question.correctAnswer),
        'Canonical answer is not an option');
    }
    byActivity.get(question.activityId).push(question);
  }
  const keys = new Map();
  for (const activity of activities) {
    const entries = byActivity.get(activity.id).sort((a, b) =>
      a.id < b.id ? -1 : a.id > b.id ? 1 : 0);
    assert.equal(entries.length, 10, `Expected 10 questions for ${activity.id}`);
    ensureUnique(entries.map(question => question.id), 'activity question ID');
    const key = {
      categoryId: activity.categoryId,
      activityId: activity.id,
      questionIds: entries.map(question => question.id),
      correctAnswersByQuestionId: Object.fromEntries(entries.map(question =>
        [question.id, question.correctAnswer])),
      acceptedAnswersByQuestionId: Object.fromEntries(entries
        .filter(question => question.type === 'fillBlank')
        .map(question => [question.id, question.acceptedAnswers
          .map(answer => answer.trim().toLowerCase())])),
      fillBlankQuestionIds: entries.filter(question => question.type === 'fillBlank')
        .map(question => question.id),
    };
    keys.set(`categories/${activity.categoryId}/answerKeys/${activity.id}`,
      { key, questions: entries });
  }
  assert.equal(keys.size, 96, 'Expected 96 generated answer key paths');
  return { categories, activities, questions, keys };
}

function firebaseCliAuth() {
  const candidates = [path.join(path.dirname(process.execPath),
    'node_modules', 'firebase-tools', 'lib', 'auth.js')];
  try {
    const npm = process.platform === 'win32' ? 'npm.cmd' : 'npm';
    const globalRoot = execFileSync(npm, ['root', '-g'],
      { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim();
    candidates.push(path.join(globalRoot, 'firebase-tools', 'lib', 'auth.js'));
  } catch (_) { /* An adjacent installation may still be available. */ }
  const authPath = candidates.find(candidate => fs.existsSync(candidate));
  assert.ok(authPath, 'Firebase CLI installation not found');
  return require(authPath);
}

async function accessToken() {
  const auth = firebaseCliAuth();
  const account = auth.getProjectDefaultAccount(process.cwd());
  assert.ok(account?.tokens?.refresh_token, 'Firebase CLI login required');
  const token = await auth.getAccessToken(account.tokens.refresh_token,
    ['https://www.googleapis.com/auth/cloud-platform']);
  assert.ok(token?.access_token, 'Firebase CLI access token unavailable');
  return token.access_token;
}

async function request(token, suffix, options = {}) {
  const response = await fetch(`${root}${suffix}`, {
    ...options,
    headers: {
      Authorization: `Bearer ${token}`,
      ...(options.body ? { 'Content-Type': 'application/json' } : {}),
    },
  });
  if (!response.ok) {
    const problem = await response.json().catch(() => ({}));
    const reason = problem.error?.message ?? '';
    throw new Error(`Firestore HTTP ${response.status} ${problem.error?.status ?? ''}: ${reason.slice(0, 200)}`);
  }
  return response.json();
}

async function list(token, collectionPath) {
  const documents = [];
  let pageToken;
  do {
    const parameters = new URLSearchParams({ pageSize: '1000' });
    if (pageToken) parameters.set('pageToken', pageToken);
    const page = await request(token, `/${collectionPath}?${parameters}`);
    documents.push(...(page.documents ?? []));
    pageToken = page.nextPageToken;
  } while (pageToken);
  return documents;
}

function id(document) {
  return document.name.split('/').at(-1);
}

function value(field) {
  if ('stringValue' in field) return field.stringValue;
  if ('arrayValue' in field) return (field.arrayValue.values ?? []).map(value);
  if ('mapValue' in field) return Object.fromEntries(Object.entries(
    field.mapValue.fields ?? {}).map(([key, item]) => [key, value(item)]));
  throw new Error('Unexpected educational field type');
}

function data(document) {
  return Object.fromEntries(Object.entries(document.fields ?? {})
    .map(([key, field]) => [key, value(field)]));
}

function fieldValue(item) {
  if (typeof item === 'string') return { stringValue: item };
  if (Array.isArray(item)) return {
    arrayValue: { values: item.map(fieldValue) },
  };
  if (item && typeof item === 'object') return {
    mapValue: { fields: Object.fromEntries(Object.entries(item)
      .map(([key, entry]) => [key, fieldValue(entry)])) },
  };
  throw new Error('Invalid generated answer key field type');
}

async function remoteInventory(token, local) {
  const categories = await list(token, 'categories');
  const localCategoryIds = local.categories.map(category => category.id).sort();
  const remoteCategoryIds = categories.map(id).sort();
  assert.ok(isDeepStrictEqual(remoteCategoryIds, localCategoryIds),
    'Local and remote category IDs differ');
  const missing = [];
  let remoteActivities = 0;
  let remoteQuestions = 0;
  let remoteKeys = 0;
  for (const categoryId of localCategoryIds) {
    const base = `categories/${categoryId}`;
    const [activities, questions, keys] = await Promise.all([
      list(token, `${base}/activities`),
      list(token, `${base}/questions`),
      list(token, `${base}/answerKeys`),
    ]);
    remoteActivities += activities.length;
    remoteQuestions += questions.length;
    remoteKeys += keys.length;
    const localActivityIds = local.activities.filter(activity =>
      activity.categoryId === categoryId).map(activity => activity.id).sort();
    const remoteActivityIds = activities.map(id).sort();
    ensureUnique(remoteActivityIds, 'remote activity ID');
    assert.ok(isDeepStrictEqual(remoteActivityIds, localActivityIds),
      `Local and remote activity IDs differ in ${categoryId}`);
    const localQuestions = local.questions.filter(question =>
      question.categoryId === categoryId);
    const localQuestionById = new Map(localQuestions.map(question =>
      [question.id, question]));
    const remoteQuestionIds = questions.map(id).sort();
    ensureUnique(remoteQuestionIds, 'remote question ID');
    assert.ok(isDeepStrictEqual(remoteQuestionIds,
      localQuestions.map(question => question.id).sort()),
    `Local and remote question IDs differ in ${categoryId}`);
    for (const document of questions) {
      const question = data(document);
      const canonical = localQuestionById.get(id(document));
      assert.ok(question.id === canonical.id &&
        question.categoryId === canonical.categoryId &&
        question.activityId === canonical.activityId &&
        question.type === canonical.type &&
        question.correctAnswer === canonical.correctAnswer &&
        isDeepStrictEqual(question.acceptedAnswers, canonical.acceptedAnswers),
      `Remote question differs from canonical content in ${categoryId}`);
    }
    const existingKeys = new Map(keys.map(document => [id(document), document]));
    ensureUnique([...existingKeys.keys()], 'remote answer key ID');
    for (const activityId of remoteActivityIds) {
      const path = `${base}/answerKeys/${activityId}`;
      const generated = local.keys.get(path).key;
      const existing = existingKeys.get(activityId);
      if (!existing) missing.push(path);
      else assert.ok(isDeepStrictEqual(data(existing), generated),
        `Existing answer key differs from canonical content in ${categoryId}`);
    }
  }
  assert.equal(remoteActivities, 96, 'Expected 96 remote activities');
  assert.equal(remoteQuestions, 960, 'Expected 960 remote questions');
  assert.equal(missing.length + (remoteKeys), 96,
    'Unexpected answer key inventory; check for extra keys');
  return { categories: categories.length, activities: remoteActivities,
    questions: remoteQuestions, keys: remoteKeys, missing };
}

async function main() {
  const flags = process.argv.slice(2);
  assert.ok(flags.length === 1 && ['--dry-run', '--apply'].includes(flags[0]),
    'Usage: node tool/migrations/backfill_activity_answer_keys.cjs --dry-run|--apply');
  const local = localInventory();
  const token = await accessToken();
  const before = await remoteInventory(token, local);
  console.log(`Inventory: categories=${before.categories} localActivities=${local.activities.length} remoteActivities=${before.activities}`);
  console.log(`Validated question references: ${before.questions}/960`);
  console.log(`Missing activity answer keys: ${before.missing.length}; writes required: ${before.missing.length}`);
  console.log('Planned public content writes: 0; user/progress/ranking writes: 0');
  if (flags[0] === '--dry-run' || before.missing.length === 0) return;
  const writes = before.missing.map(documentPath => ({
    update: {
      name: `projects/${projectId}/databases/(default)/documents/${documentPath}`,
      fields: Object.fromEntries(Object.entries(local.keys.get(documentPath).key)
        .map(([name, item]) => [name, fieldValue(item)])),
    },
    currentDocument: { exists: false },
  }));
  const result = await request(token, ':commit', {
    method: 'POST',
    body: JSON.stringify({ writes }),
  });
  assert.equal(result.writeResults?.length, writes.length,
    'Unexpected write result count');
  const after = await remoteInventory(token, local);
  assert.equal(after.keys, 96, 'Expected 96 remote activity answer keys');
  assert.equal(after.missing.length, 0, 'Activity answer keys remain missing');
  console.log(`Created activity answer keys: ${writes.length}; verified: 96/96`);
}

if (require.main === module) {
  main().catch(error => {
    console.error(`Backfill aborted: ${error.message}`);
    process.exitCode = 1;
  });
}

module.exports = { localInventory, fieldValue };
