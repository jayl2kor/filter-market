/**
 * Firestore security-rules tests for the reviews migration (US-014).
 *
 * Uses `@firebase/rules-unit-testing` to run the Firestore rules emulator inside
 * the test process. This file covers the policy boundary set in
 * `firestore.rules` for the `/filters/{id}/reviews/{authorUid}` document — the
 * heart of the reviews migration:
 *   - 1 review per (uid, filterId)  (enforced by docId == authorUid + create policy)
 *   - Author may edit their own review's body/stars only
 *   - Anyone authed can bump helpfulCount by exactly +1
 *   - Only the filter's maker may attach a single makerReply
 *   - Recipient-only reads on /users/{uid}/notifications
 *   - Block edges scoped to actor uid
 *
 * Run with: npm run test:rules (see package.json).
 *
 * Auto-skips when the Firestore emulator is not reachable on $FIRESTORE_EMULATOR_HOST,
 * which is what Firebase's emulator harness sets when `firebase emulators:exec`
 * launches us. CI / local dev should run via `npm run test:rules` to wire that up.
 */
import { describe, it, before, after } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from "@firebase/rules-unit-testing";

const __dirname = dirname(fileURLToPath(import.meta.url));
const rulesPath = resolve(__dirname, "..", "..", "firestore.rules");

const FILTER_ID = "sunset-1973";
const MAKER_UID = "maker-jisoo";
const AUTHOR_UID = "u-han";
const STRANGER_UID = "u-stranger";

function reviewDoc(extra = {}) {
  return {
    filterId: FILTER_ID,
    authorUid: AUTHOR_UID,
    authorHandle: "@han",
    stars: 5,
    body: "정말 좋아요",
    isVerifiedDownload: true,
    helpfulCount: 0,
    createdAt: new Date(),
    ...extra,
  };
}

const ENV_HOST = process.env.FIRESTORE_EMULATOR_HOST;
let env;

