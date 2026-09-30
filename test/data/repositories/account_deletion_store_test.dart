import 'package:demo_yomecuido/data/models/user_profile.dart';
import 'package:demo_yomecuido/data/repositories/account_deletion_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final stage in AccountDeletionStage.values) {
    test('interruption after $stage resumes without recreating data', () async {
      final db = FakeFirebaseFirestore();
      final own = db.collection('users').doc('uid-a');
      final category = own.collection('categoryProgress').doc('category-1');
      final activity = category.collection('activities').doc('activity-1');
      final exam = category.collection('exams').doc('exam-1');
      await own.set({
        'accountState': AccountState.deleting,
        'usernameNormalized': 'name-a',
      });
      await category.set({'fixture': true});
      await activity.set({'fixture': true});
      await activity.collection('attempts').doc('attempt-1').set({
        'fixture': true,
      });
      await exam.set({'fixture': true});
      final examAttempt = exam.collection('attempts').doc('attempt-1');
      await examAttempt.set({'fixture': true});
      await examAttempt.collection('proofs').doc('A').set({'fixture': true});
      await db.collection('leaderboard').doc('uid-a').set({'fixture': true});
      await db.collection('usernames').doc('name-a').set({'uid': 'uid-a'});
      var interrupted = false;
      final first = FirestoreAccountDeletionStore(
        firestore: db,
        onStageComplete: (completed) async {
          if (!interrupted && completed == stage) {
            interrupted = true;
            throw StateError('simulated interruption');
          }
        },
      );
      await expectLater(() async {
        await first.deletePersonalData('uid-a', 'name-a');
        await first.verifyPersonalDataRemoved('uid-a', 'name-a');
        await first.deleteProfile('uid-a');
      }(), throwsStateError);
      expect(interrupted, isTrue);
      final restarted = FirestoreAccountDeletionStore(firestore: db);
      if ((await restarted.fetchProfile('uid-a')) != null) {
        await restarted.deletePersonalData('uid-a', 'name-a');
        await restarted.verifyPersonalDataRemoved('uid-a', 'name-a');
        await restarted.deleteProfile('uid-a');
      }
      expect((await own.get()).exists, isFalse);
      expect((await category.get()).exists, isFalse);
      expect((await activity.collection('attempts').get()).docs, isEmpty);
      expect((await examAttempt.collection('proofs').get()).docs, isEmpty);
      expect(
        (await db.collection('leaderboard').doc('uid-a').get()).exists,
        isFalse,
      );
      expect(
        (await db.collection('usernames').doc('name-a').get()).exists,
        isFalse,
      );
    });
  }

  test(
    'deletes all current personal paths while preserving another user',
    () async {
      final db = FakeFirebaseFirestore();
      final store = FirestoreAccountDeletionStore(firestore: db);
      final own = db.collection('users').doc('uid-a');
      final other = db.collection('users').doc('uid-b');
      final otherProgress = other
          .collection('categoryProgress')
          .doc('category-2');
      final category = own.collection('categoryProgress').doc('category-1');
      final activity = category.collection('activities').doc('activity-1');
      final exam = category.collection('exams').doc('exam-1');
      final attempt = exam.collection('attempts').doc('attempt-1');
      await own.set({
        'accountState': AccountState.deleting,
        'usernameNormalized': 'name-a',
      });
      await other.set({
        'accountState': AccountState.active,
        'usernameNormalized': 'name-b',
      });
      await otherProgress.set({'fixture': true});
      await category.set({'fixture': true});
      await activity.set({'fixture': true});
      await activity.collection('answerSubmissions').doc('submission-1').set({
        'fixture': true,
      });
      await activity.collection('attempts').doc('attempt-1').set({
        'fixture': true,
      });
      await exam.set({'fixture': true});
      await exam.collection('answerSubmissions').doc('submission-1').set({
        'fixture': true,
      });
      await attempt.set({'fixture': true});
      await attempt.collection('proofs').doc('A').set({'fixture': true});
      await attempt.collection('proofs').doc('B').set({'fixture': true});
      await db.collection('leaderboard').doc('uid-a').set({'fixture': true});
      await db.collection('leaderboard').doc('uid-b').set({'fixture': true});
      await db.collection('usernames').doc('name-a').set({'uid': 'uid-a'});
      await db.collection('usernames').doc('name-b').set({'uid': 'uid-b'});
      await db.collection('categories').doc('global').set({'fixture': true});

      await store.deletePersonalData('uid-a', 'name-a');
      await store.verifyPersonalDataRemoved('uid-a', 'name-a');
      await store.deletePersonalData('uid-a', 'name-a');
      expect((await own.get()).exists, isTrue);
      expect((await category.get()).exists, isFalse);
      expect(
        (await activity.collection('answerSubmissions').get()).docs,
        isEmpty,
      );
      expect((await activity.collection('attempts').get()).docs, isEmpty);
      expect((await attempt.collection('proofs').get()).docs, isEmpty);
      expect((await exam.collection('answerSubmissions').get()).docs, isEmpty);
      expect((await exam.collection('attempts').get()).docs, isEmpty);
      expect(
        (await db.collection('leaderboard').doc('uid-a').get()).exists,
        isFalse,
      );
      expect(
        (await db.collection('usernames').doc('name-a').get()).exists,
        isFalse,
      );
      expect((await other.get()).exists, isTrue);
      expect((await otherProgress.get()).exists, isTrue);
      expect(
        (await db.collection('leaderboard').doc('uid-b').get()).exists,
        isTrue,
      );
      expect(
        (await db.collection('usernames').doc('name-b').get()).exists,
        isTrue,
      );
      expect(
        (await db.collection('categories').doc('global').get()).exists,
        isTrue,
      );
      await store.deleteProfile('uid-a');
      expect((await own.get()).exists, isFalse);
    },
  );
}
