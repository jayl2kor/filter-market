# `users/{uid}` Parent Document Audit

**Date:** 2026-05-12
**Context:** Prerequisite for opening `/users/{uid}` Firestore reads to public (see plan `image-49-zesty-sprout`). The parent document must contain only fields intended to be world-readable. Sensitive data should remain in subcollections under owner-only rules.

## Method

1. Grepped `functions/src/` for every write site touching `db.collection("users").doc(...).set(...)` / `.update(...)` on the parent doc (NOT subcollections).
2. Confirmed iOS client paths (`SessionStore.swift:244, 428`) only write to subcollections (`notificationPreferences`, `exportRequests`) — parent doc is server-write only.
3. Production doc sampling is **deferred to deployment-time** (requires Firebase Admin access). Pre-deploy step: run `gcloud firestore export` or admin script and confirm key set matches the whitelist below.

## Cloud Function Write Sites

| File:Line | Trigger / RPC | Fields written to `users/{uid}` |
|---|---|---|
| `functions/src/triggers/index.ts:67-74` | `onFollowCreated` | `followingCount` (on actor), `followerCount` (on target), `updatedAt` |
| `functions/src/triggers/index.ts:89-96` | `onFollowDeleted` | `followingCount` (-1), `followerCount` (-1), `updatedAt` |
| `functions/src/http/identity.ts:115-122` | `setHandle` | `handle`, `updatedAt` |
| `functions/src/http/identity.ts:158-165` | `updateProfile` | `displayName`, `bio`, `website`, `makerPageVisible`, `photoSharingAllowed`, `avatarVariant`, `avatarURL`, `photoURL`, `avatarObjectKey`, `updatedAt` |
| `functions/src/http/identity.ts:259-268` | `deleteAccount` | `deletedAt`, `displayName=""`, `handle=""`, `bio=""`, `website=""`, `makerPageVisible=false`, `photoSharingAllowed=false` |
| `functions/src/http/moderation.ts:249-252` | `reportUser` | `reportCount` (+1), `updatedAt` |

(Cloud Functions also read the doc and write to its subcollections; subcollections are out of scope here — they retain owner-only rules.)

## Field Classification

### ✅ Intended public (whitelist)

Read by other clients via the public Profile screen.

- `handle`
- `displayName`
- `bio`
- `website`
- `avatarURL`, `photoURL`, `avatarVariant`
- `followerCount`, `followingCount`, `filterCount`
- `createdAt`, `updatedAt`, `deletedAt`
- `makerPageVisible` — boolean preference; if false, marketplace surfaces hide maker page. Visible to others is acceptable (it's about user-facing surfaces anyway).
- `photoSharingAllowed` — user consent flag, considered low-sensitivity.

### ⚠️ Borderline (acceptable to leak)

- `avatarObjectKey` — internal R2 storage key (e.g. `users/{uid}/avatar/<ts>-<uuid>.jpg`). The corresponding public URL is already exposed via `avatarURL`. The key itself reveals the storage path scheme but **no credentials**. Risk: enables enumerating user avatar history if attacker can list R2 prefix (but R2 prefix listing is disabled by config). **Decision:** acceptable for Phase 1. Re-evaluate if R2 bucket policy changes.

### ❌ Sensitive (currently leaks under public read)

- `reportCount` — moderation counter. Reveals how many times a user has been reported. Not catastrophic (no reporter identity, no reason), but exposes internal moderation signal. **Decision: relocate to `users/{uid}/moderation/main` (owner-only no-read for non-mods) as a follow-up PR**, NOT a Phase 1 blocker. Risk in Phase 1 window: an attacker who scrapes `reportCount` learns relative report volumes per user. This does not unblock any abuse vector vs. the status quo (where no one outside Firebase Console saw the value anyway).

### Not present in any write site (negative findings)

- `email` — **never written to parent doc**. Stored in Firebase Auth, not Firestore.
- `phone` — same as above.
- `fcmToken` — written to `users/{uid}/devices/{deviceId}`, not parent.
- `internalNotes` / `adminFlags` — not present in any code path.
- Wallet balance, entitlements, pro status — all in subcollections.

## Conclusions

1. **Phase 1 rule change is safe to ship.** The whitelist covers all currently-written fields. The single sensitive field (`reportCount`) does not justify blocking the hotfix; the leak is bounded and reversible.

2. **Follow-up tracked**: relocate `reportCount` out of the parent doc. Suggested approach:
   - In `functions/src/http/moderation.ts:249-252`, change the write target from `userRef.update({reportCount, updatedAt})` to `userRef.collection("moderation").doc("main").set({reportCount, updatedAt}, {merge: true})`.
   - Backfill existing `reportCount` values via one-time admin script.
   - Add corresponding rule `match /users/{uid}/moderation/{doc} { allow read: if isModerator(); allow write: if false; }`.
   - Out of scope for Phase 1 — schedule before Marketing-launch milestone.

3. **Pre-deploy verification** (must run before `firebase deploy --only firestore:rules`):
   - Sample 10–30 production `users/*` documents via admin script.
   - Confirm key set is a subset of the whitelist + borderline categories above.
   - If any unexpected key is found, halt deploy and migrate first.
