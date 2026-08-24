const fs = require('node:fs');
const path = require('node:path');
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  serverTimestamp,
  setDoc,
  Timestamp,
  updateDoc,
} = require('firebase/firestore');

const projectId = 'demo-yomecuido-rules';
const rulesPath = path.resolve(__dirname, '../../firestore.rules');

function profileData(email = 'a@example.com') {
  return {
    email,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  };
}

function seededProfileData(email = 'a@example.com') {
  return {
    email,
    createdAt: Timestamp.fromDate(new Date('2026-08-21T20:00:00Z')),
    updatedAt: Timestamp.fromDate(new Date('2026-08-21T20:00:00Z')),
  };
}

function progressData(categoryId = 'relations_violence_digital') {
  return {
    categoryId,
    lessonId: 'relations_violence',
    status: 'inProgress',
    viewedLessonPageIds: ['what_is_digital_violence'],
    completedActivityIds: [],
    correctAnswers: 0,
    totalLessonPages: 4,
    totalActivities: 12,
    attemptCount: 0,
    startedAt: serverTimestamp(),
    lastActivityAt: null,
    completedAt: null,
    updatedAt: serverTimestamp(),
    latestAnswers: {},
  };
}

function seededProgressData(categoryId = 'relations_violence_digital') {
  return {
    categoryId,
    lessonId: 'relations_violence',
    status: 'inProgress',
    viewedLessonPageIds: ['what_is_digital_violence'],
    completedActivityIds: [],
    correctAnswers: 0,
    totalLessonPages: 4,
    totalActivities: 12,
    attemptCount: 1,
    startedAt: Timestamp.fromDate(new Date('2026-08-21T20:00:00Z')),
    lastActivityAt: null,
    completedAt: null,
    updatedAt: Timestamp.fromDate(new Date('2026-08-21T20:00:00Z')),
    latestAnswers: {},
  };
}

async function seed(testEnv, writer) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await writer(context.firestore());
  });
}

async function runTest(name, fn) {
  try {
    await fn();
    console.log(`ok - ${name}`);
  } catch (error) {
    console.error(`not ok - ${name}`);
    console.error(error);
    process.exitCode = 1;
  }
}

