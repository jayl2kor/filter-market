/**
 * Firestore triggers — denormalized counters and notification fanout.
 *
 * Triggers are server-only and run after the originating write commits. Use
 * them for fanout work (likeCount, useCount, FCM dispatch) — keep client
 * latency low by leaving counter math here.
 */
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import {
  onDocumentCreated,
  onDocumentDeleted,
  onDocumentUpdated,
} from "firebase-functions/v2/firestore";

const region = "asia-northeast3";

/**
 * Fires when /filters/{filterId} transitions to status: published.
 * Emits notification + bumps owner's filterCount.
 */
export const onFilterPublished = onDocumentUpdated(
  { region, document: "filters/{filterId}" },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;
    if (before.status === "published" || after.status !== "published") return;

    // TODO:
    // 1. Increment /users/{ownerUid}.filterCount via FieldValue.increment(1).
    // 2. Send FCM notification to owner.
    // 3. Index for search (Firestore copy doc or Algolia in Phase 4).
  },
);

/**
 * Fires when a user submits a /filters/{filterId}/reports/{auto} document.
 * Increments filter.reportCount; routes to moderator queue once threshold hit.
 */
export const onReportCreated = onDocumentCreated(
  { region, document: "filters/{filterId}/reports/{reportId}" },
  async (event) => {
    void event;
    // TODO:
    // 1. Increment /filters/{filterId}.reportCount.
    // 2. If >= threshold, set /filters/{filterId}.flaggedForReview = true.
    // 3. Optionally call Cloud Vision SafeSearch on thumbnail.
  },
);

/**
 * Mirrors /follows/{actorUid}_{targetUid} into per-user counters.
 *
 * The client writes only the root follow edge. Counters are server-owned so
 * follower/following list screens do not depend on local-only optimistic state.
 */
export const onFollowCreated = onDocumentCreated(
  { region, document: "follows/{edgeId}" },
  async (event) => {
    const data = event.data?.data();
    const actorUid = data?.actorUid as string | undefined;
    const targetUid = data?.targetUid as string | undefined;
    if (!actorUid || !targetUid || actorUid === targetUid) return;

    const db = getFirestore();
    await Promise.all([
      db.collection("users").doc(actorUid).set({
        followingCount: FieldValue.increment(1),
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true }),
      db.collection("users").doc(targetUid).set({
        followerCount: FieldValue.increment(1),
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true }),
    ]);
  },
);

export const onFollowDeleted = onDocumentDeleted(
  { region, document: "follows/{edgeId}" },
  async (event) => {
    const data = event.data?.data();
    const actorUid = data?.actorUid as string | undefined;
    const targetUid = data?.targetUid as string | undefined;
    if (!actorUid || !targetUid || actorUid === targetUid) return;

    const db = getFirestore();
    await Promise.all([
      db.collection("users").doc(actorUid).set({
        followingCount: FieldValue.increment(-1),
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true }),
      db.collection("users").doc(targetUid).set({
        followerCount: FieldValue.increment(-1),
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true }),
    ]);
  },
);
