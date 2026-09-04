const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { doc, setDoc, getDoc, getDocs, collection, deleteDoc, updateDoc,
  writeBatch, serverTimestamp, Timestamp, runTransaction } = require('firebase/firestore');

const projectId = 'demo-yomecuido-usernames';
const fields = (username, uid) => ({ username, usernameNormalized: username.toLowerCase(),
  email: `${uid}@example.com`, role: 'user', createdAt: serverTimestamp(), updatedAt: serverTimestamp() });

async function main() {
  const env = await initializeTestEnvironment({ projectId, firestore: {
    rules: fs.readFileSync(path.resolve(__dirname, '../../firestore.rules'), 'utf8'),
  }});
  const a = env.authenticatedContext('alice', { email: 'alice@example.com' }).firestore();
  const b = env.authenticatedContext('bob', { email: 'bob@example.com' }).firestore();
  const create = (db, uid, name) => {
    const batch = writeBatch(db);
    batch.set(doc(db, 'users', uid), fields(name, uid));
    batch.set(doc(db, 'usernames', name.toLowerCase()), { uid });
    return batch.commit();
  };
  const rename = (db, uid, name) => runTransaction(db, async tx => {
    const profile = doc(db, 'users', uid);
    const old = (await tx.get(profile)).data().usernameNormalized;
    const next = name.toLowerCase();
    const reservation = doc(db, 'usernames', next);
    const occupied = await tx.get(reservation);
    if (occupied.exists() && occupied.data().uid !== uid) throw new Error('occupied');
    if (!occupied.exists()) tx.set(reservation, { uid });
    tx.update(profile, { username: name, usernameNormalized: next, updatedAt: serverTimestamp() });
    if (old !== next) tx.delete(doc(db, 'usernames', old));
  });
  let passed = 0;
  async function test(name, fn) {
    await env.clearFirestore();
    await create(a, 'alice', 'Alice');
    await create(b, 'bob', 'Bob');
    await fn();
    console.log(`PASS ${name}`);
    passed++;
  }
  try {
    await test('rename releases old name and reserves new one', async () => {
      await assertSucceeds(rename(a, 'alice', 'Nuevo'));
      assert.equal((await getDoc(doc(a, 'users', 'alice'))).data().username, 'Nuevo');
      assert.equal((await getDoc(doc(a, 'usernames', 'alice'))).exists(), false);
      await assertSucceeds(rename(b, 'bob', 'Alice'));
    });
    await test('case-only rename keeps reservation', async () => {
      await assertSucceeds(rename(a, 'alice', 'ALICE'));
      assert.equal((await getDoc(doc(a, 'usernames', 'alice'))).data().uid, 'alice');
    });
    await test('occupied name preserves both profiles', async () => {
      await assert.rejects(rename(a, 'alice', 'BOB'), /occupied/);
      assert.equal((await getDoc(doc(a, 'users', 'alice'))).data().username, 'Alice');
      await assertFails(updateDoc(doc(a, 'users', 'alice'), {
        username: 'BOB', usernameNormalized: 'bob', updatedAt: serverTimestamp(),
      }));
    });
    await test('concurrent claims have exactly one winner', async () => {
      const outcomes = await Promise.allSettled([rename(a, 'alice', 'Shared'), rename(b, 'bob', 'SHARED')]);
      assert.equal(outcomes.filter(x => x.status === 'fulfilled').length, 1);
      const winner = (await getDoc(doc(a, 'usernames', 'shared'))).data().uid;
      const loser = winner === 'alice' ? 'bob' : 'alice';
      assert.equal((await getDoc(doc(a, 'usernames', loser))).data().uid, loser);
    });
    await test('cannot omit releasing old name', async () => {
      const batch = writeBatch(a);
      batch.set(doc(a, 'usernames', 'nuevo'), { uid: 'alice' });
      batch.update(doc(a, 'users', 'alice'), {
        username: 'Nuevo', usernameNormalized: 'nuevo', updatedAt: serverTimestamp(),
      });
      await assertFails(batch.commit());
    });
    await test('cannot delete active reservation or steal another', async () => {
      await assertFails(deleteDoc(doc(a, 'usernames', 'alice')));
      await assertFails(deleteDoc(doc(a, 'usernames', 'bob')));
      await assertFails(setDoc(doc(a, 'usernames', 'bob'), { uid: 'alice' }));
      await assertFails(setDoc(doc(a, 'usernames', 'extra'), { uid: 'alice' }));
    });
    await test('normalization, schema, role and creation time are enforced', async () => {
      for (const patch of [
        { username: 'Bob' }, { username: 'x'.repeat(21) }, { username: 12 },
        { role: 'admin' }, { createdAt: Timestamp.fromMillis(0) }, { extra: true },
      ]) {
        await assertFails(updateDoc(doc(a, 'users', 'alice'), { ...patch, updatedAt: serverTimestamp() }));
      }
    });
    await test('private profiles remain owner-only and cannot be listed', async () => {
      await assertFails(getDoc(doc(a, 'users', 'bob')));
      await assertFails(getDocs(collection(a, 'users')));
      await assertFails(getDocs(collection(a, 'usernames')));
      await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'usernames', 'alice')));
      await assertFails(rename(a, 'bob', 'Stolen'));
    });
    await test('legacy profile can still be completed', async () => {
      await env.withSecurityRulesDisabled(async context => {
        await setDoc(doc(context.firestore(), 'users', 'legacy'), {
          email: 'legacy@example.com', createdAt: Timestamp.fromMillis(1000), updatedAt: Timestamp.fromMillis(1000),
        });
      });
      const db = env.authenticatedContext('legacy', { email: 'legacy@example.com' }).firestore();
      const batch = writeBatch(db);
      batch.update(doc(db, 'users', 'legacy'), { username: 'Legacy', usernameNormalized: 'legacy',
        role: 'user', updatedAt: serverTimestamp() });
      batch.set(doc(db, 'usernames', 'legacy'), { uid: 'legacy' });
      await assertSucceeds(batch.commit());
    });
    console.log(`${passed} username rule tests passed`);
  } finally {
    await env.cleanup();
  }
}
main().catch(error => { console.error(error); process.exitCode = 1; });
