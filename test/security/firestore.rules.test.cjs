const fs = require('node:fs');
const assert = require('node:assert/strict');
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {
  arrayUnion,
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  orderBy,
  query,
  runTransaction,
  serverTimestamp,
  setDoc,
  Timestamp,
  updateDoc,
  where,
  writeBatch,
} = require('firebase/firestore');

const projectId = 'demo-yomecuido-rules';
const categoryId = 'relations_violence_digital';
const lessonId = 'relations_violence';
const activityId = 'relations_violence_activity_01';
const examId = 'relations_violence_final_exam';

let testEnv;

async function main() {
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: fs.readFileSync('firestore.rules', 'utf8'),
    },
  });

  const tests = [
    ['default deny bloquea rutas no autorizadas', defaultDenyUnknownPath],
    ['usuario A puede leer su perfil', ownProfileReadAllowed],
    ['usuario A no puede leer perfil de B', otherProfileReadDenied],
    ['usuario A no puede modificar perfil de B', otherProfileWriteDenied],
    ['usuario no autenticado no crea ni modifica perfil', unauthenticatedProfileWritesDenied],
    ['usuario no autenticado no lee progreso', unauthenticatedProgressReadDenied],
    ['usuario normal no puede escalar rol', roleEscalationDenied],
    ['variantes de rol privilegiado denegadas', privilegedRoleVariantsDenied],
    ['creación de perfil admin denegada', adminProfileCreationDenied],
    ['totalPoints inicial manipulado denegado', manipulatedInitialPointsDenied],
    ['perfil antiguo puede recibir primera puntuación', legacyProfileFirstScoringAllowed],
    ['reducción de totalPoints denegada', totalPointsReductionDenied],
    ['tipo inválido en totalPoints denegado', invalidTotalPointsTypeDenied],
    ['campo inesperado en perfil denegado', unexpectedProfileFieldDenied],
    ['activityPoints negativo denegado', negativeActivityPointsDenied],
    ['campo legacy questionScores denegado', legacyQuestionScoresFieldDenied],
    ['reserva sobre progreso legacy existente denegada', legacyExistingProgressReservationDenied],
    ['progreso migrado reserva intento 3 sin duplicar puntos', migratedProgressReservesWithoutDoubleAward],
    ['sin answer key, sincronización rechaza submission sin cambiar reserva', missingAnswerKeyBlocksPendingSubmission],
    ['attemptNumber inválido denegado', invalidAttemptNumberDenied],
    ['attempt no acepta earnedPoints del cliente', clientEarnedPointsDenied],
    ['porcentaje inválido denegado', invalidPercentageDenied],
    ['correctas superiores al total denegadas', correctAboveTotalDenied],
    ['usuario A no crea progreso ni intentos en usuario B', crossUserProgressWritesDenied],
    ['modificar intento histórico denegado', historicalAttemptUpdateDenied],
    ['eliminar intento denegado', attemptDeleteDenied],
    ['eliminar progreso denegado', progressDeleteDenied],
    ['usuario normal no modifica contenido educativo', contentWriteDenied],
    ['contenido educativo legible para autenticados', contentReadAllowed],
    ['answer key protegido contra lectura y escritura', answerKeyProtected],
    ['commit de 10 respuestas válido e inmutable', validAnswerSubmission],
    ['submission rechaza usuario e identidad incorrectos', invalidAnswerSubmissionIdentityDenied],
    ['submission rechaza ids de preguntas alterados', alteredAnswerQuestionIdsDenied],
    ['submission exige exactamente 10 posiciones', invalidAnswerSubmissionSizeDenied],
    ['resultado debe corresponder con respuestas comprometidas', committedAnswerResultsValidated],
    ['commit bloquea el oráculo de respuestas', committedAnswerOracleBlocked],
    ['correctAnswers manipulado es denegado', manipulatedCommittedCorrectAnswersDenied],
    ['intento parcial conserva slots sin respuesta', partialCommittedAttemptAllowed],
    ['texto fillBlank respeta variantes normalizadas explícitas', fillBlankCommittedVariantAllowed],
    ['query de contenido educativo permitida', contentQueryAllowed],
    ['reserva inicial y siguiente intento válidos', validSequentialAttemptReservations],
    ['reserva realista de primera actividad de trata permitida', realisticTraffickingFirstReservationAllowed],
    ['no repite ni salta números de intento', invalidAttemptReservationNumbersDenied],
    ['no reserva con contador igual ni incrementos mayores', invalidAttemptReservationDeltasDenied],
    ['no altera una reserva activa', activeAttemptReservationImmutable],
    ['no crea un segundo intento activo', secondActiveAttemptDenied],
    ['reserva de otro usuario denegada', otherUserAttemptReservationDenied],
    ['reserva sin autenticación denegada', unauthenticatedAttemptReservationDenied],
    ['teoría propia permitida y ajena denegada', ownTheoryAllowedOtherDenied],
    ['leaderboard legible solo para autenticados', leaderboardReadRules],
    ['query ordenada de leaderboard permitida', leaderboardOrderedQueryAllowed],
    ['leaderboard no permite modificar otro usuario', leaderboardOtherUserWriteDenied],
    ['leaderboard rechaza puntos arbitrarios', leaderboardArbitraryPointsDenied],
    ['leaderboard exige totalPoints de users', leaderboardMustMatchUserPoints],
    ['leaderboard exige username de users', leaderboardMustMatchUsername],
    ['leaderboard rechaza email y role', leaderboardPrivateFieldsDenied],
    ['leaderboard permite sincronización legítima de puntos', leaderboardPointSyncAllowed],
    ['leaderboard permite limpiar campos legacy', leaderboardLegacyCleanupAllowed],
    ['leaderboard permite sincronización legítima de username', leaderboardUsernameSyncAllowed],
    ['lecturas propias previas a guardar progreso permitidas', ownProgressPreflightReadsAllowed],
    ['flujo legítimo de puntuación permitido', legitimateScoringFlowAllowed],
    ['10 respuestas correctas y batch de cuatro documentos permitidos', allTenCorrectAndFourWriteBatchAllowed],
    ['frontera diagnóstica de presupuesto con historial premiado', historicalScoringBudgetBoundary],
    ['extremos de historial mixto y puntuación cero', mixedHistoricalScoringExtremes],
    ['recibo derivado falso no se puede crear', forgedActivitySubmissionDenied],
    ['finalización atómica rechaza batches parciales', partialActivityFinalizationDenied],
    ['attempt finalizado debe coincidir con recibo validado', forgedFinalizedAttemptDenied],
    ['pointValue de reserva corresponde al intento', reservationPointValueValidated],
    ['actividad no se finaliza sin los otros tres agregados', activityFinalizationRequiresFourWriteBatch],
    ['recompensa protegida por intento reservado: 10/5/1/0', scoringPolicyRewardsValidated],
    ['conjuntos premiados no se pueden mover ni borrar', scoredSetsAreImmutableAfterAward],
    ['activityPoints debe ser el delta exacto', activityRewardTotalsCannotBeInflated],
    ['totalPoints exige el intento válido en el mismo batch', totalPointsRequiresAtomicActivityAward],
    ['incrementos repetidos de totalPoints sin evidencia denegados', repeatedDirectTotalPointsIncrementsDenied],
    ['leaderboard no se altera separado del puntaje válido', leaderboardCannotDriftFromAuthoritativeScore],
    ['percentage debe derivarse del resultado comprometido', inventedActivityPercentageDenied],
    ['completedActivityIds requiere finalización real', completedActivityIdsRequireValidAttempt],
    ['el mismo attemptId no vuelve a aplicar puntos', sameAttemptCannotBeAppliedTwice],
    ['transiciones por conjuntos y ataques de puntaje', setBasedTransitionsValidated],
    ['examen semántico valida 15 respuestas con proofs 8+7', examFifteenSemanticAttemptAllowed],
    ['examen aprueba y completa categoría solo con 12 de 15',
      () => examFifteenSemanticAttemptAllowed({ correctCount: 12 })],
  ];

  for (const [name, fn] of tests) {
    if (process.env.RULES_TEST_FILTER && !name.includes(process.env.RULES_TEST_FILTER)) continue;
    await testEnv.clearFirestore();
    await fn();
    console.log(`ok - ${name}`);
  }
}

function authDb(uid, email = `${uid}@example.com`) {
  return testEnv.authenticatedContext(uid, {
    email,
    email_verified: true,
  }).firestore();
}

function unauthDb() {
  return testEnv.unauthenticatedContext().firestore();
}

async function seedUser(uid, totalPoints = 0) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const firestore = context.firestore();
    const profile = userProfile(uid, totalPoints);
    await setDoc(doc(firestore, 'users', uid), profile);
    await setDoc(doc(firestore, 'usernames', profile.usernameNormalized), {
      uid,
    });
    await setDoc(doc(firestore, 'leaderboard', uid), leaderboardEntry(profile));
  });
}

async function seedUserWithoutTotalPoints(uid) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const profile = userProfile(uid);
    delete profile.totalPoints;
    await setDoc(doc(context.firestore(), 'users', uid), profile);
  });
}

async function seedProgress(uid = 'uid-a') {
  await seedUser(uid);
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'users', uid, 'categoryProgress', categoryId),
      progressData(),
    );
  });
}

async function seedActivity(uid = 'uid-a', overrides = {}) {
  await seedProgress(uid);
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(
        context.firestore(),
        'users',
        uid,
        'categoryProgress',
        categoryId,
        'activities',
        activityId,
      ),
      activityProgressData(overrides),
    );
  });
  await seedAnswerKey();
}

async function seedAnswerKey() {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(answerKeyRef(context.firestore()), answerKeyData());
  });
}

async function seedAttempt(uid = 'uid-a') {
  await seedActivity(uid);
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      activityAttemptRef(context.firestore(), uid, 'attempt_1'),
      activityAttemptData({ attemptNumber: 1, earnedPoints: 50 }),
    );
  });
}

