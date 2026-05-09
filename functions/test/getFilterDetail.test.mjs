/**
 * Unit tests for `applyGetFilterDetail` — exercises Firestore lookup + R2
 * presigned URL construction with an in-memory Firestore + presign stub.
 */
import { describe, it } from "node:test";
import assert from "node:assert/strict";

import {
  applyAddUserSample,
  applyGetFilterDetail,
  applyListReviews,
  applyListSamples,
  applyReviewImageUploadInit,
  applySampleImageUploadInit,
  applySubmitReview,
} from "../lib/http/filters.js";

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
        get(field) { return record?.[field]; },
        data: () => record,
      };
    },
    async set(record, options = {}) {
      const current = data.get(path) ?? {};
      data.set(path, options.merge ? { ...current, ...record } : record);
    },
    async update(record) {
      const current = data.get(path);
      if (current === undefined) {
        const error = new Error(`missing document: ${path}`);
        error.code = 5;
        throw error;
      }
      data.set(path, { ...current, ...record });
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
    _data: data,
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
        photoUrl: "https://cdn.test/review.jpg",
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
    assert.equal(result.reviews[0].photoUrl, "https://cdn.test/review.jpg");
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

  it("rejects paid filters when the user has no entitlement", async () => {
    const firestore = makeFakeFirestore({
      "filters/paid-1": {
        title: "Paid",
        status: "approved",
        priceCoins: 120,
        objectKey: "filters/u/paid-1.fmpkg",
      },
    });
    let didPresign = false;
    await assert.rejects(
      () => applyGetFilterDetail(
        { filterId: "paid-1" },
        {
          firestore,
          uid: "u-current",
          presignGetURL: async () => {
            didPresign = true;
            return { url: "x", expiresAt: 0 };
          },
        },
      ),
      (err) => err && err.code === "permission-denied" && /not_entitled/.test(err.message),
    );
    assert.equal(didPresign, false);
  });

  it("returns a paid filter when the user has an entitlement", async () => {
    const firestore = makeFakeFirestore({
      "filters/paid-1": {
        title: "Paid",
        status: "approved",
        priceCoins: 120,
        objectKey: "filters/u/paid-1.fmpkg",
      },
      "users/u-current/entitlements/paid-1": {
        filterId: "paid-1",
      },
    });
    const result = await applyGetFilterDetail(
      { filterId: "paid-1" },
      {
        firestore,
        uid: "u-current",
        presignGetURL: async () => ({ url: "https://r2.test/paid", expiresAt: 10 }),
      },
    );
    assert.equal(result.filter.priceCoins, 120);
    assert.equal(result.signedDownloadURL, "https://r2.test/paid");
  });

  it("returns a paid filter for active Pro users", async () => {
    const firestore = makeFakeFirestore({
      "filters/paid-pro": {
        title: "Paid Pro",
        status: "approved",
        priceCoins: 240,
        objectKey: "filters/u/paid-pro.fmpkg",
      },
      "users/u-current/proStatus/status": {
        active: true,
      },
    });
    const result = await applyGetFilterDetail(
      { filterId: "paid-pro" },
      {
        firestore,
        uid: "u-current",
        presignGetURL: async () => ({ url: "https://r2.test/pro", expiresAt: 10 }),
      },
    );
    assert.equal(result.filter.priceCoins, 240);
    assert.equal(result.signedDownloadURL, "https://r2.test/pro");
  });
});

describe("applyReviewImageUploadInit", () => {
  it("returns a presigned R2 upload and stable public URL for review images", async () => {
    const firestore = makeFakeFirestore({
      "filters/abc-123": { status: "approved" },
    });
    let signedKey = null;
    const result = await applyReviewImageUploadInit(
      "u-1",
      { filterId: "abc-123", contentType: "image/jpeg", imageBytes: 1234 },
      {
        firestore,
        publicBaseURL: "https://cdn.moodit.test/media/",
        now: () => 123456,
        uuid: () => "image-id",
        presignPutURL: async (key, options) => {
          signedKey = key;
          assert.equal(options.contentType, "image/jpeg");
          return {
            url: `https://r2.test/upload?key=${encodeURIComponent(key)}`,
            headers: { "Content-Type": "image/jpeg" },
            expiresAt: 999,
          };
        },
      },
    );

    assert.equal(signedKey, "reviews/abc-123/u-1/123456-image-id.jpg");
    assert.equal(result.objectKey, "reviews/abc-123/u-1/123456-image-id.jpg");
    assert.equal(result.uploadUrl, "https://r2.test/upload?key=reviews%2Fabc-123%2Fu-1%2F123456-image-id.jpg");
    assert.deepEqual(result.uploadHeaders, { "Content-Type": "image/jpeg" });
    assert.equal(result.publicURL, "https://cdn.moodit.test/media/reviews/abc-123/u-1/123456-image-id.jpg");
  });

  it("rejects missing filters for review image upload", async () => {
    await assert.rejects(
      () => applyReviewImageUploadInit(
        "u-1",
        { filterId: "missing", contentType: "image/jpeg", imageBytes: 10 },
        {
          firestore: makeFakeFirestore({}),
          publicBaseURL: "https://cdn.test",
          presignPutURL: async () => ({ url: "x", expiresAt: 0 }),
        },
      ),
      (err) => err && err.code === "not-found",
    );
  });
});

