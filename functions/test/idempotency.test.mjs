import { describe, it } from "node:test";
import assert from "node:assert/strict";

import { get, put } from "../lib/lib/idempotency.js";

class FakeRedis {
  constructor(initial = {}) {
    this.data = new Map(Object.entries(initial));
    this.setCalls = [];
  }

  async get(key) {
    return this.data.get(key) ?? null;
  }

  async set(key, value, ex, ttl, nx) {
    this.setCalls.push({ key, value, ex, ttl, nx });
    if (nx === "NX" && this.data.has(key)) {
      return null;
    }
    this.data.set(key, value);
    return "OK";
  }
}

describe("idempotency cache", () => {
  it("returns null on cache miss", async () => {
    const redis = new FakeRedis();
    const result = await get(redis, "u-1", "request-1");
    assert.equal(result, null);
  });

  it("stores and reads cached response by uid and key", async () => {
    const redis = new FakeRedis();
    await put(redis, "u-1", "request-1", {
      status: 201,
      body: { ok: true, id: "abc" },
    });

    assert.deepEqual(await get(redis, "u-1", "request-1"), {
      status: 201,
      body: { ok: true, id: "abc" },
    });
    assert.equal(redis.setCalls[0].ex, "EX");
    assert.equal(redis.setCalls[0].ttl, 86_400);
    assert.equal(redis.setCalls[0].nx, "NX");
  });

  it("does not overwrite an existing cached response", async () => {
    const redis = new FakeRedis();
    await put(redis, "u-1", "request-1", { status: 200, body: { first: true } });
    await put(redis, "u-1", "request-1", { status: 500, body: { second: true } });

    assert.deepEqual(await get(redis, "u-1", "request-1"), {
      status: 200,
      body: { first: true },
    });
  });

  it("scopes identical keys by uid", async () => {
    const redis = new FakeRedis();
    await put(redis, "u-1", "same-key", { status: 200, body: { uid: "u-1" } });
    await put(redis, "u-2", "same-key", { status: 200, body: { uid: "u-2" } });

    assert.deepEqual((await get(redis, "u-1", "same-key"))?.body, { uid: "u-1" });
    assert.deepEqual((await get(redis, "u-2", "same-key"))?.body, { uid: "u-2" });
  });
});