async function seedContent() {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const firestore = context.firestore();
    await setDoc(doc(firestore, 'categories', categoryId), {
      id: categoryId,
      title: 'Relaciones y violencia digital',
      description: 'Contenido educativo.',
      iconName: 'shield_outlined',
      status: 'available',
      isEnabled: true,
      order: 1,
      indicators: ['12 actividades'],
      objectives: ['Identificar señales'],
      warning: 'Contenido sensible.',
      lessonId,
    });
    await setDoc(doc(firestore, 'categories', categoryId, 'questions', 'q01'), {
      id: 'q01',
      categoryId,
      activityId,
      type: 'multipleChoice',
      statement: 'Pregunta',
      options: [{ id: 'correct', text: 'Correcta' }],
      correctAnswer: 'correct',
      acceptedAnswers: ['correct'],
      feedback: 'Retroalimentación.',
      capacity: 'reconocer',
      difficulty: 'básica',
    });
    await setDoc(
      doc(firestore, 'categories', categoryId, 'answerKeys', activityId),
      answerKeyData(),
    );
  });
}

function answerKeyData() {
  const questionIds = Array.from({ length: 10 }, (_, index) =>
    `q${String(index + 1).padStart(2, '0')}`,
  );
  return {
    categoryId,
    activityId,
    questionIds,
    correctAnswersByQuestionId: Object.fromEntries(
      questionIds.map((questionId) => [questionId, 'correct']),
    ),
    acceptedAnswersByQuestionId: {},
    fillBlankQuestionIds: [],
  };
}

function answerSubmissionData({
  attemptId = 'attempt_1',
  attemptNumber = 1,
  correctCount = 5,
  answeredCount = 10,
  answers,
  previousScores = {},
  key = answerKeyData(),
} = {}) {
  const submittedAnswers = answers ?? Object.fromEntries(Array.from({ length: 10 }, (_, index) => [
    `q${String(index + 1).padStart(2, '0')}`,
    index < answeredCount
      ? index < correctCount ? 'correct' : 'incorrect'
      : '',
  ]));
  const ids = key.questionIds;
  const correct = ids.map((id) => {
    const answer = submittedAnswers[id];
    return answer !== '' && (key.fillBlankQuestionIds.includes(id)
      ? key.acceptedAnswersByQuestionId[id].includes(answer.trim().toLowerCase())
      : answer === key.correctAnswersByQuestionId[id]);
  });
  const rewardedQuestionIds = ids.filter((id, index) => correct[index] && !previousScores[id]);
  const value = attemptNumber === 1 ? 10 : attemptNumber === 2 ? 5
    : attemptNumber === 3 ? 1 : 0;
  return {
    finalizationVersion: 2,
    attemptId,
    attemptNumber,
    categoryId,
    activityId,
    questionIds: ids,
    answers: submittedAnswers,
    correct,
    correctAnswers: correct.filter(Boolean).length,
    percentage: correct.filter(Boolean).length * 10,
    rewardedQuestionIds,
    earnedPoints: rewardedQuestionIds.length * value,
    committedAt: serverTimestamp(),
  };
}

function answerSubmissionRef(firestore, uid, id = 'attempt_1') {
  return doc(firestore, 'users', uid, 'categoryProgress', categoryId,
    'activities', activityId, 'answerSubmissions', id);
}

function answerKeyRef(firestore, catId = categoryId, actId = activityId) {
  return doc(firestore, 'categories', catId, 'answerKeys', actId);
}

async function setActiveReservation(uid, id = 'attempt_1', number = 1) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await updateDoc(activityProgressRef(context.firestore(), uid), {
      attemptCount: number,
      activeAttempt: activeAttempt(id, number,
        Timestamp.fromDate(new Date('2026-09-05T00:00:00Z'))),
      status: 'inProgress',
    });
  });
}

function userProfile(uid, totalPoints = 0) {
  const username = `user${uid.replace(/[^a-zA-Z0-9]/g, '')}`;
  return {
    username,
    usernameNormalized: username.toLowerCase(),
    email: `${uid}@example.com`,
    role: 'user',
    totalPoints,
    createdAt: Timestamp.fromDate(new Date('2026-09-01T00:00:00Z')),
    updatedAt: Timestamp.fromDate(new Date('2026-09-01T00:00:00Z')),
  };
}

function leaderboardEntry(profile, overrides = {}) {
  return {
    username: profile.username,
    totalPoints: profile.totalPoints,
    updatedAt: Timestamp.fromDate(new Date('2026-09-01T00:00:00Z')),
    ...overrides,
  };
}

function progressData(overrides = {}) {
  return {
    categoryId,
    lessonId,
    status: 'inProgress',
    viewedLessonPageIds: [],
    completedActivityIds: [],
    totalLessonPages: 4,
    totalActivities: 6,
    startedAt: Timestamp.fromDate(new Date('2026-09-01T00:00:00Z')),
    lastActivityAt: null,
    completedAt: null,
    updatedAt: Timestamp.fromDate(new Date('2026-09-01T00:00:00Z')),
    ...overrides,
  };
}

function activityProgressData(overrides = {}) {
  return {
    activityId,
    status: 'inProgress',
    attemptCount: 1,
    activityPoints: 0,
    scoredAt10QuestionIds: [],
    scoredAt5QuestionIds: [],
    scoredAt1QuestionIds: [],
    bestCorrectAnswers: 0,
    bestTotalQuestions: 0,
    bestPercentage: 0,
    lastAttemptAt: null,
    completedAt: null,
    updatedAt: Timestamp.fromDate(new Date('2026-09-02T00:00:00Z')),
    activeAttempt: null,
    ...overrides,
  };
}

function activityProgressRef(firestore, uid = 'uid-a') {
  return doc(firestore, 'users', uid, 'categoryProgress', categoryId,
    'activities', activityId);
}

function activeAttempt(attemptId, attemptNumber, reservedAt = serverTimestamp()) {
  return { attemptId, attemptNumber, reservedAt,
    pointValue: attemptNumber === 1 ? 10 : attemptNumber === 2 ? 5 : attemptNumber === 3 ? 1 : 0 };
}

function reservationProgressData(attemptId, attemptNumber) {
  return {
    activityId,
    status: 'inProgress',
    attemptCount: attemptNumber,
    activityPoints: 0,
    scoredAt10QuestionIds: [],
    scoredAt5QuestionIds: [],
    scoredAt1QuestionIds: [],
    bestCorrectAnswers: 0,
    bestTotalQuestions: 0,
    bestPercentage: 0,
    lastAttemptAt: null,
    completedAt: null,
    updatedAt: serverTimestamp(),
    activeAttempt: activeAttempt(attemptId, attemptNumber),
  };
}

function activityAttemptData(overrides = {}) {
  const correct = Array.from({ length: 10 }, (_, index) => index < 5);
  return {
    finalizationVersion: 2,
    type: 'activity',
    attemptNumber: 1,
    categoryId,
    activityId,
    examId: null,
    questionIds: questionIds(),
    correct,
    correctAnswers: 5,
    totalQuestions: 10,
    percentage: 50,
    rewardedQuestionIds: questionIds().slice(0, 5),
    earnedPoints: 50,
    startedAt: Timestamp.fromDate(new Date('2026-09-02T00:00:00Z')),
    completedAt: serverTimestamp(),
    ...overrides,
  };
}

function questionIds() {
  return Array.from({ length: 10 }, (_, index) => `q${String(index + 1).padStart(2, '0')}`);
}

function answersByQuestionId(correctCount, answeredCount = 10, attemptNumber = 1) {
  const pointsPerCorrect = attemptNumber === 1
    ? 10
    : attemptNumber === 2 ? 5 : attemptNumber === 3 ? 1 : 0;
  return Object.fromEntries(
    questionIds().slice(0, answeredCount).map((questionId, index) => [
      questionId,
      {
        questionId,
        answer: index < correctCount ? 'correct' : 'incorrect',
        isCorrect: index < correctCount,
        pointsEarned: index < correctCount ? pointsPerCorrect : 0,
        answeredAt: Timestamp.fromDate(new Date('2026-09-02T00:00:00Z')),
      },
    ]),
  );
}

function activityAttemptRef(firestore, uid, attemptId) {
  return doc(
    firestore,
    'users',
    uid,
    'categoryProgress',
    categoryId,
    'activities',
    activityId,
    'attempts',
    attemptId,
  );
}

async function buildScoringFinalization({
  firestore,
  uid = 'uid-a',
  attemptId = 'attempt_1',
  attemptNumber = 1,
  committedAnswers,
  key = answerKeyData(),
}) {
  const activityRef = activityProgressRef(firestore, uid);
  const userRef = doc(firestore, 'users', uid);
  const categoryRef = doc(firestore, 'users', uid, 'categoryProgress', categoryId);
  const leaderboardRef = doc(firestore, 'leaderboard', uid);
  const [activitySnapshot, userSnapshot, categorySnapshot] = await Promise.all([
    getDoc(activityRef),
    getDoc(userRef),
    getDoc(categoryRef),
  ]);
  const previousActivity = activitySnapshot.data();
  const previousUser = userSnapshot.data();
  const previousCategory = categorySnapshot.data();
  const correctByIndex = key.questionIds.map((questionId) => {
    const answer = committedAnswers[questionId];
    return answer !== '' && (key.fillBlankQuestionIds.includes(questionId)
      ? key.acceptedAnswersByQuestionId[questionId].includes(answer.trim().toLowerCase())
      : answer === key.correctAnswersByQuestionId[questionId]);
  });
  const correctAnswers = correctByIndex.filter(Boolean).length;
  const pointsPerCorrect = attemptNumber === 1 ? 10 : attemptNumber === 2 ? 5
    : attemptNumber === 3 ? 1 : 0;
  const previousSets = {
    10: previousActivity.scoredAt10QuestionIds,
    5: previousActivity.scoredAt5QuestionIds,
    1: previousActivity.scoredAt1QuestionIds,
  };
  const alreadyScored = new Set(Object.values(previousSets).flat());
  const newlyRewarded = key.questionIds.filter((id, index) =>
    correctByIndex[index] && !alreadyScored.has(id));
  const earnedPoints = newlyRewarded.length * pointsPerCorrect;
  const nextSets = {
    10: [...previousSets[10]], 5: [...previousSets[5]], 1: [...previousSets[1]],
  };
  if (pointsPerCorrect > 0) nextSets[pointsPerCorrect].push(...newlyRewarded);
  const percentage = correctAnswers * 10;
  const replaceBest = percentage >= previousActivity.bestPercentage;
  const completedActivityIds = [...(previousCategory.completedActivityIds ?? [])];
  if (!completedActivityIds.includes(activityId)) completedActivityIds.push(activityId);
  const attempt = activityAttemptData({
    attemptNumber,
    questionIds: key.questionIds,
    correct: correctByIndex,
    correctAnswers,
    percentage,
    rewardedQuestionIds: newlyRewarded,
    earnedPoints,
  });
  const activity = {
    ...previousActivity,
    activityId,
    status: 'completed',
    attemptCount: attemptNumber,
    activeAttempt: null,
    activityPoints: previousActivity.activityPoints + earnedPoints,
    scoredAt10QuestionIds: nextSets[10],
    scoredAt5QuestionIds: nextSets[5],
    scoredAt1QuestionIds: nextSets[1],
    bestCorrectAnswers: replaceBest ? correctAnswers : previousActivity.bestCorrectAnswers,
    bestTotalQuestions: replaceBest ? 10 : previousActivity.bestTotalQuestions,
    bestPercentage: replaceBest ? percentage : previousActivity.bestPercentage,
    lastAttemptAt: serverTimestamp(),
    completedAt: previousActivity.completedAt ?? serverTimestamp(),
    updatedAt: serverTimestamp(),
  };
  const category = {
    ...previousCategory,
    categoryId,
    lessonId,
    status: previousCategory.status === 'notStarted' ? 'inProgress' : previousCategory.status,
    completedActivityIds,
    lastActivityAt: serverTimestamp(),
    completedAt: null,
    updatedAt: serverTimestamp(),
  };
  const user = {
    totalPoints: (previousUser.totalPoints ?? 0) + earnedPoints,
    lastActivityAward: { categoryId, activityId, attemptId, attemptNumber },
    updatedAt: serverTimestamp(),
  };
  const leaderboard = {
    username: previousUser.username,
    totalPoints: user.totalPoints,
    updatedAt: serverTimestamp(),
  };
  return {
    attempt,
    activity,
    category,
    user,
    leaderboard,
    refs: {
      activityRef,
      attemptRef: activityAttemptRef(firestore, uid, attemptId),
      categoryRef,
      userRef,
      leaderboardRef,
    },
  };
}