describe("applySubmitReview", () => {
  it("creates a verified review when the user has downloaded the filter", async () => {
    const firestore = makeFakeFirestore({
      "filters/abc-123": {
        status: "approved",
        authorUid: "maker-1",
      },
      "users/u-reviewer/savedFilters/abc-123": {
        filterId: "abc-123",
      },
      "users/u-reviewer": {
        displayName: "Hana",
        handle: "hana.film",
      },
    });

    const result = await applySubmitReview(
      "u-reviewer",
      {
        filterId: "abc-123",
        stars: 5,
        body: "따뜻한 톤이 마음에 들어요.",
        photoUrl: "https://cdn.test/review.jpg",
        photoObjectKey: "reviews/abc-123/u-reviewer/review.jpg",
      },
      { firestore },
    );

    assert.deepEqual(result, {
      ok: true,
      filterId: "abc-123",
      reviewId: "u-reviewer",
      isVerifiedDownload: true,
    });
    const saved = firestore._data.get("filters/abc-123/reviews/u-reviewer");
    assert.equal(saved.authorUid, "u-reviewer");
    assert.equal(saved.authorDisplayName, "Hana");
    assert.equal(saved.authorHandle, "@hana.film");
    assert.equal(saved.stars, 5);
    assert.equal(saved.body, "따뜻한 톤이 마음에 들어요.");
    assert.equal(saved.isVerifiedDownload, true);
    assert.equal(saved.photoUrl, "https://cdn.test/review.jpg");
  });

  it("rejects reviews without a download, entitlement, or active Pro", async () => {
    const firestore = makeFakeFirestore({
      "filters/abc-123": {
        status: "approved",
        authorUid: "maker-1",
      },
    });

    await assert.rejects(
      () => applySubmitReview(
        "u-reviewer",
        { filterId: "abc-123", stars: 4, body: "다운로드 없이 작성" },
        { firestore },
      ),
      (err) => err && err.code === "failed-precondition" && /download_required/.test(err.message),
    );
  });

  it("rejects maker self reviews", async () => {
    const firestore = makeFakeFirestore({
      "filters/abc-123": {
        status: "approved",
        authorUid: "maker-1",
      },
      "users/maker-1/savedFilters/abc-123": {
        filterId: "abc-123",
      },
    });

    await assert.rejects(
      () => applySubmitReview(
        "maker-1",
        { filterId: "abc-123", stars: 5, body: "내 필터 리뷰" },
        { firestore },
      ),
      (err) => err && err.code === "failed-precondition" && /maker_cannot_review/.test(err.message),
    );
  });
});

describe("sample upload callables", () => {
  it("returns a presigned R2 upload and public URL for user samples", async () => {
    const firestore = makeFakeFirestore({
      "filters/abc-123": {
        status: "approved",
        authorUid: "maker-1",
      },
      "users/u-sample/savedFilters/abc-123": {
        filterId: "abc-123",
      },
    });
    let signedKey = null;

    const result = await applySampleImageUploadInit(
      "u-sample",
      { filterId: "abc-123", contentType: "image/png", imageBytes: 2048 },
      {
        firestore,
        publicBaseURL: "https://cdn.moodit.test/media",
        now: () => 222,
        uuid: () => "sample-image",
        presignPutURL: async (key, options) => {
          signedKey = key;
          assert.equal(options.contentType, "image/png");
          return {
            url: `https://r2.test/upload?key=${encodeURIComponent(key)}`,
            headers: { "Content-Type": "image/png" },
            expiresAt: 123,
          };
        },
      },
    );

    assert.equal(signedKey, "samples/abc-123/u-sample/222-sample-image.png");
    assert.equal(result.objectKey, "samples/abc-123/u-sample/222-sample-image.png");
    assert.equal(result.publicURL, "https://cdn.moodit.test/media/samples/abc-123/u-sample/222-sample-image.png");
  });

  it("registers a user sample only for the signed object owner", async () => {
    const firestore = makeFakeFirestore({
      "filters/abc-123": {
        status: "approved",
        authorUid: "maker-1",
      },
      "users/u-sample/savedFilters/abc-123": {
        filterId: "abc-123",
      },
    });

    const result = await applyAddUserSample(
      "u-sample",
      {
        filterId: "abc-123",
        objectKey: "samples/abc-123/u-sample/222-sample-image.png",
        publicURL: "https://cdn.moodit.test/media/samples/abc-123/u-sample/222-sample-image.png",
        categoryHint: "portrait",
      },
      {
        firestore,
        publicBaseURL: "https://cdn.moodit.test/media",
        uuid: () => "sample-doc",
      },
    );

    assert.equal(result.sampleId, "sample-doc");
    const saved = firestore._data.get("filters/abc-123/samples/sample-doc");
    assert.equal(saved.kind, "user");
    assert.equal(saved.authorUid, "u-sample");
    assert.equal(saved.categoryHint, "portrait");
    assert.equal(saved.coverURL, "https://cdn.moodit.test/media/samples/abc-123/u-sample/222-sample-image.png");
    assert.equal(saved.thumbnailURL, saved.coverURL);
  });

  it("rejects registering another user's sample object", async () => {
    const firestore = makeFakeFirestore({
      "filters/abc-123": {
        status: "approved",
      },
      "users/u-sample/savedFilters/abc-123": {
        filterId: "abc-123",
      },
    });

    await assert.rejects(
      () => applyAddUserSample(
        "u-sample",
        {
          filterId: "abc-123",
          objectKey: "samples/abc-123/u-other/222-sample-image.png",
          publicURL: "https://cdn.moodit.test/media/samples/abc-123/u-other/222-sample-image.png",
        },
        {
          firestore,
          publicBaseURL: "https://cdn.moodit.test/media",
          uuid: () => "sample-doc",
        },
      ),
      (err) => err && err.code === "permission-denied" && /owner_mismatch/.test(err.message),
    );
  });
});

