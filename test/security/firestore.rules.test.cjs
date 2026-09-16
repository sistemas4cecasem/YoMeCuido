const fs = require('node:fs');
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
    ['usuario A puede leer su perfil', ownProfileReadAllowed],
    ['usuario A no puede leer perfil de B', otherProfileReadDenied],
    ['usuario A no puede modificar perfil de B', otherProfileWriteDenied],
    ['usuario no autenticado no lee progreso', unauthenticatedProgressReadDenied],
    ['usuario normal no puede escalar rol', roleEscalationDenied],
    ['creación de perfil admin denegada', adminProfileCreationDenied],
    ['totalPoints inicial manipulado denegado', manipulatedInitialPointsDenied],
    ['perfil antiguo puede recibir primera puntuación', legacyProfileFirstScoringAllowed],
    ['reducción de totalPoints denegada', totalPointsReductionDenied],
    ['tipo inválido en totalPoints denegado', invalidTotalPointsTypeDenied],
    ['campo inesperado en perfil denegado', unexpectedProfileFieldDenied],
    ['activityPoints negativo denegado', negativeActivityPointsDenied],
    ['questionScores inválido denegado', invalidQuestionScoresDenied],
    ['attemptNumber inválido denegado', invalidAttemptNumberDenied],
    ['intento 4 con puntos denegado', fourthAttemptWithPointsDenied],
    ['porcentaje inválido denegado', invalidPercentageDenied],
    ['correctas superiores al total denegadas', correctAboveTotalDenied],
    ['modificar intento histórico denegado', historicalAttemptUpdateDenied],
    ['eliminar intento denegado', attemptDeleteDenied],
    ['eliminar progreso denegado', progressDeleteDenied],
    ['usuario normal no modifica contenido educativo', contentWriteDenied],
    ['contenido educativo legible para autenticados', contentReadAllowed],
    ['query de contenido educativo permitida', contentQueryAllowed],
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
  ];

  for (const [name, fn] of tests) {
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

async function seedActivity(uid = 'uid-a') {
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
      activityProgressData(),
    );
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
    status: 'completed',
    attemptCount: 1,
    activityPoints: 50,
    questionScores: {
      q01: { questionId: 'q01', pointsAwarded: 10, awardedAttempt: 1 },
    },
    bestCorrectAnswers: 5,
    bestTotalQuestions: 10,
    bestPercentage: 50,
    lastAttemptAt: Timestamp.fromDate(new Date('2026-09-02T00:00:00Z')),
    completedAt: Timestamp.fromDate(new Date('2026-09-02T00:00:00Z')),
    updatedAt: Timestamp.fromDate(new Date('2026-09-02T00:00:00Z')),
    ...overrides,
  };
}

function activityAttemptData(overrides = {}) {
  return {
    type: 'activity',
    attemptNumber: 1,
    categoryId,
    activityId,
    examId: null,
    questionIds: questionIds(),
    answers: answersByQuestionId(5),
    correctAnswers: 5,
    totalQuestions: 10,
    percentage: 50,
    earnedPoints: 50,
    startedAt: Timestamp.fromDate(new Date('2026-09-02T00:00:00Z')),
    completedAt: serverTimestamp(),
    ...overrides,
  };
}

function questionIds() {
  return Array.from({ length: 10 }, (_, index) => `q${String(index + 1).padStart(2, '0')}`);
}

function answersByQuestionId(correctCount) {
  return Object.fromEntries(
    questionIds().map((questionId, index) => [
      questionId,
      {
        questionId,
        answer: index < correctCount ? 'correct' : 'incorrect',
        isCorrect: index < correctCount,
        pointsEarned: index < correctCount ? 10 : 0,
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

async function ownProfileReadAllowed() {
  await seedUser('uid-a');
  await assertSucceeds(getDoc(doc(authDb('uid-a'), 'users', 'uid-a')));
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
  await assertSucceeds(updateDoc(doc(authDb('uid-a'), 'users', 'uid-a'), {
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

async function invalidQuestionScoresDenied() {
  await seedProgress('uid-a');
  await assertFails(setDoc(
    doc(authDb('uid-a'), 'users', 'uid-a', 'categoryProgress', categoryId, 'activities', activityId),
    activityProgressData({
      activityPoints: 500,
      questionScores: {
        q01: { questionId: 'q01', pointsAwarded: 500, awardedAttempt: 1 },
      },
      lastAttemptAt: serverTimestamp(),
      completedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }),
  ));
}

async function invalidAttemptNumberDenied() {
  await seedActivity('uid-a');
  await assertFails(setDoc(
    activityAttemptRef(authDb('uid-a'), 'uid-a', 'attempt_bad'),
    activityAttemptData({ attemptNumber: 0 }),
  ));
}

async function fourthAttemptWithPointsDenied() {
  await seedActivity('uid-a');
  await assertFails(setDoc(
    activityAttemptRef(authDb('uid-a'), 'uid-a', 'attempt_bad'),
    activityAttemptData({ attemptNumber: 4, earnedPoints: 10 }),
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
  await assertSucceeds(batch.commit());
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
  await assertSucceeds(batch.commit());

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

async function legitimateScoringFlowAllowed() {
  await seedUser('uid-a');
  await seedProgress('uid-a');
  const firestore = authDb('uid-a');
  const batch = writeBatch(firestore);
  batch.update(doc(firestore, 'users', 'uid-a'), {
    totalPoints: 50,
    updatedAt: serverTimestamp(),
  });
  batch.update(doc(firestore, 'users', 'uid-a', 'categoryProgress', categoryId), {
    completedActivityIds: arrayUnion(activityId),
    lastActivityAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });
  batch.set(
    doc(firestore, 'users', 'uid-a', 'categoryProgress', categoryId, 'activities', activityId),
    {
      ...activityProgressData(),
      lastAttemptAt: serverTimestamp(),
      completedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    },
  );
  batch.set(activityAttemptRef(firestore, 'uid-a', 'attempt_legit'), activityAttemptData());
  await assertSucceeds(batch.commit());
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
