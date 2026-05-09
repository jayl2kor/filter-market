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

async function recalculateReviewStats(filterId: string): Promise<void> {
  const db = getFirestore();
  const reviewsSnap = await db.collection("filters").doc(filterId)
    .collection("reviews")
    .where("status", "in", ["active", "published"])
    .get();

  let totalStars = 0;
  for (const doc of reviewsSnap.docs) {
    const stars = doc.get("stars");
    if (typeof stars === "number") {
      totalStars += stars;
    }
  }

  const reviewCount = reviewsSnap.size;
  await db.collection("filters").doc(filterId).set({
    reviewCount,
    ratingAvg: reviewCount > 0 ? Math.round((totalStars / reviewCount) * 10) / 10 : null,
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });
}

export const onReviewCreated = onDocumentCreated(
  { region, document: "filters/{filterId}/reviews/{reviewId}" },
  async (event) => {
    const filterId = event.params.filterId;
    if (!filterId) return;
    await recalculateReviewStats(filterId);
  },
);

export const onReviewUpdated = onDocumentUpdated(
  { region, document: "filters/{filterId}/reviews/{reviewId}" },
  async (event) => {
    const filterId = event.params.filterId;
    if (!filterId) return;
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;
    if (before.stars === after.stars && before.status === after.status) return;
    await recalculateReviewStats(filterId);
  },
);

export const onReviewDeleted = onDocumentDeleted(
  { region, document: "filters/{filterId}/reviews/{reviewId}" },
  async (event) => {
    const filterId = event.params.filterId;
    if (!filterId) return;
    await recalculateReviewStats(filterId);
  },
);

export const onSampleCreated = onDocumentCreated(
  { region, document: "filters/{filterId}/samples/{sampleId}" },
  async (event) => {
    const filterId = event.params.filterId;
    if (!filterId) return;
    await getFirestore().collection("filters").doc(filterId).set({
      sampleCount: FieldValue.increment(1),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  },
);

export const onSampleDeleted = onDocumentDeleted(
  { region, document: "filters/{filterId}/samples/{sampleId}" },
  async (event) => {
    const filterId = event.params.filterId;
    if (!filterId) return;
    await getFirestore().collection("filters").doc(filterId).set({
      sampleCount: FieldValue.increment(-1),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  },
);

export const onFilterLikeCreated = onDocumentCreated(
  { region, document: "filters/{filterId}/likes/{uid}" },
  async (event) => {
    const filterId = event.params.filterId;
    if (!filterId) return;
    await getFirestore().collection("filters").doc(filterId).set({
      likeCount: FieldValue.increment(1),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  },
);

export const onFilterLikeDeleted = onDocumentDeleted(
  { region, document: "filters/{filterId}/likes/{uid}" },
  async (event) => {
    const filterId = event.params.filterId;
    if (!filterId) return;
    await getFirestore().collection("filters").doc(filterId).set({
      likeCount: FieldValue.increment(-1),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  },
);