describe("listReviews and listSamples", () => {
  it("returns active reviews in helpful order with a cursor", async () => {
    const firestore = makeFakeFirestore({
      "filters/abc-123": {
        status: "approved",
      },
      "filters/abc-123/reviews/older": {
        authorUid: "u-older",
        authorDisplayName: "Older",
        stars: 4,
        body: "Older review",
        helpfulCount: 1,
        status: "active",
        createdAt: { toMillis: () => 100 },
      },
      "filters/abc-123/reviews/helpful": {
        authorUid: "u-helpful",
        authorDisplayName: "Helpful",
        stars: 5,
        body: "Helpful review",
        helpfulCount: 9,
        status: "active",
        createdAt: { toMillis: () => 50 },
      },
      "filters/abc-123/reviews/hidden": {
        authorUid: "u-hidden",
        authorDisplayName: "Hidden",
        stars: 1,
        body: "Hidden review",
        helpfulCount: 100,
        status: "hidden",
        createdAt: { toMillis: () => 300 },
      },
      "filters/abc-123/reviews/newer": {
        authorUid: "u-newer",
        authorDisplayName: "Newer",
        stars: 5,
        body: "Newer review",
        helpfulCount: 1,
        status: "published",
        createdAt: { toMillis: () => 200 },
      },
    });

    const firstPage = await applyListReviews(
      { filterId: "abc-123", limit: 2 },
      { firestore },
    );

    assert.deepEqual(firstPage.reviews.map((review) => review.id), ["helpful", "newer"]);
    assert.equal(firstPage.reviews[0].authorDisplayName, "Helpful");
    assert.ok(firstPage.nextCursor);

    const secondPage = await applyListReviews(
      { filterId: "abc-123", limit: 2, cursor: firstPage.nextCursor },
      { firestore },
    );

    assert.deepEqual(secondPage.reviews.map((review) => review.id), ["older"]);
    assert.equal(secondPage.nextCursor, null);
  });

  it("returns featured samples first and filters hidden samples", async () => {
    const firestore = makeFakeFirestore({
      "filters/abc-123": {
        status: "approved",
      },
      "filters/abc-123/samples/user-old": {
        kind: "user",
        categoryHint: "portrait",
        coverURL: "https://cdn.test/old.jpg",
        thumbnailURL: "https://cdn.test/old-thumb.jpg",
        featured: false,
        createdAt: { toMillis: () => 100 },
      },
      "filters/abc-123/samples/featured": {
        kind: "signature",
        categoryHint: "landscape",
        coverURL: "https://cdn.test/featured.jpg",
        thumbnailURL: "https://cdn.test/featured-thumb.jpg",
        featured: true,
        createdAt: { toMillis: () => 50 },
      },
      "filters/abc-123/samples/user-new": {
        kind: "user",
        categoryHint: "food",
        coverURL: "https://cdn.test/new.jpg",
        thumbnailURL: "https://cdn.test/new-thumb.jpg",
        featured: false,
        createdAt: { toMillis: () => 200 },
      },
      "filters/abc-123/samples/hidden": {
        kind: "user",
        status: "hidden",
        coverURL: "https://cdn.test/hidden.jpg",
      },
    });

    const result = await applyListSamples(
      { filterId: "abc-123", limit: 10 },
      { firestore },
    );

    assert.deepEqual(result.samples.map((sample) => sample.id), ["featured", "user-new", "user-old"]);
    assert.equal(result.samples[0].coverURL, "https://cdn.test/featured.jpg");
    assert.equal(result.nextCursor, null);
  });

  it("rejects unavailable filters for paginated reads", async () => {
    const firestore = makeFakeFirestore({
      "filters/pending": {
        status: "pending_review",
      },
    });

    await assert.rejects(
      () => applyListReviews({ filterId: "pending" }, { firestore }),
      (err) => err && err.code === "not-found",
    );
    await assert.rejects(
      () => applyListSamples({ filterId: "missing" }, { firestore }),
      (err) => err && err.code === "not-found",
    );
  });
});
