# Firestore Profile Rules Analysis

Scope: Subfase 2.3, user profile documents only.

Firestore database: projects/yomecuido-1dc1a/databases/(default)
Edition/type: STANDARD, FIRESTORE_NATIVE

Collections and paths used by app after this change:

- users/{uid}
  - email: string, required, copied from Firebase Auth email.
  - createdAt: timestamp, required, set with FieldValue.serverTimestamp().
  - updatedAt: timestamp, required, set with FieldValue.serverTimestamp().

No category progress, lesson progress, quiz answers, scores, or educational
content are stored in Firestore in this subphase.

Access pattern:

- Authenticated user gets users/{ownUid}.
- Authenticated user creates users/{ownUid} if missing.
- The app does not list users.
- The app does not update or delete user profile documents in this subphase.
- App access is centralized in UserProfileRepository; widgets and controllers
  do not call FirebaseFirestore directly.

Rules attack review:

- Public list: denied because list is false.
- Unauthenticated get/create: denied by isOwner(userId).
- User A get/create for User B: denied because request.auth.uid must match
  userId.
- Schema pollution: denied because create requires only email, createdAt,
  updatedAt.
- Missing fields: denied because create requires all three fields.
- Type juggling: denied because email must be string and timestamps must equal
  request.time.
- Email spoofing: denied because email must equal request.auth.token.email.
- createdAt overwrite on login: no update rule exists; app reads existing docs
  and does not write when the profile already exists.
- Future subcollections such as categoryProgress: no rules are defined, so they
  remain denied.