async function commitScoringFinalization(firestore, plan) {
  const batch = writeBatch(firestore);
  batch.set(plan.refs.attemptRef, plan.attempt);
  batch.set(plan.refs.activityRef, plan.activity);
  batch.set(plan.refs.categoryRef, plan.category);
  batch.set(plan.refs.userRef, plan.user, { merge: true });
  batch.set(plan.refs.leaderboardRef, plan.leaderboard);
  return batch.commit();
}

async function prepareAttempt({
  uid = 'uid-a',
  attemptNumber = 1,
  correctCount = 1,
  answeredCount = 1,
  answers,
  previousScores = {},
  totalPoints = 0,
  historicalCompletion = false,
} = {}) {
  const attemptId = `attempt_${attemptNumber}`;
  const previousActivityPoints = Object.values(previousScores).reduce(
    (sum, score) => sum + score.pointsAwarded,
    0,
  );
  await seedActivity(uid, {
    attemptCount: Math.max(1, attemptNumber - 1),
    activityPoints: previousActivityPoints,
    scoredAt10QuestionIds: Object.keys(previousScores).filter((id) =>
      previousScores[id].pointsAwarded === 10),
    scoredAt5QuestionIds: Object.keys(previousScores).filter((id) =>
      previousScores[id].pointsAwarded === 5),
    scoredAt1QuestionIds: Object.keys(previousScores).filter((id) =>
      previousScores[id].pointsAwarded === 1),
  });
  if (totalPoints !== 0) {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), 'users', uid), { totalPoints });
      await updateDoc(doc(context.firestore(), 'leaderboard', uid), { totalPoints });
    });
  }
  await setActiveReservation(uid, attemptId, attemptNumber);
  if (historicalCompletion) {
    const completedAt = Timestamp.fromDate(new Date('2026-09-02T00:00:00Z'));
    const scoredCount = Object.keys(previousScores).length;
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await updateDoc(activityProgressRef(db, uid), {
        bestCorrectAnswers: scoredCount,
        bestTotalQuestions: 10,
        bestPercentage: scoredCount * 10,
        lastAttemptAt: completedAt,
        completedAt,
      });
      await updateDoc(doc(db, 'users', uid, 'categoryProgress', categoryId), {
        completedActivityIds: [activityId],
      });
    });
  }
  const firestore = authDb(uid);
  const committed = answerSubmissionData({
    attemptId,
    attemptNumber,
    correctCount,
    answeredCount,
    answers,
    previousScores,
  });
  await assertSucceeds(setDoc(
    answerSubmissionRef(firestore, uid, attemptId),
    committed,
  ));
  const plan = await buildScoringFinalization({
    firestore,
    uid,
    attemptId,
    attemptNumber,
    committedAnswers: committed.answers,
  });
  return { firestore, committed, plan, attemptId };
}

async function scoringPolicyRewardsValidated() {
  const expected = new Map([[1, 10], [2, 5], [3, 1], [4, 0]]);
  for (const [attemptNumber, points] of expected) {
    await testEnv.clearFirestore();
    const { firestore, plan } = await prepareAttempt({ attemptNumber });
    if (plan.activity.activityPoints !== points) {
      throw new Error(`Attempt ${attemptNumber} expected ${points} points.`);
    }
    await assertSucceeds(commitScoringFinalization(firestore, plan));
    const activity = (await getDoc(activityProgressRef(firestore))).data();
    const scoredIds = activity[`scoredAt${points}QuestionIds`] ?? [];
    if (points > 0 && !scoredIds.includes('q01')) {
      throw new Error(`Attempt ${attemptNumber} stored the wrong question score.`);
    }
  }
}

async function scoredSetsAreImmutableAfterAward() {
  const previousScores = {
    q01: { questionId: 'q01', pointsAwarded: 5, awardedAttempt: 2 },
  };
  for (const change of [
    (activity) => activity.scoredAt10QuestionIds.push('q01'),
    (activity) => activity.scoredAt1QuestionIds.push('q01'),
    (activity) => { activity.scoredAt5QuestionIds = []; },
  ]) {
    await testEnv.clearFirestore();
    const { firestore, plan } = await prepareAttempt({ attemptNumber: 3, previousScores });
    change(plan.activity);
    await assertFails(commitScoringFinalization(firestore, plan));
  }
}

async function activityRewardTotalsCannotBeInflated() {
  const { firestore, plan } = await prepareAttempt({ attemptNumber: 1 });
  plan.activity.activityPoints = 20;
  plan.user.totalPoints = 20;
  plan.leaderboard.totalPoints = 20;
  await assertFails(commitScoringFinalization(firestore, plan));

  await testEnv.clearFirestore();
  const second = await prepareAttempt({ correctCount: 3, answeredCount: 3 });
  second.plan.activity.activityPoints = 500;
  await assertFails(commitScoringFinalization(second.firestore, second.plan));
}

async function totalPointsRequiresAtomicActivityAward() {
  const { firestore, plan } = await prepareAttempt({
    attemptNumber: 2,
    correctCount: 3,
    answeredCount: 3,
    totalPoints: 100,
  });
  if (plan.activity.activityPoints !== 15) {
    throw new Error('The attempt 2 fixture must earn exactly 15 points.');
  }
  await assertSucceeds(commitScoringFinalization(firestore, plan));
  const user = (await getDoc(doc(firestore, 'users', 'uid-a'))).data();
  if (user.totalPoints !== 115) {
    throw new Error('totalPoints did not increase by the validated reward.');
  }

  await testEnv.clearFirestore();
  const forged = await prepareAttempt({
    attemptNumber: 2,
    correctCount: 3,
    answeredCount: 3,
    totalPoints: 100,
  });
  forged.plan.user.totalPoints = 120;
  forged.plan.leaderboard.totalPoints = 120;
  await assertFails(commitScoringFinalization(forged.firestore, forged.plan));
}

async function repeatedDirectTotalPointsIncrementsDenied() {
  await seedUser('uid-a', 100);
  const firestore = authDb('uid-a');
  for (const totalPoints of [110, 120, 130]) {
    await assertFails(updateDoc(doc(firestore, 'users', 'uid-a'), {
      totalPoints,
      updatedAt: serverTimestamp(),
    }));
  }
}

async function leaderboardCannotDriftFromAuthoritativeScore() {
  const { firestore, plan } = await prepareAttempt({ correctCount: 2, answeredCount: 2 });
  await assertSucceeds(commitScoringFinalization(firestore, plan));
  await assertFails(updateDoc(doc(firestore, 'leaderboard', 'uid-a'), {
    totalPoints: 9999,
    updatedAt: serverTimestamp(),
  }));
}

async function inventedActivityPercentageDenied() {
  const { firestore, plan } = await prepareAttempt({ correctCount: 6, answeredCount: 10 });
  plan.attempt.percentage = 100;
  plan.activity.bestPercentage = 100;
  plan.activity.bestCorrectAnswers = 10;
  await assertFails(commitScoringFinalization(firestore, plan));
}

async function completedActivityIdsRequireValidAttempt() {
  await seedProgress('uid-a');
  await assertFails(updateDoc(doc(
    authDb('uid-a'), 'users', 'uid-a', 'categoryProgress', categoryId,
  ), {
    completedActivityIds: arrayUnion('relations_violence_activity_02'),
    lastActivityAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  }));

  await testEnv.clearFirestore();
  const { firestore, plan } = await prepareAttempt({ correctCount: 2, answeredCount: 2 });
  plan.category.completedActivityIds.push('relations_violence_activity_02');
  await assertFails(commitScoringFinalization(firestore, plan));
}

async function sameAttemptCannotBeAppliedTwice() {
  const { firestore, plan } = await prepareAttempt({ correctCount: 3, answeredCount: 3 });
  await assertSucceeds(commitScoringFinalization(firestore, plan));
  const activityBefore = (await getDoc(activityProgressRef(firestore))).data();
  const totalBefore = (await getDoc(doc(firestore, 'users', 'uid-a'))).data().totalPoints;
  await assertFails(commitScoringFinalization(firestore, plan));
  const activityAfter = (await getDoc(activityProgressRef(firestore))).data();
  const totalAfter = (await getDoc(doc(firestore, 'users', 'uid-a'))).data().totalPoints;
  if (activityAfter.activityPoints !== activityBefore.activityPoints || totalAfter !== totalBefore) {
    throw new Error('Retrying a finalized attempt applied its reward a second time.');
  }
}

