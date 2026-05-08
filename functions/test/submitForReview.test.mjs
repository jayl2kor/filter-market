import { describe, it } from "node:test";
import assert from "node:assert/strict";

import { applySubmitForReview } from "../lib/http/filters.js";

function makeFakeFirestore(initial = {}) {
  const data = new Map(Object.entries(initial));
  const docRef = (path) => ({
    _path: path,
    async get() {
      const record = data.get(path);
      return { exists: record !== undefined, data: () => record };
    },
    async update(patch) {
      const current = data.get(path);
      if (!current) throw new Error(`update on missing ${path}`);
      data.set(path, { ...current, ...patch });
    },
  });
  return {
    _data: data,
    collection(name) {
      return { doc(id) { return docRef(`${name}/${id}`); } };
    },
  };
}

const validTos = { tosOriginal: true, tosPolicy: true, tosCommercial: true };

describe("applySubmitForReview", () => {
  it("transitions pending_review_pre → pending_review", async () => {
    const firestore = makeFakeFirestore({
      "filters/f-1": { authorUid: "u-1", status: "pending_review_pre" },
    });
    const result = await applySubmitForReview(
      "u-1",
      { filterId: "f-1", ...validTos },
      { firestore },
    );
    assert.equal(result.status, "pending_review");
    assert.equal(firestore._data.get("filters/f-1").status, "pending_review");
  });

  it("rejects when ToS not all accepted", async () => {
    const firestore = makeFakeFirestore({
      "filters/f-1": { authorUid: "u-1", status: "pending_review_pre" },
    });
    await assert.rejects(
      () => applySubmitForReview("u-1", { filterId: "f-1", tosOriginal: true, tosPolicy: false, tosCommercial: true }, { firestore }),
      (err) => err && err.code === "failed-precondition",
    );
  });

  it("rejects non-owner", async () => {
    const firestore = makeFakeFirestore({
      "filters/f-1": { authorUid: "u-other", status: "pending_review_pre" },
    });
    await assert.rejects(
      () => applySubmitForReview("u-1", { filterId: "f-1", ...validTos }, { firestore }),
      (err) => err && err.code === "permission-denied",
    );
  });

  it("rejects when status is wrong", async () => {
    const firestore = makeFakeFirestore({
      "filters/f-1": { authorUid: "u-1", status: "approved" },
    });
    await assert.rejects(
      () => applySubmitForReview("u-1", { filterId: "f-1", ...validTos }, { firestore }),
      (err) => err && err.code === "failed-precondition",
    );
  });
});