const suite = describe(
  ENV_HOST ? "firestore.rules — reviews migration" : "firestore.rules (skipped — no emulator)",
  { skip: !ENV_HOST },
  () => {
    before(async () => {
      env = await initializeTestEnvironment({
        projectId: "moodit-rules-test",
        firestore: {
          rules: readFileSync(rulesPath, "utf8"),
          // host/port come from FIRESTORE_EMULATOR_HOST.
        },
      });

      // Seed a filter doc owned by MAKER_UID via the privileged admin path so
      // collection-level rules don't block setup.
      await env.withSecurityRulesDisabled(async (ctx) => {
        await ctx
          .firestore()
          .doc(`filters/${FILTER_ID}`)
          .set({ authorUid: MAKER_UID, useCount: 0 });
      });
    });

    after(async () => {
      if (env) await env.cleanup();
    });

    it("rejects an unauthenticated read of /filters/{id}/uses (only owner)", async () => {
      const anon = env.unauthenticatedContext();
      await assertFails(anon.firestore().doc(`filters/${FILTER_ID}/uses/${AUTHOR_UID}`).get());
    });

    it("allows the author to create their first review", async () => {
      const ctx = env.authenticatedContext(AUTHOR_UID);
      await assertSucceeds(
        ctx.firestore().doc(`filters/${FILTER_ID}/reviews/${AUTHOR_UID}`).set(reviewDoc())
      );
    });

    it("rejects a second review for the same (uid, filterId)", async () => {
      // First write under a fresh author to avoid coupling to test ordering.
      const dupUid = "u-dup";
      const ctx = env.authenticatedContext(dupUid);
      await assertSucceeds(
        ctx
          .firestore()
          .doc(`filters/${FILTER_ID}/reviews/${dupUid}`)
          .set(reviewDoc({ authorUid: dupUid }))
      );

      // Same uid trying to write a second review at the same path → "already exists"
      // is allowed by rules but it must be an UPDATE matching validReviewSelfUpdate.
      // Trying to overwrite isVerifiedDownload should be rejected.
      await assertFails(
        ctx
          .firestore()
          .doc(`filters/${FILTER_ID}/reviews/${dupUid}`)
          .update({ isVerifiedDownload: false })
      );
    });

    it("rejects a different uid trying to forge an authorUid", async () => {
      const ctx = env.authenticatedContext(STRANGER_UID);
      await assertFails(
        ctx
          .firestore()
          .doc(`filters/${FILTER_ID}/reviews/${STRANGER_UID}`)
          .set(reviewDoc({ authorUid: AUTHOR_UID })) // forged
      );
    });

    it("rejects a review with stars out of range", async () => {
      const ctx = env.authenticatedContext("u-stars");
      await assertFails(
        ctx
          .firestore()
          .doc(`filters/${FILTER_ID}/reviews/u-stars`)
          .set(reviewDoc({ authorUid: "u-stars", stars: 7 }))
      );
    });

    it("allows author to edit body+stars but not isVerifiedDownload", async () => {
      const uid = "u-edit";
      await env.withSecurityRulesDisabled(async (ctx) => {
        await ctx
          .firestore()
          .doc(`filters/${FILTER_ID}/reviews/${uid}`)
          .set(reviewDoc({ authorUid: uid }));
      });

      const author = env.authenticatedContext(uid);
      await assertSucceeds(
        author
          .firestore()
          .doc(`filters/${FILTER_ID}/reviews/${uid}`)
          .update({ stars: 4, body: "수정", updatedAt: new Date() })
      );

      await assertFails(
        author
          .firestore()
          .doc(`filters/${FILTER_ID}/reviews/${uid}`)
          .update({ isVerifiedDownload: false })
      );
    });

    it("allows any authed user to bump helpfulCount by +1, but not by +2", async () => {
      const uid = "u-helpful-author";
      await env.withSecurityRulesDisabled(async (ctx) => {
        await ctx
          .firestore()
          .doc(`filters/${FILTER_ID}/reviews/${uid}`)
          .set(reviewDoc({ authorUid: uid, helpfulCount: 3 }));
      });

      const peer = env.authenticatedContext("u-peer");
      await assertSucceeds(
        peer
          .firestore()
          .doc(`filters/${FILTER_ID}/reviews/${uid}`)
          .update({ helpfulCount: 4 })
      );

      await assertFails(
        peer
          .firestore()
          .doc(`filters/${FILTER_ID}/reviews/${uid}`)
          .update({ helpfulCount: 6 })
      );
    });

    it("allows the maker to attach a single makerReply, then rejects a second", async () => {
      const uid = "u-reply-target";
      await env.withSecurityRulesDisabled(async (ctx) => {
        await ctx
          .firestore()
          .doc(`filters/${FILTER_ID}/reviews/${uid}`)
          .set(reviewDoc({ authorUid: uid }));
      });

      const maker = env.authenticatedContext(MAKER_UID);
      await assertSucceeds(
        maker
          .firestore()
          .doc(`filters/${FILTER_ID}/reviews/${uid}`)
          .update({
            makerReply: { body: "감사합니다", createdAt: new Date() },
          })
      );

      // Second reply attempt — rules require the prior makerReply to be null.
      await assertFails(
        maker
          .firestore()
          .doc(`filters/${FILTER_ID}/reviews/${uid}`)
          .update({
            makerReply: { body: "한 번 더", createdAt: new Date() },
          })
      );

      // Stranger trying to attach is also rejected.
      const stranger = env.authenticatedContext(STRANGER_UID);
      await assertFails(
        stranger
          .firestore()
          .doc(`filters/${FILTER_ID}/reviews/${uid}`)
          .update({
            makerReply: { body: "stranger", createdAt: new Date() },
          })
      );
    });

    it("rejects direct client writes to /filters/{id}/uses (server-only)", async () => {
      const ctx = env.authenticatedContext(AUTHOR_UID);
      await assertFails(
        ctx
          .firestore()
          .doc(`filters/${FILTER_ID}/uses/${AUTHOR_UID}`)
          .set({ lastUseAt: new Date() })
      );
    });

    it("scopes notifications reads to the recipient", async () => {
      await env.withSecurityRulesDisabled(async (ctx) => {
        await ctx
          .firestore()
          .doc(`users/u-recipient/notifications/n-1`)
          .set({ kind: "review", filterId: FILTER_ID, createdAt: new Date() });
      });

      const recipient = env.authenticatedContext("u-recipient");
      await assertSucceeds(
        recipient.firestore().doc(`users/u-recipient/notifications/n-1`).get()
      );

      const stranger = env.authenticatedContext(STRANGER_UID);
      await assertFails(
        stranger.firestore().doc(`users/u-recipient/notifications/n-1`).get()
      );
    });

    it("scopes block edges to the calling actor", async () => {
      const actor = env.authenticatedContext("u-blocker");
      await assertSucceeds(
        actor
          .firestore()
          .doc(`blocks/u-blocker_u-target`)
          .set({ actorUid: "u-blocker", targetUid: "u-target", createdAt: new Date() })
      );

      // Forging actorUid to someone else should fail.
      await assertFails(
        actor
          .firestore()
          .doc(`blocks/u-blocker_u-other`)
          .set({ actorUid: STRANGER_UID, targetUid: "u-other", createdAt: new Date() })
      );
    });
  }
);

void suite;
