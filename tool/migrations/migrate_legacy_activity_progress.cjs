#!/usr/bin/env node
// One-time administrative migration for the six legacy account-protection activities.
const assert = require('node:assert/strict');
const { execFileSync } = require('node:child_process');
const crypto = require('node:crypto');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const projectId = 'yomecuido-1dc1a';
const categoryId = 'account_protection_authentication';
const expectedActivityIds = Array.from({ length: 6 }, (_, index) =>
  `accounts_auth_activity_0${index + 1}`);
const expectedTotalPoints = 560;
const root = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents`;

function integer(field, label) {
  assert.match(field?.integerValue ?? '', /^\d+$/, `Invalid ${label}`);
  return Number(field.integerValue);
}

function scoreSetsFromLegacy(questionScores, expectedQuestionIds, attemptCount) {
  const entries = questionScores?.mapValue?.fields;
  assert.ok(entries && typeof entries === 'object', 'Missing questionScores map');
  assert.deepEqual(Object.keys(entries).sort(), [...expectedQuestionIds].sort(),
    'Legacy question IDs differ from the approved content');
  const sets = { 10: [], 5: [], 1: [] };
  let total = 0;
  for (const [questionId, value] of Object.entries(entries)) {
    const fields = value.mapValue?.fields;
    assert.deepEqual(Object.keys(fields ?? {}).sort(),
      ['awardedAttempt', 'pointsAwarded', 'questionId'],
      `Invalid score fields for ${questionId}`);
    assert.equal(fields.questionId?.stringValue, questionId);
    const points = integer(fields.pointsAwarded, `${questionId}.pointsAwarded`);
    assert.ok([0, 1, 5, 10].includes(points), `Invalid points for ${questionId}`);
    if (points === 0) {
      assert.ok(fields.awardedAttempt?.nullValue === null,
        `Unawarded question ${questionId} has an attempt`);
    } else {
      const awardedAttempt = integer(fields.awardedAttempt,
        `${questionId}.awardedAttempt`);
      assert.equal(awardedAttempt, { 10: 1, 5: 2, 1: 3 }[points]);
      assert.ok(awardedAttempt <= attemptCount);
      sets[points].push(questionId);
    }
    total += points;
  }
  for (const ids of Object.values(sets)) ids.sort();
  return { sets, total };
}

function expectedQuestionsByActivity() {
  const questions = JSON.parse(fs.readFileSync(path.join(__dirname,
    '../seed/content/accounts_auth_questions.json'), 'utf8'));
  const result = new Map(expectedActivityIds.map(id => [id, []]));
  for (const question of questions) {
    assert.equal(question.categoryId, categoryId);
    assert.ok(result.has(question.activityId));
    result.get(question.activityId).push(question.id);
  }
  for (const [activityId, ids] of result) {
    assert.equal(ids.length, 10, `Expected ten questions for ${activityId}`);
    assert.equal(new Set(ids).size, 10);
  }
  return result;
}

function planDocument(document, expectedQuestionIds) {
  const fields = document.fields ?? {};
  const activityId = fields.activityId?.stringValue;
  assert.ok(expectedActivityIds.includes(activityId), 'Unexpected activity document');
  assert.ok(document.name.endsWith(`/activities/${activityId}`));
  if (!fields.questionScores) {
    assert.deepEqual(Object.keys(fields).sort(), [
      'activeAttempt', 'activityId', 'activityPoints', 'attemptCount',
      'bestCorrectAnswers', 'bestPercentage', 'bestTotalQuestions',
      'completedAt', 'lastAttemptAt', 'scoredAt10QuestionIds',
      'scoredAt1QuestionIds', 'scoredAt5QuestionIds', 'status', 'updatedAt',
    ].sort(), 'Already-migrated document has unexpected fields');
    const status = fields.status?.stringValue;
    assert.ok(['completed', 'inProgress'].includes(status),
      'Already-migrated activity has invalid status');
    if (status === 'completed') {
      assert.ok(fields.activeAttempt?.nullValue === null,
        'Completed activity has an active attempt');
    } else {
      const active = fields.activeAttempt?.mapValue?.fields;
      assert.ok(active?.attemptId?.stringValue && active.reservedAt?.timestampValue,
        'In-progress activity has no valid reservation');
      assert.equal(integer(active.attemptNumber, 'activeAttempt.attemptNumber'),
        integer(fields.attemptCount, 'attemptCount'));
      const count = integer(fields.attemptCount, 'attemptCount');
      assert.equal(integer(active.pointValue, 'activeAttempt.pointValue'),
        count === 1 ? 10 : count === 2 ? 5 : count === 3 ? 1 : 0);
    }
    const awarded = new Set();
    let scoredTotal = 0;
    for (const [score, field] of [[10, 'scoredAt10QuestionIds'],
      [5, 'scoredAt5QuestionIds'], [1, 'scoredAt1QuestionIds']]) {
      assert.ok(fields[field]?.arrayValue, `Missing ${field}`);
      for (const item of fields[field].arrayValue.values ?? []) {
        const id = item.stringValue;
        assert.ok(expectedQuestionIds.includes(id) && !awarded.has(id),
          `Invalid or duplicate awarded question in ${field}`);
        awarded.add(id);
        scoredTotal += score;
      }
    }
    assert.equal(scoredTotal, integer(fields.activityPoints, 'activityPoints'));
    return { activityId, legacy: false, fields, points: integer(fields.activityPoints,
      'activityPoints'), attempts: integer(fields.attemptCount, 'attemptCount') };
  }
  assert.deepEqual(Object.keys(fields).sort(), [
    'activityId', 'activityPoints', 'attemptCount', 'bestCorrectAnswers',
    'bestPercentage', 'bestTotalQuestions', 'completedAt', 'lastAttemptAt',
    'questionScores', 'status', 'updatedAt',
  ].sort(), 'Legacy document has unexpected fields');
  assert.equal(fields.status?.stringValue, 'completed');
  assert.ok(fields.completedAt?.timestampValue);
  assert.ok(fields.lastAttemptAt?.timestampValue);
  assert.ok(fields.updatedAt?.timestampValue);
  const attempts = integer(fields.attemptCount, 'attemptCount');
  assert.ok(attempts >= 1 && attempts <= 1000);
  const points = integer(fields.activityPoints, 'activityPoints');
  const { sets, total } = scoreSetsFromLegacy(fields.questionScores,
    expectedQuestionIds, attempts);
  assert.equal(total, points, `Points differ for ${activityId}`);
  const migrated = structuredClone(fields);
  delete migrated.questionScores;
  for (const [score, field] of [[10, 'scoredAt10QuestionIds'],
    [5, 'scoredAt5QuestionIds'], [1, 'scoredAt1QuestionIds']]) {
    migrated[field] = { arrayValue: { values: sets[score].map(id =>
      ({ stringValue: id })) } };
  }
  migrated.activeAttempt = { nullValue: null };
  return { activityId, legacy: true, fields: migrated, points, attempts };
}

function firebaseCliAuth() {
  const candidates = [
    path.join(path.dirname(process.execPath), 'node_modules', 'firebase-tools',
      'lib', 'auth.js'),
  ];
  try {
    const npm = process.platform === 'win32' ? 'npm.cmd' : 'npm';
    const globalRoot = execFileSync(npm, ['root', '-g'],
      { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim();
    candidates.push(path.join(globalRoot, 'firebase-tools', 'lib', 'auth.js'));
  } catch (_) { /* The adjacent global installation may still be available. */ }
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
  if (!response.ok) throw new Error(`Firestore HTTP ${response.status}`);
  return response.json();
}

async function readState(token, uid) {
  const user = `/users/${encodeURIComponent(uid)}`;
  const activityPath = `${user}/categoryProgress/${categoryId}/activities`;
  const [activitiesPage, progressPage, profile, leaderboard] = await Promise.all([
    request(token, `${activityPath}?pageSize=100`),
    request(token, `${user}/categoryProgress?pageSize=100`),
    request(token, user),
    request(token, `/leaderboard/${encodeURIComponent(uid)}`),
  ]);
  assert.ok(!activitiesPage.nextPageToken && !progressPage.nextPageToken,
    'Unexpected pagination');
  const activities = activitiesPage.documents ?? [];
  assert.deepEqual(activities.map(doc => doc.name.split('/').at(-1)).sort(),
    expectedActivityIds, 'Unexpected activity count or IDs');
  return {
    activities,
    aggregates: {
      profile: profile.fields,
      leaderboard: leaderboard.fields,
      progress: Object.fromEntries((progressPage.documents ?? []).map(doc =>
        [doc.name.split('/').at(-1), doc.fields])),
    },
  };
}

function planState(state) {
  const questions = expectedQuestionsByActivity();
  const plans = state.activities.map(doc => planDocument(doc,
    questions.get(doc.name.split('/').at(-1))));
  const legacyCount = plans.filter(plan => plan.legacy).length;
  assert.ok(legacyCount === 0 || legacyCount === 6,
    `Partial migration detected: ${legacyCount} legacy documents`);
  const points = plans.reduce((sum, plan) => sum + plan.points, 0);
  if (legacyCount === 6) assert.equal(points, expectedTotalPoints);
  assert.equal(integer(state.aggregates.profile.totalPoints,
    'profile.totalPoints'), integer(state.aggregates.leaderboard.totalPoints,
    'leaderboard.totalPoints'), 'Profile and leaderboard points differ');
  return { plans, legacyCount, points };
}

function saveBackup(documents) {
  const directory = path.join(os.homedir(), '.codex', 'backups', 'yomecuido');
  fs.mkdirSync(directory, { recursive: true, mode: 0o700 });
  const filename = `legacy-activities-${new Date().toISOString().replace(/[:.]/g, '-')}-${crypto.randomUUID()}.json`;
  const backupPath = path.join(directory, filename);
  fs.writeFileSync(backupPath, JSON.stringify(documents, null, 2),
    { flag: 'wx', mode: 0o600 });
  const saved = JSON.parse(fs.readFileSync(backupPath, 'utf8'));
  assert.deepEqual(saved, documents, 'Backup verification failed');
  return backupPath;
}

function canonicalFields(fields) {
  const copy = structuredClone(fields);
  for (const field of ['scoredAt10QuestionIds', 'scoredAt5QuestionIds',
    'scoredAt1QuestionIds']) {
    if (copy[field]?.arrayValue && !copy[field].arrayValue.values) {
      copy[field].arrayValue.values = [];
    }
  }
  return copy;
}

function latestBackup() {
  const directory = path.join(os.homedir(), '.codex', 'backups', 'yomecuido');
  const files = fs.readdirSync(directory).filter(name =>
    /^legacy-activities-[\w-]+\.json$/.test(name)).sort();
  assert.ok(files.length > 0, 'No migration backup found');
  return JSON.parse(fs.readFileSync(path.join(directory, files.at(-1)), 'utf8'));
}

function verifyBackup(after) {
  const original = latestBackup();
  assert.equal(original.length, 6);
  const questions = expectedQuestionsByActivity();
  const originals = new Map(original.map(doc =>
    [doc.name.split('/').at(-1), doc]));
  for (const doc of after.activities) {
    const activityId = doc.name.split('/').at(-1);
    const originalDoc = originals.get(activityId);
    assert.ok(originalDoc && originalDoc.name === doc.name,
      'Backup does not match the target user');
    const expected = planDocument(originalDoc, questions.get(activityId));
    assert.ok(expected.legacy, 'Backup is not legacy');
    assert.deepEqual(canonicalFields(doc.fields), canonicalFields(expected.fields),
      `Migrated document differs from backup for ${activityId}`);
  }
  const result = planState(after);
  assert.equal(result.legacyCount, 0);
  assert.equal(result.points, expectedTotalPoints);
  console.log(JSON.stringify({ verifiedAgainstBackup: 6,
    pointsBefore: expectedTotalPoints, pointsAfter: result.points,
    attemptsPreserved: true }));
}

async function run(mode, uid) {
  assert.ok(['--dry-run', '--apply', '--verify'].includes(mode),
    'Use --dry-run, --apply or --verify');
  assert.match(uid ?? '', /^[A-Za-z0-9_-]{1,128}$/,
    'Set YOMECUIDO_MIGRATION_UID from the active test session');
  const token = await accessToken();
  const before = await readState(token, uid);
  const { plans, legacyCount, points } = planState(before);
  if (mode === '--verify') {
    verifyBackup(before);
    return;
  }
  console.log(JSON.stringify({ mode, legacyDocuments: legacyCount,
    legacyPoints: points, plannedPoints: points,
    attempts: plans.map(plan => plan.attempts) }));
  if (mode === '--dry-run' || legacyCount === 0) {
    if (legacyCount === 0) console.log('Already migrated: no writes');
    return;
  }
  saveBackup(before.activities);
  console.log('Backup verified outside Git');
  const writes = before.activities.map((doc, index) => ({
    update: { name: doc.name, fields: plans[index].fields },
    currentDocument: { updateTime: doc.updateTime },
  }));
  await request(token, ':commit', { method: 'POST',
    body: JSON.stringify({ writes }) });
  const after = await readState(token, uid);
  assert.deepEqual(after.aggregates, before.aggregates,
    'Aggregates changed unexpectedly');
  for (let index = 0; index < plans.length; index++) {
    assert.deepEqual(canonicalFields(after.activities[index].fields),
      canonicalFields(plans[index].fields),
      `Post-migration fields differ for ${plans[index].activityId}`);
  }
  const result = planState(after);
  assert.equal(result.legacyCount, 0);
  assert.equal(result.points, expectedTotalPoints);
  console.log(JSON.stringify({ migratedDocuments: 6, pointsBefore: points,
    pointsAfter: result.points, attemptsPreserved: true,
    aggregatesPreserved: true }));
}

module.exports = { scoreSetsFromLegacy, planDocument, planState };

if (require.main === module) {
  run(process.argv[2], process.env.YOMECUIDO_MIGRATION_UID).catch(error => {
    console.error(`Migration stopped: ${error.message}`);
    process.exitCode = 1;
  });
}