(async () => {
  const testEnv = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: fs.readFileSync(rulesPath, 'utf8'),
    },
  });

  const authedA = () =>
    testEnv.authenticatedContext('userA', { email: 'a@example.com' })
      .firestore();
  const authedB = () =>
    testEnv.authenticatedContext('userB', { email: 'b@example.com' })
      .firestore();
  const unauth = () => testEnv.unauthenticatedContext().firestore();

  await runTest('Usuario A crea su propio perfil', async () => {
    await testEnv.clearFirestore();
    await assertSucceeds(setDoc(doc(authedA(), 'users/userA'), profileData()));
  });

  await runTest('Usuario A lee su propio perfil', async () => {
    await testEnv.clearFirestore();
    await seed(testEnv, (db) =>
      setDoc(doc(db, 'users/userA'), seededProfileData())
    );
    await assertSucceeds(getDoc(doc(authedA(), 'users/userA')));
  });

  await runTest('Usuario A actualiza campos permitidos de su perfil', async () => {
    await testEnv.clearFirestore();
    await seed(testEnv, (db) =>
      setDoc(doc(db, 'users/userA'), seededProfileData())
    );
    await assertSucceeds(
      updateDoc(doc(authedA(), 'users/userA'), {
        updatedAt: serverTimestamp(),
      })
    );
  });

  await runTest('Sin autenticacion no lee perfil', async () => {
    await testEnv.clearFirestore();
    await seed(testEnv, (db) =>
      setDoc(doc(db, 'users/userA'), seededProfileData())
    );
    await assertFails(getDoc(doc(unauth(), 'users/userA')));
  });

  await runTest('Usuario A no lee ni modifica perfil B', async () => {
    await testEnv.clearFirestore();
    await seed(testEnv, (db) =>
      setDoc(doc(db, 'users/userB'), seededProfileData('b@example.com'))
    );
    await assertFails(getDoc(doc(authedA(), 'users/userB')));
    await assertFails(
      updateDoc(doc(authedA(), 'users/userB'), {
        updatedAt: serverTimestamp(),
      })
    );
  });

  await runTest('Usuario A no crea perfil bajo UID ajeno', async () => {
    await testEnv.clearFirestore();
    await assertFails(
      setDoc(doc(authedA(), 'users/userB'), profileData('a@example.com'))
    );
  });

  await runTest('Perfil rechaza createdAt modificado y campos arbitrarios', async () => {
    await testEnv.clearFirestore();
    await seed(testEnv, (db) =>
      setDoc(doc(db, 'users/userA'), seededProfileData())
    );
    await assertFails(
      updateDoc(doc(authedA(), 'users/userA'), {
        createdAt: Timestamp.fromDate(new Date('2027-01-01T00:00:00Z')),
        updatedAt: serverTimestamp(),
      })
    );
    await assertFails(
      updateDoc(doc(authedA(), 'users/userA'), {
        role: 'admin',
        updatedAt: serverTimestamp(),
      })
    );
  });

  await runTest('Usuario A crea, lee, lista y actualiza su progreso', async () => {
    await testEnv.clearFirestore();
    await seed(testEnv, (db) =>
      setDoc(doc(db, 'users/userA'), seededProfileData())
    );
    const progressRef = doc(
      authedA(),
      'users/userA/categoryProgress/relations_violence_digital'
    );
    await assertSucceeds(setDoc(progressRef, progressData()));
    await assertSucceeds(getDoc(progressRef));
    await assertSucceeds(getDocs(collection(authedA(), 'users/userA/categoryProgress')));
    await assertSucceeds(
      updateDoc(progressRef, {
        status: 'inProgress',
        completedActivityIds: ['activity_1'],
        correctAnswers: 1,
        lastActivityAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
        latestAnswers: {
          activity_1: {
            answer: 'safe_action',
            isCorrect: true,
            answeredAt: serverTimestamp(),
          },
        },
      })
    );
  });

  await runTest('Usuario A no accede al progreso B', async () => {
    await testEnv.clearFirestore();
    await seed(testEnv, async (db) => {
      await setDoc(doc(db, 'users/userB'), seededProfileData('b@example.com'));
      await setDoc(
        doc(db, 'users/userB/categoryProgress/category1'),
        seededProgressData('category1')
      );
    });
    await assertFails(getDoc(doc(authedA(), 'users/userB/categoryProgress/category1')));
    await assertFails(
      setDoc(
        doc(authedA(), 'users/userB/categoryProgress/category1'),
        progressData('category1')
      )
    );
  });

  await runTest('Progreso rechaza datos invalidos', async () => {
    await testEnv.clearFirestore();
    await seed(testEnv, (db) =>
      setDoc(doc(db, 'users/userA'), seededProfileData())
    );
    await assertFails(
      setDoc(
        doc(authedA(), 'users/userA/categoryProgress/cat_a'),
        progressData('cat_b')
      )
    );
    await assertFails(
      setDoc(doc(authedA(), 'users/userA/categoryProgress/cat_a'), {
        ...progressData('cat_a'),
        status: 'superCompleted',
      })
    );
    await assertFails(
      setDoc(doc(authedA(), 'users/userA/categoryProgress/cat_a'), {
        ...progressData('cat_a'),
        correctAnswers: -1,
      })
    );
    await assertFails(
      setDoc(doc(authedA(), 'users/userA/categoryProgress/cat_a'), {
        ...progressData('cat_a'),
        extra: true,
      })
    );
    await assertFails(
      setDoc(doc(authedA(), 'users/userA/categoryProgress/cat_a'), {
        ...progressData('cat_a'),
        completedActivityIds: [],
        latestAnswers: {
          activity_1: {
            answer: 'safe_action',
            isCorrect: true,
            answeredAt: serverTimestamp(),
          },
        },
      })
    );
  });

  await runTest('Progreso rechaza startedAt modificado, attemptCount menor y delete', async () => {
    await testEnv.clearFirestore();
    await seed(testEnv, async (db) => {
      await setDoc(doc(db, 'users/userA'), seededProfileData());
      await setDoc(
        doc(db, 'users/userA/categoryProgress/cat_a'),
        seededProgressData('cat_a')
      );
    });
    const progressRef = doc(authedA(), 'users/userA/categoryProgress/cat_a');
    await assertFails(
      updateDoc(progressRef, {
        startedAt: Timestamp.fromDate(new Date('2027-01-01T00:00:00Z')),
        updatedAt: serverTimestamp(),
      })
    );
    await assertFails(
      updateDoc(progressRef, {
        attemptCount: 0,
        updatedAt: serverTimestamp(),
      })
    );
    await assertFails(deleteDoc(progressRef));
  });

  await testEnv.cleanup();
  if (process.exitCode) {
    process.exit(process.exitCode);
  }
})();
