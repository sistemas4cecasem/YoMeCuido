Firestore user profile and username analysis

- Firebase Auth owns uid, email/password auth, email verification, and current
  session state.
- Private user profile data lives at users/{uid}. Before this change it only
  allowed email, createdAt, and updatedAt.
- Educational progress remains below users/{uid}/categoryProgress and must stay
  keyed by Firebase uid.
- Register form validation is handled by RegisterController. AuthGate listens
  to AuthRepository.authStateChanges and gates email verification before loading
  progress.
- Firestore rules already use strict owner checks, schema whitelists, timestamp
  validation, and parent profile existence checks for progress subcollections.
- New username uniqueness requires usernames/{usernameNormalized} plus a
  transaction that writes both usernames/{usernameNormalized} and users/{uid}.
- Legacy profiles without username must parse safely and route through a
  complete-profile screen after email verification.
- The rules need to keep users/{uid} owner-only because email remains private.
- Username editing: a transaction reads the current profile and target name,
  reserves the target, updates only username/usernameNormalized/updatedAt, and
  deletes the previous reservation. Case-only edits reuse the same reservation.
  A conflict or failed transaction preserves the original profile and name.
- Rules enforce username.lower() == usernameNormalized, owner-only profile
  access, immutable role/createdAt, and a matching reservation through getAfter.
  Renaming requires removal of the old reservation. Deletion is allowed only
  for the owner's previous name when their profile changes in the same commit.
- Executable attack review: .agents/firestore_rules_tests/username_test.js.
  Nine emulator scenarios pass: rename/reuse, case-only edit, occupied names,
  simultaneous claims, missing release, reservation theft/deletion, invalid
  types/length/normalization/role/timestamp/extra fields, private access/listing,
  and legacy completion. Unauthorized attempts are denied. New account creation
  is also exercised as the setup for every scenario.
- Run with: npx -y firebase-tools@latest emulators:exec --only firestore
  --project demo-yomecuido-usernames "node .agents/firestore_rules_tests/username_test.js"
- Progress/content rules are unchanged by username editing. These targeted
  tests are not a comprehensive audit of all progress and educational data.
- String normalization reference: https://firebase.google.com/docs/reference/rules/rules.String#lower
