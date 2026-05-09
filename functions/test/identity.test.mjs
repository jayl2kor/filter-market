/**
 * Unit tests for `applySetHandle`, `applyUpdateProfile`, `applyDeleteAccount`
 * using an in-memory Firestore stub.
 */
import { describe, it } from "node:test";
import assert from "node:assert/strict";

import {
  applySetHandle,
  applyUpdateProfile,
  applyProfileAvatarUploadInit,
  applyDeleteAccount,
} from "../lib/http/identity.js";

function makeFakeFirestore(initial = {}) {
  const data = new Map(Object.entries(initial));
  const docRef = (path) => ({
    _path: path,
    id: path.split("/").pop(),
    async get() {
      const record = data.get(path);
      return { exists: record !== undefined, data: () => record };
    },
    async set(payload, opts) {
      const merged = opts && opts.merge ? data.get(path) : undefined;
      data.set(path, { ...(merged ?? {}), ...payload });
    },
    async delete() { data.delete(path); },
  });
  const collectionRef = (path) => ({
    doc(id) { return docRef(`${path}/${id}`); },
  });
  const tx = {
    async get(ref) {
      const record = data.get(ref._path);
      return { exists: record !== undefined, data: () => record };
    },
    set(ref, payload, opts) {
      const merged = opts && opts.merge ? data.get(ref._path) : undefined;
      data.set(ref._path, { ...(merged ?? {}), ...payload });
    },
    delete(ref) { data.delete(ref._path); },
  };
  return {
    _data: data,
    collection(name) { return collectionRef(name); },
    async runTransaction(fn) { return fn(tx); },
  };
}

describe("applySetHandle", () => {
  it("claims a free handle", async () => {
    const firestore = makeFakeFirestore({});
    const result = await applySetHandle("u-1", { handle: "alex" }, { firestore });
    assert.equal(result.ok, true);
    assert.equal(result.handle, "alex");
    assert.equal(firestore._data.get("handles/alex").uid, "u-1");
    assert.equal(firestore._data.get("users/u-1").handle, "alex");
  });

  it("normalizes to lowercase and trims", async () => {
    const firestore = makeFakeFirestore({});
    const result = await applySetHandle("u-1", { handle: "  ALEX  " }, { firestore });
    assert.equal(result.handle, "alex");
  });

  it("rejects when handle is taken by another user", async () => {
    const firestore = makeFakeFirestore({
      "handles/alex": { uid: "u-other" },
    });
    await assert.rejects(
      () => applySetHandle("u-1", { handle: "alex" }, { firestore }),
      (err) => err && err.code === "already-exists",
    );
  });

  it("allows same user to re-claim same handle (idempotent)", async () => {
    const firestore = makeFakeFirestore({
      "handles/alex": { uid: "u-1" },
      "users/u-1": { handle: "alex" },
    });
    const result = await applySetHandle("u-1", { handle: "alex" }, { firestore });
    assert.equal(result.ok, true);
  });

  it("releases previous handle when changing", async () => {
    const firestore = makeFakeFirestore({
      "handles/old_one": { uid: "u-1" },
      "users/u-1": { handle: "old_one" },
    });
    await applySetHandle("u-1", { handle: "new_one" }, { firestore });
    assert.equal(firestore._data.has("handles/old_one"), false);
    assert.equal(firestore._data.get("handles/new_one").uid, "u-1");
    assert.equal(firestore._data.get("users/u-1").handle, "new_one");
  });

  it("rejects invalid characters", async () => {
    const firestore = makeFakeFirestore({});
    await assert.rejects(
      () => applySetHandle("u-1", { handle: "Alex Lab" }, { firestore }),
      (err) => err && err.code === "invalid-argument",
    );
  });

  it("rejects reserved words", async () => {
    const firestore = makeFakeFirestore({});
    await assert.rejects(
      () => applySetHandle("u-1", { handle: "admin" }, { firestore }),
      (err) => err && err.code === "failed-precondition",
    );
  });

  it("rejects too-short handle", async () => {
    const firestore = makeFakeFirestore({});
    await assert.rejects(
      () => applySetHandle("u-1", { handle: "ab" }, { firestore }),
      (err) => err && err.code === "invalid-argument",
    );
  });
});