function examQuestionIds() {
  return Array.from({ length: 60 }, (_, index) =>
    `exam_q${String(index + 1).padStart(2, '0')}`);
}

function examSelectedIds() {
  return examQuestionIds().slice(0, 15);
}

function examProgressRef(firestore, uid = 'uid-a') {
  return doc(firestore, 'users', uid, 'categoryProgress', categoryId,
    'exams', examId);
}

function examSubmissionRef(firestore, uid = 'uid-a', attemptId = 'exam_1') {
  return doc(firestore, 'users', uid, 'categoryProgress', categoryId,
    'exams', examId, 'answerSubmissions', attemptId);
}

function examAttemptRef(firestore, uid = 'uid-a', attemptId = 'exam_1') {
  return doc(firestore, 'users', uid, 'categoryProgress', categoryId,
    'exams', examId, 'attempts', attemptId);
}

async function examFifteenSemanticAttemptAllowed({ correctCount = 9 } = {}) {
  await seedProgress('uid-a');
  const selected = examSelectedIds();
  const activityIds = Array.from({ length: 6 }, (_, index) =>
    `relations_violence_activity_0${index + 1}`);
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'users', 'uid-a', 'categoryProgress', categoryId),
      progressData({
        viewedLessonPageIds: ['page_01', 'page_02', 'page_03', 'page_04'],
        completedActivityIds: activityIds,
      }));
    for (const id of activityIds) {
      await setDoc(doc(db, 'users', 'uid-a', 'categoryProgress', categoryId,
        'activities', id), activityProgressData({
        activityId: id,
        status: 'completed',
        bestCorrectAnswers: 8,
        bestTotalQuestions: 10,
        bestPercentage: 80,
        completedAt: Timestamp.fromDate(new Date('2026-09-02T00:00:00Z')),
      }));
    }
    await setDoc(doc(context.firestore(), 'categories', categoryId,
      'answerKeys', examId), {
      categoryId,
      examId,
      questionIds: examQuestionIds(),
      activityIds,
      correctAnswersByQuestionId: Object.fromEntries(
        examQuestionIds().map((id) => [id, 'correct'])),
      acceptedAnswersByQuestionId: {},
      fillBlankQuestionIds: [],
    });
  });
  const firestore = authDb('uid-a');
  if (correctCount === 9) {
    for (const invalidSelection of [
      [...selected.slice(0, 14), selected[0]],
      [...selected.slice(0, 14), 'foreign_question'],
    ]) {
      await assertFails(setDoc(examProgressRef(firestore), {
        examId, status: 'inProgress', attemptCount: 1,
        activeAttempt: { attemptId: 'exam_1', attemptNumber: 1,
          selectedQuestionIds: invalidSelection, reservedAt: serverTimestamp() },
        bestCorrectAnswers: 0, bestTotalQuestions: 0, bestPercentage: 0,
        lastAttemptAt: null, completedAt: null, updatedAt: serverTimestamp(),
      }));
    }
  }
  await assertSucceeds(setDoc(examProgressRef(firestore), {
    examId,
    status: 'inProgress',
    attemptCount: 1,
    activeAttempt: {
      attemptId: 'exam_1',
      attemptNumber: 1,
      selectedQuestionIds: selected,
      reservedAt: serverTimestamp(),
    },
    bestCorrectAnswers: 0,
    bestTotalQuestions: 0,
    bestPercentage: 0,
    lastAttemptAt: null,
    completedAt: null,
    updatedAt: serverTimestamp(),
  }));
  if (correctCount === 9) {
    const duplicate = [...selected];
    duplicate[14] = duplicate[0];
    await assertFails(setDoc(examProgressRef(firestore), {
      examId, status: 'inProgress', attemptCount: 1,
      activeAttempt: { attemptId: 'exam_1', attemptNumber: 1,
        selectedQuestionIds: duplicate, reservedAt: serverTimestamp() },
      bestCorrectAnswers: 0, bestTotalQuestions: 0, bestPercentage: 0,
      lastAttemptAt: null, completedAt: null, updatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(examProgressRef(firestore), {
      'activeAttempt.selectedQuestionIds': examQuestionIds().slice(15, 30),
      updatedAt: serverTimestamp(),
    }));
    await assertFails(setDoc(examSubmissionRef(authDb('uid-b')), {
      attemptId: 'exam_1', attemptNumber: 1, categoryId, examId,
      answers: Object.fromEntries(selected.map((id) => [id, 'correct'])),
      committedAt: serverTimestamp(),
    }));
  }
  const answers = Object.fromEntries(selected.map((id, index) =>
    [id, index < correctCount ? 'correct' : 'incorrect']));
  await assertSucceeds(setDoc(examSubmissionRef(firestore), {
    attemptId: 'exam_1',
    attemptNumber: 1,
    categoryId,
    examId,
    answers,
    committedAt: serverTimestamp(),
  }));
  if (correctCount === 9) {
    await assertFails(updateDoc(examSubmissionRef(firestore), {
      answers: Object.fromEntries(selected.map((id) => [id, 'correct'])),
    }));
    await assertFails(deleteDoc(examSubmissionRef(firestore)));
  }
  for (const [part, ids, correct] of [
    ['A', selected.slice(0, 8), selected.slice(0, 8).map(() => true)],
    ['B', selected.slice(8), selected.slice(8).map((_, index) => index + 8 < correctCount)],
  ]) {
    if (part === 'A' && correctCount === 9) {
      await assertFails(setDoc(doc(firestore, 'users', 'uid-a',
        'categoryProgress', categoryId, 'exams', examId, 'attempts',
        'exam_1', 'proofs', 'A'), {
        uid: 'uid-a', attemptId: 'exam_1', attemptNumber: 1,
        categoryId, examId, part: 'A', questionIds: ids,
        correct: [false, ...correct.slice(1)], correctAnswers: 7,
        createdAt: serverTimestamp(),
      }));
    }
    if (part === 'B' && correctCount === 9) {
      await assertFails(setDoc(doc(firestore, 'users', 'uid-a',
        'categoryProgress', categoryId, 'exams', examId, 'attempts',
        'other_attempt', 'proofs', 'B'), {
        uid: 'uid-a', attemptId: 'exam_1', attemptNumber: 1,
        categoryId, examId, part: 'B', questionIds: ids,
        correct, correctAnswers: correct.filter(Boolean).length,
        createdAt: serverTimestamp(),
      }));
    }
    await assertSucceeds(setDoc(doc(firestore, 'users', 'uid-a',
      'categoryProgress', categoryId, 'exams', examId, 'attempts',
      'exam_1', 'proofs', part), {
      uid: 'uid-a',
      attemptId: 'exam_1',
      attemptNumber: 1,
      categoryId,
      examId,
      part,
      questionIds: ids,
      correct,
      correctAnswers: correct.filter(Boolean).length,
      createdAt: serverTimestamp(),
    }));
  }
  const semanticAttempt = {
    type: 'exam',
    categoryId,
    activityId: null,
    examId,
    attemptNumber: 1,
    questionIds: selected,
    correct: selected.map((_, index) => index < correctCount),
    correctAnswers: correctCount,
    totalQuestions: 15,
    percentage: Math.round(correctCount / 15 * 100),
    earnedPoints: 0,
    startedAt: Timestamp.fromDate(new Date('2026-09-02T00:00:00Z')),
    completedAt: serverTimestamp(),
  };
  if (correctCount === 9) {
    await assertFails(setDoc(examAttemptRef(firestore), {
      ...semanticAttempt,
      correct: selected.map(() => true),
      correctAnswers: 15,
      percentage: 100,
    }));
    await assertFails(setDoc(examAttemptRef(firestore), {
      ...semanticAttempt, earnedPoints: 10,
    }));
  }
  await assertSucceeds(setDoc(examAttemptRef(firestore), semanticAttempt));
  if (correctCount === 9) {
    await assertFails(updateDoc(examAttemptRef(firestore), {
      percentage: 100,
    }));
  }
  const batch = writeBatch(firestore);
  batch.set(examProgressRef(firestore), {
    examId,
    status: 'completed',
    attemptCount: 1,
    activeAttempt: null,
    bestCorrectAnswers: correctCount,
    bestTotalQuestions: 15,
    bestPercentage: Math.round(correctCount / 15 * 100),
    lastAttemptAt: serverTimestamp(),
    completedAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });
  batch.update(doc(firestore, 'users', 'uid-a', 'categoryProgress', categoryId), {
    categoryId,
    lessonId,
    status: correctCount >= 12 ? 'completed' : 'inProgress',
    totalLessonPages: 4,
    totalActivities: 6,
    lastActivityAt: serverTimestamp(),
    completedAt: correctCount >= 12 ? serverTimestamp() : null,
    updatedAt: serverTimestamp(),
  });
  if (correctCount === 9) {
    const fakePass = writeBatch(firestore);
    fakePass.set(examProgressRef(firestore), {
      examId, status: 'completed', attemptCount: 1, activeAttempt: null,
      bestCorrectAnswers: 15, bestTotalQuestions: 15, bestPercentage: 100,
      lastAttemptAt: serverTimestamp(), completedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
    fakePass.update(doc(firestore, 'users', 'uid-a', 'categoryProgress', categoryId), {
      status: 'completed', completedAt: serverTimestamp(),
      lastActivityAt: serverTimestamp(), updatedAt: serverTimestamp(),
    });
    await assertFails(fakePass.commit());
  }
  await assertSucceeds(batch.commit());
  await assertFails(setDoc(examProgressRef(firestore), {
    examId, status: 'completed', attemptCount: 1, activeAttempt: null,
    bestCorrectAnswers: correctCount, bestTotalQuestions: 15,
    bestPercentage: Math.round(correctCount / 15 * 100),
    lastAttemptAt: serverTimestamp(), completedAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  }));
  if (correctCount === 9) {
    for (const invalidNumber of [1, 3]) {
      await assertFails(setDoc(examProgressRef(firestore), {
        examId, status: 'inProgress', attemptCount: invalidNumber,
        activeAttempt: { attemptId: 'exam_new',
          attemptNumber: invalidNumber, selectedQuestionIds: selected,
          reservedAt: serverTimestamp() },
        bestCorrectAnswers: 9, bestTotalQuestions: 15, bestPercentage: 60,
        lastAttemptAt: serverTimestamp(), completedAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }));
    }
    await assertSucceeds(setDoc(examProgressRef(firestore), {
      examId, status: 'inProgress', attemptCount: 2,
      activeAttempt: { attemptId: 'exam_2', attemptNumber: 2,
        selectedQuestionIds: selected, reservedAt: serverTimestamp() },
      bestCorrectAnswers: 9, bestTotalQuestions: 15, bestPercentage: 60,
      lastAttemptAt: (await getDoc(examProgressRef(firestore))).data().lastAttemptAt,
      completedAt: (await getDoc(examProgressRef(firestore))).data().completedAt,
      updatedAt: serverTimestamp(),
    }));
  }
}

async function setBasedTransitionsValidated() {
  const answers = Object.fromEntries(questionIds().map((id) =>
    [id, ['q01', 'q02', 'q04', 'q06'].includes(id) ? 'correct' : 'incorrect']));
  const previousScores = {
    q01: { pointsAwarded: 10 },
    q04: { pointsAwarded: 5 },
  };
  async function fixture() {
    return prepareAttempt({ attemptNumber: 2, answers, previousScores, totalPoints: 15 });
  }

  let prepared = await fixture();
  const { firestore, plan } = prepared;
  if (plan.activity.activityPoints !== 25
    || plan.user.totalPoints !== 25
    || JSON.stringify(plan.activity.scoredAt10QuestionIds) !== '["q01"]'
    || JSON.stringify(plan.activity.scoredAt5QuestionIds) !== '["q04","q02","q06"]') {
    throw new Error('The set transition fixture is not the expected 10-point delta.');
  }
  await assertSucceeds(commitScoringFinalization(firestore, plan));

  const attacks = [
    (p) => { p.activity.activityPoints += 5; p.user.totalPoints += 5;
      p.leaderboard.totalPoints += 5; },
    (p) => { p.activity.scoredAt10QuestionIds.push('q02'); },
    (p) => { p.activity.scoredAt5QuestionIds.push('q07'); },
    (p) => { p.activity.scoredAt5QuestionIds.push('q01'); },
    (p) => { p.activity.scoredAt10QuestionIds = []; },
    (p) => { p.activity.scoredAt5QuestionIds = ['q02', 'q06']; },
    (p) => { p.activity.scoredAt5QuestionIds.push('q02'); },
    (p) => { p.user.totalPoints += 5; p.leaderboard.totalPoints += 5; },
    (p) => { p.leaderboard.totalPoints += 5; },
  ];
  for (const attack of attacks) {
    await testEnv.clearFirestore();
    prepared = await fixture();
    attack(prepared.plan);
    await assertFails(commitScoringFinalization(prepared.firestore, prepared.plan));
  }
}

async function allTenCorrectAndFourWriteBatchAllowed() {
  const { firestore, plan } = await prepareAttempt({ correctCount: 10, answeredCount: 10 });
  if (plan.activity.activityPoints !== 100) {
    throw new Error('Ten correct answers must award 100 points on attempt one.');
  }
  await assertSucceeds(commitScoringFinalization(firestore, plan));
}

async function missingAnswerKeyBlocksPendingSubmission() {
  await seedActivity('uid-a');
  await setActiveReservation('uid-a', 'pending_attempt', 1);
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await deleteDoc(answerKeyRef(context.firestore()));
  });
  const firestore = authDb('uid-a');
  const ref = answerSubmissionRef(firestore, 'uid-a', 'pending_attempt');
  const submission = answerSubmissionData({
    attemptId: 'pending_attempt',
    attemptNumber: 1,
    answeredCount: 0,
    correctCount: 0,
  });
  await assertFails(setDoc(ref, submission));
  assert.equal((await getDoc(ref)).exists(), false);
  const progress = (await getDoc(activityProgressRef(firestore))).data();
  assert.equal(progress.activeAttempt.attemptId, 'pending_attempt');
  assert.equal(progress.activeAttempt.attemptNumber, 1);
  await seedAnswerKey();
  await assertSucceeds(setDoc(ref, submission));
}

async function historicalScoringBudgetBoundary() {
  // A prior completion leaves completedAt set. Every case must finalize.
  const cases = [
    [1, 7],
    [1, 8],
    [10, 3],
    [10, 4],
    [10, 10],
    [10, 0],
  ];
  for (const [count, correctCount] of cases) {
    await testEnv.clearFirestore();
    const ids = Array.from({ length: count }, (_, index) =>
      `q${String(index + 1).padStart(2, '0')}`);
    const previousScores = Object.fromEntries(ids.map((id) => [id, {
      pointsAwarded: 10,
    }]));
    const { firestore, plan } = await prepareAttempt({
      attemptNumber: 3,
      correctCount,
      answeredCount: 10,
      previousScores,
      totalPoints: count * 10,
      historicalCompletion: true,
    });
    await assertSucceeds(commitScoringFinalization(firestore, plan));
  }
}

async function mixedHistoricalScoringExtremes() {
  const previousScores = Object.fromEntries(questionIds().map((id, index) => [id, {
    pointsAwarded: index < 4 ? 10 : index < 7 ? 5 : 1,
  }]));
  for (const correctCount of [0, 5, 10]) {
    await testEnv.clearFirestore();
    const { firestore, plan } = await prepareAttempt({
      attemptNumber: 4,
      correctCount,
      answeredCount: 10,
      previousScores,
      totalPoints: 58,
      historicalCompletion: true,
    });
    assert.equal(plan.attempt.earnedPoints, 0);
    await assertSucceeds(commitScoringFinalization(firestore, plan));
  }
  await testEnv.clearFirestore();
  const { firestore, plan } = await prepareAttempt({
    attemptNumber: 3,
    correctCount: 10,
    answeredCount: 10,
    previousScores: { q01: { pointsAwarded: 10 } },
    totalPoints: 10,
    historicalCompletion: true,
  });
  assert.equal(plan.attempt.earnedPoints, 9);
  await assertSucceeds(commitScoringFinalization(firestore, plan));
}

async function forgedActivitySubmissionDenied() {
  const variants = [
    (s) => { s.earnedPoints = 100; },
    (s) => { s.rewardedQuestionIds = ['q02']; },
    (s) => { s.correct[0] = false; },
    (s) => { s.correctAnswers = 10; },
    (s) => { s.percentage = 100; },
    (s) => { s.attemptId = 'other_attempt'; },
    (s) => { s.attemptNumber = 2; },
  ];
  for (const mutate of variants) {
    await testEnv.clearFirestore();
    await seedActivity('uid-a');
    await setActiveReservation('uid-a', 'attempt_1', 1);
    const firestore = authDb('uid-a');
    const submission = answerSubmissionData({ correctCount: 1 });
    mutate(submission);
    await assertFails(setDoc(answerSubmissionRef(firestore, 'uid-a'), submission));
  }
}

async function partialActivityFinalizationDenied() {
  const { firestore, plan } = await prepareAttempt({ correctCount: 3 });
  const partial = writeBatch(firestore);
  partial.set(plan.refs.attemptRef, plan.attempt);
  partial.set(plan.refs.activityRef, plan.activity);
  await assertFails(partial.commit());

  const withoutAttempt = writeBatch(firestore);
  withoutAttempt.set(plan.refs.activityRef, plan.activity);
  withoutAttempt.set(plan.refs.categoryRef, plan.category);
  withoutAttempt.set(plan.refs.userRef, plan.user, { merge: true });
  withoutAttempt.set(plan.refs.leaderboardRef, plan.leaderboard);
  await assertFails(withoutAttempt.commit());
  assert.equal((await getDoc(plan.refs.attemptRef)).exists(), false);
  await assertSucceeds(commitScoringFinalization(firestore, plan));
}

async function forgedFinalizedAttemptDenied() {
  const variants = [
    (p) => { p.attempt.earnedPoints += 10; },
    (p) => { p.attempt.rewardedQuestionIds = ['q10']; },
    (p) => { p.attempt.correct[0] = false; },
    (p) => { p.attempt.attemptNumber = 2; },
    (p) => { p.attempt.finalizationVersion = 1; },
  ];
  for (const mutate of variants) {
    await testEnv.clearFirestore();
    const { firestore, plan } = await prepareAttempt({ correctCount: 3 });
    mutate(plan);
    await assertFails(commitScoringFinalization(firestore, plan));
  }
}

async function reservationPointValueValidated() {
  await seedActivity('uid-a');
  const firestore = authDb('uid-a');
  const reservation = activeAttempt('attempt_2', 2);
  reservation.pointValue = 10;
  await assertFails(updateDoc(activityProgressRef(firestore), {
    attemptCount: 2,
    activeAttempt: reservation,
    updatedAt: serverTimestamp(),
  }));
}

async function activityFinalizationRequiresFourWriteBatch() {
  const { firestore, plan } = await prepareAttempt({ correctCount: 2, answeredCount: 10 });
  await assertFails(setDoc(plan.refs.attemptRef, plan.attempt));
  await assertFails(setDoc(plan.refs.activityRef, plan.activity));
}

async function ownProfileReadAllowed() {
  await seedUser('uid-a');
  await assertSucceeds(getDoc(doc(authDb('uid-a'), 'users', 'uid-a')));
}

async function defaultDenyUnknownPath() {
  await assertFails(getDoc(doc(authDb('uid-a'), 'privateAuditProbe', 'doc-a')));
  await assertFails(setDoc(doc(authDb('uid-a'), 'privateAuditProbe', 'doc-a'), {
    value: true,
  }));
}

async function otherProfileReadDenied() {
  await seedUser('uid-a');
  await seedUser('uid-b');
  await assertFails(getDoc(doc(authDb('uid-a'), 'users', 'uid-b')));
}

async function otherProfileWriteDenied() {
  await seedUser('uid-a');
  await seedUser('uid-b');
  await assertFails(updateDoc(doc(authDb('uid-a'), 'users', 'uid-b'), {
    username: 'intruso',
    updatedAt: serverTimestamp(),
  }));
}

async function unauthenticatedProfileWritesDenied() {
  await seedUser('uid-a');
  await assertFails(updateDoc(doc(unauthDb(), 'users', 'uid-a'), {
    username: 'intruso',
    updatedAt: serverTimestamp(),
  }));
  await assertFails(setDoc(doc(unauthDb(), 'users', 'uid-new'), {
    username: 'Anonimo',
    usernameNormalized: 'anonimo',
    email: 'anonimo@example.com',
    role: 'user',
    totalPoints: 0,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  }));
}

async function unauthenticatedProgressReadDenied() {
  await seedProgress('uid-a');
  await assertFails(getDoc(doc(unauthDb(), 'users', 'uid-a', 'categoryProgress', categoryId)));
}

async function roleEscalationDenied() {
  await seedUser('uid-a');
  await assertFails(updateDoc(doc(authDb('uid-a'), 'users', 'uid-a'), {
    role: 'admin',
    updatedAt: serverTimestamp(),
  }));
  await assertFails(setDoc(doc(authDb('uid-a'), 'users', 'uid-a'), {
    role: 'admin',
    updatedAt: serverTimestamp(),
  }, { merge: true }));
}

async function privilegedRoleVariantsDenied() {
  await seedUser('uid-a');
  for (const role of ['ADMIN', 'Admin', 'administrator', 'moderator']) {
    await assertFails(updateDoc(doc(authDb('uid-a'), 'users', 'uid-a'), {
      role,
      updatedAt: serverTimestamp(),
    }));
  }
}

async function adminProfileCreationDenied() {
  const firestore = authDb('uid-a');
  const batch = writeBatch(firestore);
  batch.set(doc(firestore, 'usernames', 'usuarioa'), { uid: 'uid-a' });
  batch.set(doc(firestore, 'users', 'uid-a'), {
    username: 'UsuarioA',
    usernameNormalized: 'usuarioa',
    email: 'uid-a@example.com',
    role: 'admin',
    totalPoints: 0,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });
  await assertFails(batch.commit());
}

async function manipulatedInitialPointsDenied() {
  const firestore = authDb('uid-a');
  const batch = writeBatch(firestore);
  batch.set(doc(firestore, 'usernames', 'usuarioa'), { uid: 'uid-a' });
  batch.set(doc(firestore, 'users', 'uid-a'), {
    username: 'UsuarioA',
    usernameNormalized: 'usuarioa',
    email: 'uid-a@example.com',
    role: 'user',
    totalPoints: 99999,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });
  await assertFails(batch.commit());
}

async function legacyProfileFirstScoringAllowed() {
  await seedUserWithoutTotalPoints('uid-a');
  await assertFails(updateDoc(doc(authDb('uid-a'), 'users', 'uid-a'), {
    totalPoints: 50,
    updatedAt: serverTimestamp(),
  }));
}

async function totalPointsReductionDenied() {
  await seedUser('uid-a', 100);
  await assertFails(updateDoc(doc(authDb('uid-a'), 'users', 'uid-a'), {
    totalPoints: 50,
    updatedAt: serverTimestamp(),
  }));
}

async function invalidTotalPointsTypeDenied() {
  await seedUser('uid-a', 100);
  await assertFails(updateDoc(doc(authDb('uid-a'), 'users', 'uid-a'), {
    totalPoints: '100',
    updatedAt: serverTimestamp(),
  }));
}

async function unexpectedProfileFieldDenied() {
  await seedUser('uid-a');
  await assertFails(updateDoc(doc(authDb('uid-a'), 'users', 'uid-a'), {
    hackedPoints: 500,
    updatedAt: serverTimestamp(),
  }));
}

async function negativeActivityPointsDenied() {
  await seedProgress('uid-a');
  await assertFails(setDoc(
    doc(authDb('uid-a'), 'users', 'uid-a', 'categoryProgress', categoryId, 'activities', activityId),
    activityProgressData({
      activityPoints: -1,
      lastAttemptAt: serverTimestamp(),
      completedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }),
  ));
}

async function legacyQuestionScoresFieldDenied() {
  await seedProgress('uid-a');
  await assertFails(setDoc(
    doc(authDb('uid-a'), 'users', 'uid-a', 'categoryProgress', categoryId, 'activities', activityId),
    { ...reservationProgressData('attempt_1', 1), questionScores: {} },
  ));
}

async function legacyExistingProgressReservationDenied() {
  await seedProgress('uid-a');
  const completedAt = Timestamp.fromDate(new Date('2026-09-02T00:00:00Z'));
  const questionScores = Object.fromEntries(Array.from({ length: 10 }, (_, index) => {
    const questionId = `q${String(index + 1).padStart(2, '0')}`;
    return [questionId, { questionId, awardedAttempt: 1, pointsAwarded: 10 }];
  }));
  const firestore = authDb('uid-a');
  const progressRef = activityProgressRef(firestore);
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(activityProgressRef(context.firestore()), {
      activityId,
      status: 'completed',
      attemptCount: 1,
      activityPoints: 100,
      questionScores,
      bestCorrectAnswers: 10,
      bestTotalQuestions: 10,
      bestPercentage: 100,
      lastAttemptAt: completedAt,
      completedAt,
      updatedAt: completedAt,
    });
  });
  await assertSucceeds(getDoc(progressRef));

  // The current client uses merge:true, so the legacy field remains present.
  await assertFails(runTransaction(firestore, async (transaction) => {
    const snapshot = await transaction.get(progressRef);
    if (!snapshot.exists()) throw new Error('Expected legacy progress.');
    transaction.set(progressRef, {
      ...reservationProgressData('attempt_2', 2),
      activityPoints: 100,
      bestCorrectAnswers: 10,
      bestTotalQuestions: 10,
      bestPercentage: 100,
      lastAttemptAt: completedAt,
      completedAt,
      scoredAt10QuestionIds: Object.keys(questionScores),
    }, { merge: true });
  }));

  // Replacing the document cannot bypass the old resource's missing sets.
  await assertFails(setDoc(progressRef, {
    ...reservationProgressData('attempt_2', 2),
    activityPoints: 100,
    bestCorrectAnswers: 10,
    bestTotalQuestions: 10,
    bestPercentage: 100,
    lastAttemptAt: completedAt,
    completedAt,
    scoredAt10QuestionIds: Object.keys(questionScores),
  }));
}

