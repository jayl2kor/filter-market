/**
 * Unit tests for `applyRecordUse` — exercises the cooldown + transaction logic
 * with an in-memory Firestore mock so the full Cloud Function stack does not need
 * the emulator running.
 *
 * Live emulator integration is tracked in TODO.md §3.5 and runs from
 * `firebase emulators:exec --only firestore,functions "npm run test:emulator"`
 * once added. This file proves the policy logic itself is correct.
 */
import { describe, it, beforeEach } from "node:test";
import assert from "node:assert/strict";

import { applyRecordDownload, applyRecordUse, RECORD_USE_COOLDOWN_MS } from "../lib/http/filters.js";

function makeFakeFirestore(initialDocs = {}) {
  const data = new Map(Object.entries(initialDocs));

  const docRef = (path) => ({
    _path: path,
    collection(name) {
      return collectionRef(`${path}/${name}`);
    },
  });

  const collectionRef = (path) => ({
    _path: path,
    doc(id) {
      return docRef(`${path}/${id}`);
    },
  });

  const snapshot = (path) => {
    const record = data.get(path);
    return {
      exists: record !== undefined,
      get(field) {
        return record ? record[field] : undefined;
      },
    };
  };

  const tx = {
    async get(ref) {
      return snapshot(ref._path);
    },
    update(ref, patch) {
      const current = data.get(ref._path);
      if (!current) {
        throw new Error(`update() on missing doc ${ref._path}`);
      }
      data.set(ref._path, { ...current, ...patch });
    },
    set(ref, doc, opts) {
      const merged = opts && opts.merge ? data.get(ref._path) : undefined;
      data.set(ref._path, { ...(merged ?? {}), ...doc });
    },
  };

  return {
    _data: data,
    collection(name) {
      return collectionRef(name);
    },
    async runTransaction(fn) {
      return fn(tx);
    },
  };
}

describe("applyRecordUse", () => {
  const filterPath = "filters/sunset-1973";
  const usePath = "filters/sunset-1973/uses/u-han";

  let firestore;
  let nowMs;

  beforeEach(() => {
    nowMs = Date.UTC(2026, 4, 7, 12, 0, 0);
    firestore = makeFakeFirestore({
      [filterPath]: { useCount: 5 },
    });
  });

  it("counts the first call and persists the cooldown row", async () => {
    const result = await applyRecordUse(
      "u-han",
      { filterId: "sunset-1973" },
      { firestore, now: () => new Date(nowMs) }
    );

    assert.deepEqual(result, {
      filterId: "sunset-1973",
      useCount: 6,
      counted: true,
    });
    assert.equal(firestore._data.get(filterPath).useCount, 6);
    const useDoc = firestore._data.get(usePath);
    assert.ok(useDoc, "use doc should be created");
    assert.equal(useDoc.lastUseAt instanceof Date, true);
    assert.equal(useDoc.lastUseAt.getTime(), nowMs);
  });

  it("does NOT double-count a second call within the cooldown window", async () => {
    await applyRecordUse(
      "u-han",
      { filterId: "sunset-1973" },
      { firestore, now: () => new Date(nowMs) }
    );

    // Second call 5 minutes later — well inside the 1h cooldown.
    const fiveMinutesLater = nowMs + 5 * 60 * 1000;
    const second = await applyRecordUse(
      "u-han",
      { filterId: "sunset-1973" },
      { firestore, now: () => new Date(fiveMinutesLater) }
    );

    assert.deepEqual(second, {
      filterId: "sunset-1973",
      useCount: 6, // unchanged from first call's increment
      counted: false,
    });
    assert.equal(firestore._data.get(filterPath).useCount, 6);
  });

  it("counts again once the cooldown expires", async () => {
    await applyRecordUse(
      "u-han",
      { filterId: "sunset-1973" },
      { firestore, now: () => new Date(nowMs) }
    );

    const wayLater = nowMs + RECORD_USE_COOLDOWN_MS + 1;
    const second = await applyRecordUse(
      "u-han",
      { filterId: "sunset-1973" },
      { firestore, now: () => new Date(wayLater) }
    );

    assert.deepEqual(second, {
      filterId: "sunset-1973",
      useCount: 7,
      counted: true,
    });
    assert.equal(firestore._data.get(filterPath).useCount, 7);
  });

  it("counts independently for two different users on the same filter", async () => {
    await applyRecordUse(
      "u-alice",
      { filterId: "sunset-1973" },
      { firestore, now: () => new Date(nowMs) }
    );
    await applyRecordUse(
      "u-bob",
      { filterId: "sunset-1973" },
      { firestore, now: () => new Date(nowMs) }
    );

    assert.equal(firestore._data.get(filterPath).useCount, 7);
  });

  it("rejects an invalid filterId payload", async () => {
    await assert.rejects(
      () =>
        applyRecordUse(
          "u-han",
          { filterId: "" },
          { firestore, now: () => new Date(nowMs) }
        ),
      (err) => err.code === "invalid-argument" || /String must contain/.test(err.message)
    );
  });

  it("returns not-found if the filter doc does not exist", async () => {
    const empty = makeFakeFirestore();
    await assert.rejects(
      () =>
        applyRecordUse(
          "u-han",
          { filterId: "missing-filter" },
          { firestore: empty, now: () => new Date(nowMs) }
        ),
      (err) => err.code === "not-found" || /not found/.test(err.message)
    );
  });
});

describe("applyRecordDownload", () => {
  const filterPath = "filters/sunset-1973";
  const downloadPath = "filters/sunset-1973/downloads/u-han";

  it("counts the first download and persists the per-user ledger row", async () => {
    const nowMs = Date.UTC(2026, 4, 7, 12, 0, 0);
    const firestore = makeFakeFirestore({
      [filterPath]: { downloadCount: 0, useCount: 9_100 },
    });

    const result = await applyRecordDownload(
      "u-han",
      { filterId: "sunset-1973" },
      { firestore, now: () => new Date(nowMs) }
    );

    assert.deepEqual(result, {
      filterId: "sunset-1973",
      downloadCount: 1,
      counted: true,
    });
    assert.equal(firestore._data.get(filterPath).downloadCount, 1);
    assert.equal(firestore._data.get(filterPath).useCount, 9_100);
    assert.equal(firestore._data.get(downloadPath).downloadedAt.getTime(), nowMs);
  });

  it("does not double-count the same user's repeated download", async () => {
    const nowMs = Date.UTC(2026, 4, 7, 12, 0, 0);
    const firestore = makeFakeFirestore({
      [filterPath]: { downloadCount: 4 },
    });

    await applyRecordDownload(
      "u-han",
      { filterId: "sunset-1973" },
      { firestore, now: () => new Date(nowMs) }
    );
    const second = await applyRecordDownload(
      "u-han",
      { filterId: "sunset-1973" },
      { firestore, now: () => new Date(nowMs + 1_000) }
    );

    assert.deepEqual(second, {
      filterId: "sunset-1973",
      downloadCount: 5,
      counted: false,
    });
    assert.equal(firestore._data.get(filterPath).downloadCount, 5);
  });

  it("rejects missing filters", async () => {
    const firestore = makeFakeFirestore();

    await assert.rejects(
      () =>
        applyRecordDownload(
          "u-han",
          { filterId: "missing-filter" },
          { firestore, now: () => new Date() }
        ),
      (err) => err.code === "not-found" || /not found/.test(err.message)
    );
  });
});
