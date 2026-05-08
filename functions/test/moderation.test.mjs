/**
 * Unit tests for `applyApproveFilter`, `applyRejectFilter`, `applyReportFilter`
 * using an in-memory Firestore stub.
 */
import { describe, it } from "node:test";
import assert from "node:assert/strict";

import {
  applyApproveFilter,
  applyRejectFilter,
  applyReportFilter,
  applyUndoModerationDecision,
} from "../lib/http/moderation.js";

function makeFakeFirestore(initial = {}) {
  const data = new Map(Object.entries(initial));
  let autoId = 0;

  const docRef = (path) => ({
    _path: path,
    id: path.split("/").pop(),
    collection(name) { return collectionRef(`${path}/${name}`); },
    async get() {
      const record = data.get(path);
      return { exists: record !== undefined, data: () => record };
    },
    async set(payload) { data.set(path, { ...(data.get(path) ?? {}), ...payload }); },
    async update(patch) {
      const current = data.get(path);
      if (!current) throw new Error(`update on missing ${path}`);
      const next = { ...current };
      for (const [key, value] of Object.entries(patch)) {
        // Crude FieldValue.increment shim
        if (value && typeof value === "object" && value._increment) {
          next[key] = (next[key] ?? 0) + value._increment;
        } else {
          next[key] = value;
        }
      }
      data.set(path, next);
    },
  });

  const collectionRef = (path) => ({
    doc(id) {
      if (id === undefined) {
        autoId += 1;
        return docRef(`${path}/auto-${autoId}`);
      }
      return docRef(`${path}/${id}`);
    },
  });

  return {
    _data: data,
    collection(name) { return collectionRef(name); },
  };
}

describe("applyApproveFilter", () => {
  it("transitions pending_review → approved", async () => {
    const firestore = makeFakeFirestore({
      "filters/f-1": { status: "pending_review", title: "T" },
    });
    const result = await applyApproveFilter({ filterId: "f-1" }, { firestore });
    assert.equal(result.status, "approved");
    assert.equal(firestore._data.get("filters/f-1").status, "approved");
  });

  it("rejects already-approved filters", async () => {
    const firestore = makeFakeFirestore({
      "filters/f-1": { status: "approved" },
    });
    await assert.rejects(
      () => applyApproveFilter({ filterId: "f-1" }, { firestore }),
      (err) => err && err.code === "failed-precondition",
    );
  });

  it("rejects missing filter", async () => {
    const firestore = makeFakeFirestore({});
    await assert.rejects(
      () => applyApproveFilter({ filterId: "missing" }, { firestore }),
      (err) => err && err.code === "not-found",
    );
  });
});

describe("applyRejectFilter", () => {
  it("transitions pending_review → rejected with reason", async () => {
    const firestore = makeFakeFirestore({
      "filters/f-1": { status: "pending_review" },
    });
    const result = await applyRejectFilter(
      { filterId: "f-1", reason: "policy violation" },
      { firestore },
    );
    assert.equal(result.status, "rejected");
    assert.equal(firestore._data.get("filters/f-1").status, "rejected");
    assert.equal(firestore._data.get("filters/f-1").rejectionReason, "policy violation");
  });

  it("requires non-empty reason", async () => {
    const firestore = makeFakeFirestore({
      "filters/f-1": { status: "pending_review" },
    });
    await assert.rejects(
      () => applyRejectFilter({ filterId: "f-1", reason: "" }, { firestore }),
      (err) => err && err.code === "invalid-argument",
    );
  });
});

describe("applyUndoModerationDecision", () => {
  it("transitions approved → pending_review", async () => {
    const firestore = makeFakeFirestore({
      "filters/f-1": { status: "approved", title: "T" },
    });
    const result = await applyUndoModerationDecision({ filterId: "f-1" }, { firestore });
    assert.equal(result.status, "pending_review");
    assert.equal(firestore._data.get("filters/f-1").status, "pending_review");
  });

  it("transitions rejected → pending_review", async () => {
    const firestore = makeFakeFirestore({
      "filters/f-1": { status: "rejected", rejectionReason: "policy" },
    });
    const result = await applyUndoModerationDecision({ filterId: "f-1" }, { firestore });
    assert.equal(result.status, "pending_review");
    assert.equal(firestore._data.get("filters/f-1").status, "pending_review");
  });

  it("rejects pending filters without a completed decision", async () => {
    const firestore = makeFakeFirestore({
      "filters/f-1": { status: "pending_review" },
    });
    await assert.rejects(
      () => applyUndoModerationDecision({ filterId: "f-1" }, { firestore }),
      (err) => err && err.code === "failed-precondition",
    );
  });
});

describe("applyReportFilter", () => {
  it("creates a report doc for an existing filter", async () => {
    const firestore = makeFakeFirestore({
      "filters/f-1": { status: "approved", reportCount: 0 },
    });
    // Stub FieldValue.increment via patch — our fake handles it via plain numbers.
    const result = await applyReportFilter(
      "u-1",
      { filterId: "f-1", reasonCode: "spam", detail: "bot" },
      { firestore },
    );
    assert.equal(result.ok, true);
    assert.ok(result.reportId);
  });

  it("rejects missing filter", async () => {
    const firestore = makeFakeFirestore({});
    await assert.rejects(
      () => applyReportFilter("u-1", { filterId: "x", reasonCode: "spam" }, { firestore }),
      (err) => err && err.code === "not-found",
    );
  });

  it("validates reasonCode", async () => {
    const firestore = makeFakeFirestore({ "filters/f-1": { status: "approved" } });
    await assert.rejects(
      () => applyReportFilter("u-1", { filterId: "f-1" }, { firestore }),
      (err) => err && err.code === "invalid-argument",
    );
  });
});