async function migratedProgressReservesWithoutDoubleAward() {
  const rewardedIds = ['q01'];
  const completedAt = Timestamp.fromDate(new Date('2026-09-02T00:00:00Z'));
  await seedActivity('uid-a', {
    status: 'completed',
    attemptCount: 2,
    activityPoints: 10,
    scoredAt10QuestionIds: rewardedIds,
    bestCorrectAnswers: 1,
    bestTotalQuestions: 10,
    bestPercentage: 10,
    lastAttemptAt: completedAt,
    completedAt,
  });
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await updateDoc(doc(db, 'users', 'uid-a'), { totalPoints: 10 });
    await updateDoc(doc(db, 'leaderboard', 'uid-a'), { totalPoints: 10 });
    await updateDoc(doc(db, 'users', 'uid-a', 'categoryProgress', categoryId), {
      completedActivityIds: [activityId],
    });
  });
  const firestore = authDb('uid-a');
  const reservationId = 'attempt_3_after_migration';
  await assertSucceeds(updateDoc(activityProgressRef(firestore), {
    attemptCount: 3,
    status: 'inProgress',
    activeAttempt: activeAttempt(reservationId, 3),
    updatedAt: serverTimestamp(),
  }));
  const submission = answerSubmissionData({
    attemptId: reservationId,
    attemptNumber: 3,
    correctCount: 1,
    previousScores: { q01: { pointsAwarded: 10 } },
  });
  await assertSucceeds(setDoc(
    answerSubmissionRef(firestore, 'uid-a', reservationId), submission));
  const plan = await buildScoringFinalization({
    firestore,
    attemptId: reservationId,
    attemptNumber: 3,
    committedAnswers: submission.answers,
  });
  assert.equal(plan.activity.activityPoints, 10);
  assert.equal(plan.user.totalPoints, 10);
  await assertSucceeds(commitScoringFinalization(firestore, plan));
  const [activityAfter, userAfter, leaderboardAfter] = await Promise.all([
    getDoc(activityProgressRef(firestore)),
    getDoc(doc(firestore, 'users', 'uid-a')),
    getDoc(doc(firestore, 'leaderboard', 'uid-a')),
  ]);
  assert.equal(activityAfter.data().activityPoints, 10);
  assert.equal(userAfter.data().totalPoints, 10);
  assert.equal(leaderboardAfter.data().totalPoints, 10);
}