describe("applyUpdateProfile", () => {
  it("merges fields into /users/{uid}", async () => {
    const firestore = makeFakeFirestore({});
    const result = await applyUpdateProfile(
      "u-1",
      { displayName: "Alex", bio: "Color science", website: "https://example.com" },
      { firestore },
    );
    assert.equal(result.ok, true);
    const doc = firestore._data.get("users/u-1");
    assert.equal(doc.displayName, "Alex");
    assert.equal(doc.bio, "Color science");
    assert.equal(doc.website, "https://example.com");
  });

  it("preserves untouched fields", async () => {
    const firestore = makeFakeFirestore({
      "users/u-1": { displayName: "Alex", handle: "alex" },
    });
    await applyUpdateProfile("u-1", { bio: "new bio" }, { firestore });
    const doc = firestore._data.get("users/u-1");
    assert.equal(doc.handle, "alex");
    assert.equal(doc.displayName, "Alex");
    assert.equal(doc.bio, "new bio");
  });

  it("rejects oversized displayName", async () => {
    const firestore = makeFakeFirestore({});
    await assert.rejects(
      () => applyUpdateProfile("u-1", { displayName: "x".repeat(100) }, { firestore }),
      (err) => err && err.code === "invalid-argument",
    );
  });

  it("stores avatar URLs and object key", async () => {
    const firestore = makeFakeFirestore({});
    await applyUpdateProfile(
      "u-1",
      {
        avatarURL: "https://cdn.moodit.test/users/u-1/avatar/a.jpg",
        photoURL: "https://cdn.moodit.test/users/u-1/avatar/a.jpg",
        avatarObjectKey: "users/u-1/avatar/a.jpg",
      },
      { firestore },
    );
    const doc = firestore._data.get("users/u-1");
    assert.equal(doc.avatarURL, "https://cdn.moodit.test/users/u-1/avatar/a.jpg");
    assert.equal(doc.photoURL, "https://cdn.moodit.test/users/u-1/avatar/a.jpg");
    assert.equal(doc.avatarObjectKey, "users/u-1/avatar/a.jpg");
  });

  it("rejects empty payload? — actually empty is allowed (no-op merge)", async () => {
    const firestore = makeFakeFirestore({});
    const result = await applyUpdateProfile("u-1", {}, { firestore });
    assert.equal(result.ok, true);
  });
});

describe("applyProfileAvatarUploadInit", () => {
  it("returns a presigned PUT target and public URL", async () => {
    const result = await applyProfileAvatarUploadInit(
      "u-1",
      { contentType: "image/jpeg", imageBytes: 1234 },
      {
        publicBaseURL: "https://cdn.moodit.test/media/",
        now: () => 123456,
        uuid: () => "avatar-id",
        presignPutURL: async (key, options) => ({
          url: `https://r2.moodit.test/${key}`,
          headers: { "content-type": options.contentType ?? "" },
          expiresAt: 654321,
        }),
      },
    );

    assert.equal(result.objectKey, "users/u-1/avatar/123456-avatar-id.jpg");
    assert.equal(result.uploadUrl, "https://r2.moodit.test/users/u-1/avatar/123456-avatar-id.jpg");
    assert.deepEqual(result.uploadHeaders, { "content-type": "image/jpeg" });
    assert.equal(result.publicURL, "https://cdn.moodit.test/media/users/u-1/avatar/123456-avatar-id.jpg");
    assert.equal(result.expiresAt, 654321);
  });

  it("rejects oversized images", async () => {
    await assert.rejects(
      () => applyProfileAvatarUploadInit(
        "u-1",
        { contentType: "image/jpeg", imageBytes: 1_500_001 },
        {
          publicBaseURL: "https://cdn.moodit.test",
          presignPutURL: async () => {
            throw new Error("should not sign");
          },
        },
      ),
      (err) => err && err.code === "invalid-argument",
    );
  });

  it("requires public base URL configuration", async () => {
    await assert.rejects(
      () => applyProfileAvatarUploadInit(
        "u-1",
        { contentType: "image/png", imageBytes: 128 },
        {
          publicBaseURL: "",
          presignPutURL: async () => {
            throw new Error("should not sign");
          },
        },
      ),
      (err) => err && err.code === "internal",
    );
  });
});

describe("applyDeleteAccount", () => {
  it("soft-deletes the user doc with deletedAt + cleared public fields", async () => {
    const firestore = makeFakeFirestore({
      "users/u-1": { displayName: "Alex", handle: "alex", bio: "hello" },
    });
    const result = await applyDeleteAccount("u-1", { firestore });
    assert.equal(result.ok, true);
    const doc = firestore._data.get("users/u-1");
    assert.ok(doc.deletedAt);
    assert.equal(doc.displayName, "");
    assert.equal(doc.handle, "");
    assert.equal(doc.bio, "");
  });
});
