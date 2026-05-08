/**
 * Unit tests for `applyGetFilterDetail` — exercises Firestore lookup + R2
 * presigned URL construction with an in-memory Firestore + presign stub.
 */
import { describe, it } from "node:test";
import assert from "node:assert/strict";

import { applyGetFilterDetail } from "../lib/http/filters.js";

function makeFakeFirestore(initialDocs = {}) {
  const data = new Map(Object.entries(initialDocs));
  const docRef = (path) => ({
    _path: path,
    collection(name) { return collectionRef(`${path}/${name}`); },
    async get() {
      const record = data.get(path);
      return {
        exists: record !== undefined,
        id: path.split("/").at(-1),
        ref: docRef(path),
        data: () => record,
      };
    },
  });
  const collectionRef = (path) => ({
    _path: path,
    doc(id) { return docRef(`${path}/${id}`); },
    where() { return this; },
    orderBy() { return this; },
    limit() { return this; },
    async get() {
      const prefix = `${path}/`;
      const docs = [];
      for (const [docPath, record] of data.entries()) {
        if (!docPath.startsWith(prefix)) continue;
        const remainder = docPath.slice(prefix.length);
        if (remainder.includes("/")) continue;
        docs.push({
          id: remainder,
          data: () => record,
        });
      }
      return { docs, size: docs.length };
    },
  });
  return {
    collection(name) { return collectionRef(name); },
  };
}

describe("applyGetFilterDetail", () => {
  it("returns approved filter with signed download URL", async () => {
    const firestore = makeFakeFirestore({
      "filters/abc-123": {
        title: "Sunset Vibes",
        description: "Warm cinematic filter for sunset scenes.",
        version: "1.0.0",
        category: "cinematic",
        status: "approved",
        useCount: 42,
        downloadCount: 100,
        priceCoins: 0,
        coverURL: "https://cdn.test/cover.jpg",
        signatureSampleURL: "https://cdn.test/signature.jpg",
        reviewCount: 1,
        likeCount: 12,
        sampleCount: 1,
        tags: ["mood", "warm"],
        objectKey: "filters/u-1/abc-123.fmpkg",
        author: { uid: "u-1", displayName: "Alex" },
      },
      "filters/abc-123/reviews/reviewer-1": {
        authorUid: "reviewer-1",
        authorDisplayName: "Soojin",
        stars: 5,
        body: "Great warm tone.",
        isVerifiedDownload: true,
        helpfulCount: 2,
        status: "active",
      },
      "filters/abc-123/samples/sample-1": {
        kind: "signature",
        categoryHint: "portrait",
        coverURL: "https://cdn.test/sample.jpg",
        thumbnailURL: "https://cdn.test/sample-thumb.jpg",
        featured: true,
      },
      "filters/abc-123/likes/u-current": {
        createdAt: 1,
      },
    });
    let presignedKey = null;
    const presignGetURL = async (key) => {
      presignedKey = key;
      return { url: `https://r2.test/signed?key=${encodeURIComponent(key)}`, expiresAt: 9_999_999 };
    };

    const result = await applyGetFilterDetail(
      { filterId: "abc-123" },
      { firestore, presignGetURL, uid: "u-current" },
    );

    assert.equal(presignedKey, "filters/u-1/abc-123.fmpkg");
    assert.equal(result.filter.id, "abc-123");
    assert.equal(result.filter.title, "Sunset Vibes");
    assert.equal(result.filter.description, "Warm cinematic filter for sunset scenes.");
    assert.equal(result.filter.status, "approved");
    assert.equal(result.filter.useCount, 42);
    assert.equal(result.filter.coverURL, "https://cdn.test/cover.jpg");
    assert.equal(result.filter.signatureSampleURL, "https://cdn.test/signature.jpg");
    assert.equal(result.filter.reviewCount, 1);
    assert.equal(result.filter.likeCount, 12);
    assert.deepEqual(result.filter.tags, ["mood", "warm"]);
    assert.equal(result.samples.length, 1);
    assert.equal(result.samples[0].coverURL, "https://cdn.test/sample.jpg");
    assert.equal(result.reviews.length, 1);
    assert.equal(result.reviews[0].authorDisplayName, "Soojin");
    assert.equal(result.userHasLiked, true);
    assert.equal(result.filter.author.uid, "u-1");
    assert.equal(result.filter.author.displayName, "Alex");
    assert.equal(result.signedDownloadURL, "https://r2.test/signed?key=filters%2Fu-1%2Fabc-123.fmpkg");
    assert.equal(result.expiresAt, 9_999_999);
  });

  it("rejects invalid arguments", async () => {
    const firestore = makeFakeFirestore({});
    await assert.rejects(
      () => applyGetFilterDetail({}, { firestore, presignGetURL: async () => ({ url: "x", expiresAt: 0 }) }),
      (err) => err && err.code === "invalid-argument",
    );
  });

  it("returns not-found when filter does not exist", async () => {
    const firestore = makeFakeFirestore({});
    await assert.rejects(
      () => applyGetFilterDetail(
        { filterId: "missing" },
        { firestore, presignGetURL: async () => ({ url: "x", expiresAt: 0 }) },
      ),
      (err) => err && err.code === "not-found",
    );
  });

  it("rejects non-approved filters as not-found", async () => {
    const firestore = makeFakeFirestore({
      "filters/pending-1": {
        title: "Pending",
        status: "pending_review",
        objectKey: "filters/u/pending-1.fmpkg",
      },
    });
    await assert.rejects(
      () => applyGetFilterDetail(
        { filterId: "pending-1" },
        { firestore, presignGetURL: async () => ({ url: "x", expiresAt: 0 }) },
      ),
      (err) => err && err.code === "not-found",
    );
  });

  it("throws internal when objectKey is missing", async () => {
    const firestore = makeFakeFirestore({
      "filters/no-key": {
        title: "Broken",
        status: "approved",
        // no objectKey
      },
    });
    await assert.rejects(
      () => applyGetFilterDetail(
        { filterId: "no-key" },
        { firestore, presignGetURL: async () => ({ url: "x", expiresAt: 0 }) },
      ),
      (err) => err && err.code === "internal",
    );
  });

  it("decodes Firestore Timestamp createdAt to milliseconds", async () => {
    const firestore = makeFakeFirestore({
      "filters/ts-1": {
        title: "T",
        status: "approved",
        objectKey: "k",
        createdAt: { toMillis: () => 1_700_000_000_000 },
        author: { uid: "u", displayName: "U" },
      },
    });
    const result = await applyGetFilterDetail(
      { filterId: "ts-1" },
      { firestore, presignGetURL: async () => ({ url: "x", expiresAt: 0 }) },
    );
    assert.equal(result.filter.createdAt, 1_700_000_000_000);
  });
});