async function invalidAttemptNumberDenied() {
  await seedActivity('uid-a');
  await assertFails(setDoc(
    activityAttemptRef(authDb('uid-a'), 'uid-a', 'attempt_bad'),
    activityAttemptData({ attemptNumber: 0 }),
  ));
}

async function clientEarnedPointsDenied() {
  const { firestore, plan } = await prepareAttempt({ attemptNumber: 4 });
  plan.attempt.earnedPoints = 10;
  await assertFails(setDoc(
    plan.refs.attemptRef,
    plan.attempt,
  ));
}

async function invalidPercentageDenied() {
  await seedActivity('uid-a');
  await assertFails(setDoc(
    activityAttemptRef(authDb('uid-a'), 'uid-a', 'attempt_bad'),
    activityAttemptData({ percentage: 150 }),
  ));
}

async function correctAboveTotalDenied() {
  await seedActivity('uid-a');
  await assertFails(setDoc(
    activityAttemptRef(authDb('uid-a'), 'uid-a', 'attempt_bad'),
    activityAttemptData({ correctAnswers: 11, totalQuestions: 10 }),
  ));
}

async function crossUserProgressWritesDenied() {
  await seedActivity('uid-b');
  await assertFails(setDoc(
    doc(authDb('uid-a'), 'users', 'uid-b', 'categoryProgress', categoryId),
    progressData({
      viewedLessonPageIds: ['page_01'],
      startedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }),
  ));
  await assertFails(setDoc(
    activityAttemptRef(authDb('uid-a'), 'uid-b', 'attempt_cross_user'),
    activityAttemptData(),
  ));
}

