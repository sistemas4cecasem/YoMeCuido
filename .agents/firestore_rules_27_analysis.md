# Firestore rules audit - Subfase 2.7

## Project files inspected

- `firestore.rules`
- `firebase.json`
- `.firebaserc`
- `lib/data/repositories/user_profile_repository.dart`
- `lib/data/repositories/category_progress_repository.dart`
- Firestore usage searched with `rg` for collection paths, queries, and `_connection_tests`.

## Firebase target

- `.firebaserc` default project: `yomecuido-1dc1a`
- `firebase.json` Firestore database: `(default)`
- Firestore edition confirmed by CLI: `STANDARD`, `FIRESTORE_NATIVE`

## Firestore paths used by the app

- `users/{uid}`
  - `get`: `UserProfileRepository.fetchProfile`
  - `create`: `UserProfileRepository.ensureProfile`
  - `update`: not currently used by Flutter, but rules allow owner-only valid updates for the approved profile schema.
  - `delete`: not used.

- `users/{uid}/categoryProgress/{categoryId}`
  - `list/get`: `CategoryProgressRepository.fetchAllProgress`
  - `create/update`: theory progress, activity attempts, and answers.
  - `delete`: not used.

No app code depends on `_connection_tests`.
No app code uses Firestore `where`, `orderBy`, or `limit`.

## Initial risks found

- The previous `categoryProgress` rules enumerated the current demo lesson and activity IDs directly. That was secure for the current data, but too tightly coupled to local content and contradicted the 2.7 requirement not to enumerate `activity_1`, `activity_2`, etc.
- Profile update was denied entirely. The app does not currently update profiles, but the approved 2.7 shape expects owner-only updates to known fields while preserving `createdAt`.
- No global permissive wildcard existed.
- No `_connection_tests` rule existed.

## Final rule intent

- Default deny via explicit final `match /{document=**}`.
- Owner-only access for profile and progress.
- Closed schemas for both persisted document types.
- Server timestamp checks for client writes that use `FieldValue.serverTimestamp()`.
- `createdAt` and `startedAt` immutable after creation.
- `categoryId` must match the progress document ID.
- `status` restricted to `notStarted`, `inProgress`, `completed`.
- Numeric fields constrained to sane non-negative ranges.
- `latestAnswers` stays dynamic, but is constrained as a map with bounded keys that must be included in `completedActivityIds`.

## Auditor assessment

```json
{
  "score": 5,
  "summary": "Rules enforce owner-only access, deny cross-user access, close schemas, validate core types and ranges, and preserve immutable timestamps. Remaining limitations are intentional because Firestore Rules cannot iterate arbitrary dynamic answer maps without coupling to local content IDs.",
  "findings": [
    {
      "check": "Business Logic vs. Rules",
      "severity": "minor",
      "issue": "Rules do not validate every educational ID or each dynamic latestAnswers child field.",
      "recommendation": "Keep validation at schema/range/ownership level unless the content is migrated to Firestore or a bounded server-side validation layer is introduced."
    }
  ]
}
```

## Devil's advocate outcomes

- Public list exploit: rejected.
- Unauthenticated access: rejected.
- Cross-user read/write: rejected.
- Profile privilege fields such as `role` or `isAdmin`: rejected by schema.
- Profile `createdAt` modification: rejected.
- Progress `categoryId` mismatch: rejected.
- Progress invalid `status`: rejected.
- Progress negative/overflow numeric values: rejected.
- Progress `startedAt` modification: rejected.
- Progress `attemptCount` decrease: rejected.
- Progress arbitrary field injection: rejected.
- Progress delete: rejected.
