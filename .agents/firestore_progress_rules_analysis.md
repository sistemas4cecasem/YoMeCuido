# Firestore progress rules analysis - Subfase 2.5

## Firestore instance

- Project: `yomecuido-1dc1a`
- Database: `(default)`
- Edition: `STANDARD`
- Type: `FIRESTORE_NATIVE`
- Location: `southamerica-west1`

## Application paths found

- `users/{uid}` is used by `UserProfileRepository` for the authenticated user's basic profile.
- `users/{uid}/categoryProgress/{categoryId}` is introduced by `CategoryProgressRepository`.
- No Firestore queries with `where`, `orderBy`, or `limit` were found in app code for progress.
- The app does not read or hydrate progress from Firestore in this subphase.

## Progress schema

`users/{uid}/categoryProgress/{categoryId}` stores only stable references and attempt state:

- `categoryId`: string, equals the document ID.
- `lessonId`: string.
- `status`: `notStarted`, `inProgress`, or `completed`.
- `viewedLessonPageIds`: known local `LessonPage.id` values.
- `completedActivityIds`: known local `QuizQuestion.id` values.
- `correctAnswers`: integer score for the current attempt.
- `totalLessonPages`: integer from local content/controller state.
- `totalActivities`: integer from local content.
- `attemptCount`: integer count of started attempts.
- `startedAt`: immutable server timestamp.
- `lastActivityAt`: server timestamp or null.
- `completedAt`: server timestamp when completed, otherwise null.
- `updatedAt`: server timestamp.
- `latestAnswers`: map keyed by activity ID with `{ answer, isCorrect, answeredAt }`.

The schema deliberately excludes titles, lesson text, statements, options, correct answers, feedback, images, and percentage.

## Access pattern

- Only the authenticated owner can get/list/create/update their own progress.
- Deletes are denied.
- Parent `users/{uid}` must exist before progress access is allowed.

## Devil's advocate review

- Public list exploit: denied because all progress reads require `request.auth.uid == userId`.
- Unauthorized read/write: denied by `isOwner(userId)`.
- Update bypass: blocked by required fields, allowed fields, typed fields, numeric ranges, status validation, and latest answer validation on both create and update.
- Ownership hijacking: `categoryId` must match the progress document ID; the user path is controlled by `request.auth.uid == userId`.
- Immutable field modification: `startedAt` must remain equal to `resource.data.startedAt` on update.
- Data corruption/type juggling: rules check strings, ints, bools, timestamps, list/map fields, and allowed IDs.
- Required field omission: blocked by `hasRequiredProgressFields()`.
- Schema pollution: blocked by `hasOnlyProgressFields()` and per-answer allowed keys.
- Invalid status: blocked by explicit status allowlist.
- Timestamp manipulation: create/update require `startedAt`/`updatedAt` server time behavior; answer timestamps must be server time for new answers or unchanged for existing answers.
- Orphaned subcollection access: blocked by `userProfileExists(userId)`.
- Query mismatch: current app performs no progress reads/queries in this subphase.

Residual limitations for later hardening:

- Security rules validate known IDs for the current demo category only; new educational content will need an intentional rules update or a different validation strategy.
- Rules cannot fully prove semantic score correctness; Flutter computes correctness locally and Firestore validates shape/ranges.