async function historicalAttemptUpdateDenied() {
  await seedAttempt('uid-a');
  await assertFails(updateDoc(activityAttemptRef(authDb('uid-a'), 'uid-a', 'attempt_1'), {
    percentage: 100,
  }));
}

async function attemptDeleteDenied() {
  await seedAttempt('uid-a');
  await assertFails(deleteDoc(activityAttemptRef(authDb('uid-a'), 'uid-a', 'attempt_1')));
}

async function progressDeleteDenied() {
  await seedProgress('uid-a');
  await assertFails(deleteDoc(doc(authDb('uid-a'), 'users', 'uid-a', 'categoryProgress', categoryId)));
}

async function contentWriteDenied() {
  await seedContent();
  await assertFails(updateDoc(doc(authDb('uid-a'), 'categories', categoryId, 'questions', 'q01'), {
    correctAnswer: 'manipulada',
  }));
}

async function contentReadAllowed() {
  await seedContent();
  await assertSucceeds(getDoc(doc(authDb('uid-a'), 'categories', categoryId, 'questions', 'q01')));
}

async function contentQueryAllowed() {
  await seedContent();
  const questions = query(
    collection(authDb('uid-a'), 'categories', categoryId, 'questions'),
    where('activityId', '==', activityId),
    orderBy('activityId'),
  );
  await assertSucceeds(getDocs(questions));
}

async function answerKeyProtected() {
  await seedActivity('uid-a');
  const firestore = authDb('uid-a');
  const keyRef = answerKeyRef(firestore);
  await assertFails(getDoc(keyRef));
  await assertFails(setDoc(keyRef, answerKeyData()));
  await assertFails(updateDoc(keyRef, { questions: [] }));
  await assertFails(deleteDoc(keyRef));
  await assertFails(getDoc(answerKeyRef(unauthDb())));
}

async function validAnswerSubmission() {
  await seedActivity('uid-a');
  await setActiveReservation('uid-a');
  const firestore = authDb('uid-a');
  const submissionRef = answerSubmissionRef(firestore, 'uid-a');
  await assertSucceeds(setDoc(submissionRef, answerSubmissionData()));
  await assertFails(setDoc(submissionRef, answerSubmissionData()));
  await assertFails(updateDoc(submissionRef, { answers: [] }));
  await assertFails(deleteDoc(submissionRef));
}

async function invalidAnswerSubmissionIdentityDenied() {
  await seedActivity('uid-a');
  await seedActivity('uid-b');
  await setActiveReservation('uid-a', 'reserved_A', 1);
  await setActiveReservation('uid-b', 'reserved_B', 3);
  await assertFails(setDoc(
    answerSubmissionRef(authDb('uid-b'), 'uid-b'),
    answerSubmissionData({ attemptId: 'attempt_1' }),
  ));
  await assertFails(setDoc(
    answerSubmissionRef(authDb('uid-a'), 'uid-a', 'reserved_B'),
    answerSubmissionData({ attemptId: 'reserved_B', attemptNumber: 1 }),
  ));
  await assertFails(setDoc(
    answerSubmissionRef(authDb('uid-a'), 'uid-a', 'reserved_A'),
    answerSubmissionData({ attemptId: 'reserved_A', attemptNumber: 3 }),
  ));
}

async function alteredAnswerQuestionIdsDenied() {
  await seedActivity('uid-a');
  await setActiveReservation('uid-a');
  const answers = { ...answerSubmissionData().answers };
  delete answers.q02;
  answers.q11 = 'correct';
  await assertFails(setDoc(
    answerSubmissionRef(authDb('uid-a'), 'uid-a'),
    answerSubmissionData({ answers }),
  ));
}

async function invalidAnswerSubmissionSizeDenied() {
  for (const size of [9, 11]) {
    await testEnv.clearFirestore();
    await seedActivity('uid-a');
    await setActiveReservation('uid-a');
    const answers = { ...answerSubmissionData().answers };
    if (size === 9) delete answers.q10;
    if (size === 11) answers.q11 = 'correct';
    await assertFails(setDoc(
      answerSubmissionRef(authDb('uid-a'), 'uid-a'),
      answerSubmissionData({ answers }),
    ));
  }
}

async function committedAnswerResultsValidated() {
  await seedActivity('uid-a');
  await setActiveReservation('uid-a');
  const firestore = authDb('uid-a');
  const committed = answerSubmissionData({ correctCount: 5 });
  await assertSucceeds(setDoc(
    answerSubmissionRef(firestore, 'uid-a'),
    committed,
  ));
  const plan = await buildScoringFinalization({
    firestore,
    committedAnswers: committed.answers,
  });
  await assertSucceeds(commitScoringFinalization(firestore, plan));
}

async function committedAnswerOracleBlocked() {
  await seedActivity('uid-a');
  await setActiveReservation('uid-a');
  const firestore = authDb('uid-a');
  const submissionRef = answerSubmissionRef(firestore, 'uid-a');
  const committed = answerSubmissionData({ correctCount: 4 });
  await assertSucceeds(setDoc(
    submissionRef,
    committed,
  ));

  const forgedPlan = await buildScoringFinalization({
    firestore,
    committedAnswers: committed.answers,
  });
  forgedPlan.attempt.correct[4] = true;
  forgedPlan.attempt.correctAnswers = 5;
  forgedPlan.attempt.percentage = 50;
  await assertFails(commitScoringFinalization(firestore, forgedPlan));
  await assertFails(updateDoc(submissionRef, {
    answers: answerSubmissionData({ correctCount: 5 }).answers,
  }));
}

async function ownTheoryAllowedOtherDenied() {
  await seedUser('uid-a');
  await seedUser('uid-b');
  await assertSucceeds(setDoc(
    doc(authDb('uid-a'), 'users', 'uid-a', 'categoryProgress', categoryId),
    {
      categoryId,
      lessonId,
      status: 'inProgress',
      viewedLessonPageIds: ['page_01'],
      completedActivityIds: [],
      totalLessonPages: 4,
      totalActivities: 6,
      startedAt: serverTimestamp(),
      lastActivityAt: null,
      completedAt: null,
      updatedAt: serverTimestamp(),
    },
  ));
  await assertFails(updateDoc(doc(authDb('uid-b'), 'users', 'uid-a', 'categoryProgress', categoryId), {
    viewedLessonPageIds: arrayUnion('page_02'),
    updatedAt: serverTimestamp(),
  }));
}

async function leaderboardReadRules() {
  await seedUser('uid-a', 50);
  await assertSucceeds(getDocs(collection(authDb('uid-a'), 'leaderboard')));
  await assertFails(getDocs(collection(unauthDb(), 'leaderboard')));
}

async function leaderboardOrderedQueryAllowed() {
  await seedUser('uid-a', 50);
  await seedUser('uid-b', 80);
  const orderedRanking = query(
    collection(authDb('uid-a'), 'leaderboard'),
    where('totalPoints', '>', 0),
    orderBy('totalPoints', 'desc'),
  );
  await assertSucceeds(getDocs(orderedRanking));
}

async function leaderboardOtherUserWriteDenied() {
  await seedUser('uid-a', 50);
  await seedUser('uid-b', 40);
  await assertFails(setDoc(doc(authDb('uid-a'), 'leaderboard', 'uid-b'), {
    username: userProfile('uid-b', 40).username,
    totalPoints: 40,
    updatedAt: serverTimestamp(),
  }));
}

async function leaderboardArbitraryPointsDenied() {
  await seedUser('uid-a', 50);
  await assertFails(setDoc(doc(authDb('uid-a'), 'leaderboard', 'uid-a'), {
    username: userProfile('uid-a', 50).username,
    totalPoints: 999999,
    updatedAt: serverTimestamp(),
  }));
}

async function leaderboardMustMatchUserPoints() {
  await seedUser('uid-a', 50);
  await assertFails(setDoc(doc(authDb('uid-a'), 'leaderboard', 'uid-a'), {
    username: userProfile('uid-a', 50).username,
    totalPoints: 51,
    updatedAt: serverTimestamp(),
  }));
}

async function leaderboardMustMatchUsername() {
  await seedUser('uid-a', 50);
  await assertFails(setDoc(doc(authDb('uid-a'), 'leaderboard', 'uid-a'), {
    username: 'otroNombre',
    totalPoints: 50,
    updatedAt: serverTimestamp(),
  }));
}

async function leaderboardPrivateFieldsDenied() {
  await seedUser('uid-a', 50);
  await assertFails(setDoc(doc(authDb('uid-a'), 'leaderboard', 'uid-a'), {
    username: userProfile('uid-a', 50).username,
    totalPoints: 50,
    email: 'uid-a@example.com',
    role: 'user',
    updatedAt: serverTimestamp(),
  }));
}

async function leaderboardPointSyncAllowed() {
  await seedUser('uid-a', 50);
  const firestore = authDb('uid-a');
  const batch = writeBatch(firestore);
  batch.update(doc(firestore, 'users', 'uid-a'), {
    totalPoints: 80,
    updatedAt: serverTimestamp(),
  });
  batch.set(doc(firestore, 'leaderboard', 'uid-a'), {
    username: userProfile('uid-a', 80).username,
    totalPoints: 80,
    updatedAt: serverTimestamp(),
  });
  await assertFails(batch.commit());
}

async function leaderboardLegacyCleanupAllowed() {
  await seedUser('uid-a', 50);
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'leaderboard', 'uid-a'), {
      username: userProfile('uid-a', 50).username,
      totalPoints: 50,
      email: 'uid-a@example.com',
      role: 'user',
      updatedAt: Timestamp.fromDate(new Date('2026-09-01T00:00:00Z')),
    });
  });
  const firestore = authDb('uid-a');
  await assertSucceeds(setDoc(doc(firestore, 'leaderboard', 'uid-a'), {
    username: userProfile('uid-a', 50).username,
    totalPoints: 50,
    updatedAt: serverTimestamp(),
  }));

  const snapshot = await getDoc(doc(firestore, 'leaderboard', 'uid-a'));
  const data = snapshot.data();
  if ('email' in data || 'role' in data) {
    throw new Error('legacy private leaderboard fields were not removed');
  }
}

async function leaderboardUsernameSyncAllowed() {
  await seedUser('uid-a', 50);
  const firestore = authDb('uid-a');
  const batch = writeBatch(firestore);
  batch.set(doc(firestore, 'usernames', 'diegof'), { uid: 'uid-a' });
  batch.update(doc(firestore, 'users', 'uid-a'), {
    username: 'diegof',
    usernameNormalized: 'diegof',
    updatedAt: serverTimestamp(),
  });
  batch.set(doc(firestore, 'leaderboard', 'uid-a'), {
    username: 'diegof',
    totalPoints: 50,
    updatedAt: serverTimestamp(),
  });
  batch.delete(doc(firestore, 'usernames', userProfile('uid-a', 50).usernameNormalized));
  await assertSucceeds(batch.commit());
}

async function ownProgressPreflightReadsAllowed() {
  await seedUser('uid-a');
  const firestore = authDb('uid-a');
  await assertSucceeds(getDoc(doc(firestore, 'users', 'uid-a', 'categoryProgress', categoryId)));
  await assertSucceeds(getDoc(doc(
    firestore,
    'users',
    'uid-a',
    'categoryProgress',
    categoryId,
    'activities',
    activityId,
  )));
  await assertSucceeds(getDoc(activityAttemptRef(firestore, 'uid-a', 'attempt_preflight')));
}

async function manipulatedCommittedCorrectAnswersDenied() {
  await seedActivity('uid-a');
  await setActiveReservation('uid-a');
  const firestore = authDb('uid-a');
  const committed = answerSubmissionData({ correctCount: 5 });
  await assertSucceeds(setDoc(
    answerSubmissionRef(firestore, 'uid-a'),
    committed,
  ));
  const inflated = await buildScoringFinalization({
    firestore,
    committedAnswers: committed.answers,
  });
  inflated.attempt.correctAnswers = 6;
  inflated.attempt.percentage = 60;
  await assertFails(commitScoringFinalization(firestore, inflated));

  await testEnv.clearFirestore();
  await seedActivity('uid-a');
  await setActiveReservation('uid-a');
  const secondFirestore = authDb('uid-a');
  const secondCommitted = answerSubmissionData({ correctCount: 5 });
  await assertSucceeds(setDoc(
    answerSubmissionRef(secondFirestore, 'uid-a'),
    secondCommitted,
  ));
  const falseNegative = await buildScoringFinalization({
    firestore: secondFirestore,
    committedAnswers: secondCommitted.answers,
  });
  falseNegative.attempt.correct[0] = false;
  falseNegative.attempt.correctAnswers = 4;
  falseNegative.attempt.percentage = 40;
  await assertFails(commitScoringFinalization(secondFirestore, falseNegative));
}

async function partialCommittedAttemptAllowed() {
  await seedActivity('uid-a');
  await setActiveReservation('uid-a');
  const firestore = authDb('uid-a');
  await assertSucceeds(setDoc(
    answerSubmissionRef(firestore, 'uid-a'),
    answerSubmissionData({ correctCount: 2, answeredCount: 3 }),
  ));
  const committed = answerSubmissionData({ correctCount: 2, answeredCount: 3 });
  const plan = await buildScoringFinalization({
    firestore,
    committedAnswers: committed.answers,
  });
  await assertSucceeds(commitScoringFinalization(firestore, plan));
}

async function fillBlankCommittedVariantAllowed() {
  await seedActivity('uid-a');
  const textAnswerKey = answerKeyData();
  textAnswerKey.correctAnswersByQuestionId.q10 = 'sextorsión';
  textAnswerKey.acceptedAnswersByQuestionId.q10 = ['sextorsión', 'sextorsion'];
  textAnswerKey.fillBlankQuestionIds = ['q10'];
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(answerKeyRef(context.firestore()), textAnswerKey);
  });
  await setActiveReservation('uid-a');
  const firestore = authDb('uid-a');
  const committedAnswers = answerSubmissionData({ correctCount: 5 }).answers;
  committedAnswers.q10 = ' Sextorsion ';
  const committed = answerSubmissionData({ answers: committedAnswers, key: textAnswerKey });
  await assertSucceeds(setDoc(
    answerSubmissionRef(firestore, 'uid-a'),
    committed,
  ));
  const plan = await buildScoringFinalization({
    firestore,
    committedAnswers,
    key: textAnswerKey,
  });
  await assertSucceeds(commitScoringFinalization(firestore, plan));
}

async function legitimateScoringFlowAllowed() {
  await seedActivity('uid-a');
  const firestore = authDb('uid-a');
  const progressRef = activityProgressRef(firestore);
  const reservationId = 'attempt_reserved_2';
  await updateDoc(progressRef, {
    attemptCount: 2,
    status: 'inProgress',
    activeAttempt: activeAttempt(reservationId, 2),
    updatedAt: serverTimestamp(),
  });
  const committed = answerSubmissionData({
    attemptId: reservationId,
    attemptNumber: 2,
    correctCount: 5,
  });
  await assertSucceeds(setDoc(
    answerSubmissionRef(firestore, 'uid-a', reservationId),
    committed,
  ));
  const plan = await buildScoringFinalization({
    firestore,
    attemptId: reservationId,
    attemptNumber: 2,
    committedAnswers: committed.answers,
  });
  await assertSucceeds(commitScoringFinalization(firestore, plan));
}

async function validSequentialAttemptReservations() {
  await seedProgress('uid-a');
  await seedAnswerKey();
  const firestore = authDb('uid-a');
  const progressRef = activityProgressRef(firestore);

  await assertSucceeds(setDoc(progressRef, reservationProgressData('attempt_1', 1)));
  await assertSucceeds(setDoc(
    answerSubmissionRef(firestore, 'uid-a', 'attempt_1'),
    answerSubmissionData({ attemptId: 'attempt_1', attemptNumber: 1 }),
  ));
  const committed = answerSubmissionData({ attemptId: 'attempt_1', attemptNumber: 1 });
  const plan = await buildScoringFinalization({
    firestore,
    attemptId: 'attempt_1',
    attemptNumber: 1,
    committedAnswers: committed.answers,
  });
  await assertSucceeds(commitScoringFinalization(firestore, plan));

  await assertSucceeds(updateDoc(progressRef, {
    attemptCount: 2,
    status: 'inProgress',
    activeAttempt: activeAttempt('attempt_2', 2),
    updatedAt: serverTimestamp(),
  }));
}

async function realisticTraffickingFirstReservationAllowed() {
  const uid = 'uid-a';
  const realCategoryId = 'trafficking_fundamentals';
  const realActivityId = 'trafficking_fundamentals_activity_01';
  await seedUser(uid, 560);
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'users', uid, 'categoryProgress', realCategoryId),
      {
        ...progressData(),
        categoryId: realCategoryId,
        lessonId: realCategoryId,
        totalLessonPages: 6,
        viewedLessonPageIds: Array.from({ length: 6 }, (_, index) =>
          `trafficking_fundamentals_lesson_0${index + 1}`),
      },
    );
  });
  const firestore = authDb(uid);
  const progressRef = doc(firestore, 'users', uid, 'categoryProgress', realCategoryId,
    'activities', realActivityId);
  await assertSucceeds(runTransaction(firestore, async (transaction) => {
    const snapshot = await transaction.get(progressRef);
    if (snapshot.exists()) throw new Error('Expected a new activity progress document.');
    transaction.set(progressRef, {
      activityId: realActivityId,
      status: 'inProgress',
      attemptCount: 1,
      bestCorrectAnswers: 0,
      bestTotalQuestions: 0,
      bestPercentage: 0,
      lastAttemptAt: null,
      completedAt: null,
      updatedAt: serverTimestamp(),
      activeAttempt: {
        attemptId: 'first_attempt',
        attemptNumber: 1,
        reservedAt: serverTimestamp(),
        pointValue: 10,
      },
      activityPoints: 0,
      scoredAt10QuestionIds: [],
      scoredAt5QuestionIds: [],
      scoredAt1QuestionIds: [],
    }, { merge: true });
  }));
}

async function invalidAttemptReservationNumbersDenied() {
  await seedActivity('uid-a');
  const firestore = authDb('uid-a');
  const progressRef = activityProgressRef(firestore);
  for (const attemptNumber of [1, 5]) {
    await assertFails(updateDoc(progressRef, {
      attemptCount: attemptNumber,
      status: 'inProgress',
      activeAttempt: activeAttempt(`attempt_${attemptNumber}`, attemptNumber),
      updatedAt: serverTimestamp(),
    }));
  }
}

async function invalidAttemptReservationDeltasDenied() {
  await seedActivity('uid-a');
  const firestore = authDb('uid-a');
  const progressRef = activityProgressRef(firestore);
  for (const [attemptCount, activeNumber] of [[1, 1], [7, 7]]) {
    await assertFails(updateDoc(progressRef, {
      attemptCount,
      status: 'inProgress',
      activeAttempt: activeAttempt(`attempt_${attemptCount}`, activeNumber),
      updatedAt: serverTimestamp(),
    }));
  }
}

async function activeAttemptReservationImmutable() {
  await seedActivity('uid-a');
  const firestore = authDb('uid-a');
  const progressRef = activityProgressRef(firestore);
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await updateDoc(activityProgressRef(context.firestore()), {
      status: 'inProgress',
      activeAttempt: activeAttempt('attempt_A', 1,
        Timestamp.fromDate(new Date('2026-09-03T00:00:00Z'))),
    });
  });
  await assertFails(updateDoc(progressRef, {
    attemptCount: 2,
    activeAttempt: activeAttempt('attempt_B', 2),
    updatedAt: serverTimestamp(),
  }));
}

async function secondActiveAttemptDenied() {
  await activeAttemptReservationImmutable();
}

async function otherUserAttemptReservationDenied() {
  await seedActivity('uid-a');
  await seedUser('uid-b');
  await assertFails(updateDoc(activityProgressRef(authDb('uid-b'), 'uid-a'), {
    attemptCount: 2,
    activeAttempt: activeAttempt('attempt_b', 2),
    updatedAt: serverTimestamp(),
  }));
}

async function unauthenticatedAttemptReservationDenied() {
  await seedActivity('uid-a');
  await assertFails(updateDoc(activityProgressRef(unauthDb()), {
    attemptCount: 2,
    activeAttempt: activeAttempt('attempt_2', 2),
    updatedAt: serverTimestamp(),
  }));
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(async () => {
    if (testEnv) {
      await testEnv.cleanup();
    }
  });
