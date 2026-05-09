#!/usr/bin/env node
/**
 * Seed the 20 mooditor default filters into Firestore + Cloudflare R2.
 *
 * Reads the bundled seed manifest (Sources/Marketplace/Resources/SeedFilters/manifest.json)
 * plus the matching .cube packages produced by `scripts/generate_seed_luts.py` and:
 *   1. Uploads each .cube as `filters/{authorUid}/{filterId}.fmpkg` to R2
 *   2. Verifies via HeadObject that the upload landed with the declared sha256
 *   3. Writes /filters/{filterId} in Firestore with status="approved", priceCoins=0,
 *      and the metadata fields read by `applyGetFilterDetail` + `FirestoreFilterRepository.decode`
 *
 * Idempotent: re-running overwrites the same R2 object key and Firestore doc.
 *
 * Default mode is DRY-RUN — no remote writes happen unless `--apply` is passed.
 *
 * Required environment variables (load via `firebase functions:secrets:access NAME`):
 *   R2_ENDPOINT
 *   R2_ACCESS_KEY_ID
 *   R2_SECRET_ACCESS_KEY
 *   R2_BUCKET
 *   R2_PUBLIC_BASE_URL              (optional — only used to log the public URL)
 *   GOOGLE_APPLICATION_CREDENTIALS  (or `gcloud auth application-default login`)
 *
 * Usage:
 *   # 1. Generate fresh .cube packages alongside the bundle PNGs
 *   .venv-luts/bin/python scripts/generate_seed_luts.py
 *
 *   # 2. Dry-run (no remote writes — preview the plan)
 *   node functions/scripts/seed-mooditor-filters.mjs
 *
 *   # 3. Real apply (after exporting R2 secrets via firebase CLI)
 *   node functions/scripts/seed-mooditor-filters.mjs --apply
 */

import { readFileSync, existsSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { createHash } from "node:crypto";
import { fileURLToPath } from "node:url";
import readline from "node:readline";

import admin from "firebase-admin";
import {
  S3Client,
  PutObjectCommand,
  HeadObjectCommand,
} from "@aws-sdk/client-s3";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const REPO_ROOT = resolve(__dirname, "../..");

const MANIFEST_PATH = resolve(
  REPO_ROOT,
  "Sources/Marketplace/Resources/SeedFilters/manifest.json",
);
const CUBE_DIR = resolve(REPO_ROOT, "dist/seed-filter-cubes");
const PACKAGE_CONTENT_TYPE = "application/x-moodit-package";

// Filter UUID → cube file stem (matches RECIPES in scripts/generate_seed_luts.py).
// Built from the manifest at runtime — see `manifestToSeed()`.

function parseArgs(argv) {
  const flags = { apply: false, projectId: null, force: false };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--apply") flags.apply = true;
    else if (arg === "--force") flags.force = true;
    else if (arg === "--project") flags.projectId = argv[++i];
    else if (arg === "--help" || arg === "-h") {
      printUsage();
      process.exit(0);
    } else {
      console.error(`Unknown flag: ${arg}`);
      printUsage();
      process.exit(2);
    }
  }
  return flags;
}

function printUsage() {
  console.log(`Usage: node functions/scripts/seed-mooditor-filters.mjs [--apply] [--force] [--project <id>]

  --apply       Actually write to Firestore + R2. Without this flag the script
                only reports what would happen (dry-run).
  --force       Skip the interactive confirmation prompt (use carefully).
  --project ID  Override Firebase project ID (default: from .firebaserc / GCLOUD_PROJECT).
`);
}

function requireEnv(name) {
  const value = process.env[name];
  if (!value || value.length === 0) {
    throw new Error(`missing required env var: ${name}`);
  }
  return value;
}

function readManifest() {
  if (!existsSync(MANIFEST_PATH)) {
    throw new Error(`seed manifest not found at ${MANIFEST_PATH}`);
  }
  const raw = readFileSync(MANIFEST_PATH, "utf8");
  const data = JSON.parse(raw);
  if (!Array.isArray(data) || data.length === 0) {
    throw new Error("seed manifest is empty");
  }
  return data;
}

/**
 * Map a manifest entry to a seed plan: derives the .cube file stem from the
 * lutFile slug (PNG basename → matches the python generator's slug list).
 */
function manifestToSeed(entry) {
  const lutFile = entry?.engine?.lutFile;
  if (typeof lutFile !== "string") {
    throw new Error(`entry ${entry?.id} missing engine.lutFile`);
  }
  const stem = lutFile
    .replace(/^.*\//, "")
    .replace(/\.png$/i, "");
  const cubePath = resolve(CUBE_DIR, `${stem}.cube`);
  if (!existsSync(cubePath)) {
    throw new Error(
      `missing cube package for ${entry.id} (${stem}) — run "python scripts/generate_seed_luts.py" first`,
    );
  }
  const bytes = readFileSync(cubePath);
  const sha256Hex = createHash("sha256").update(bytes).digest("hex");
  const sha256B64 = createHash("sha256").update(bytes).digest("base64");
  const authorUid = entry?.author?.uid;
  if (!authorUid) {
    throw new Error(`entry ${entry.id} missing author.uid`);
  }
  return {
    filterId: entry.id,
    title: entry.title,
    version: entry.version ?? "1.0.0",
    category: entry.category,
    tags: Array.isArray(entry.tags) ? entry.tags : [],
    authorUid,
    authorDisplayName: entry?.author?.displayName ?? "mooditor",
    objectKey: `filters/${authorUid}/${entry.id}.fmpkg`,
    bytes,
    packageBytes: bytes.length,
    contentSha256B64: sha256B64,
    contentSha256Hex: sha256Hex,
    lutSize: entry?.engine?.lutSize ?? 33,
    engineType: entry?.engine?.type ?? "lut+params",
    minAppVersion: entry?.engine?.minAppVersion ?? "1.0.0",
    minIOSVersion: entry?.engine?.minIOSVersion ?? "17.0",
  };
}

function buildR2Client() {
  return new S3Client({
    region: "auto",
    endpoint: requireEnv("R2_ENDPOINT"),
    credentials: {
      accessKeyId: requireEnv("R2_ACCESS_KEY_ID"),
      secretAccessKey: requireEnv("R2_SECRET_ACCESS_KEY"),
    },
    forcePathStyle: false,
  });
}

async function uploadPackage(client, bucket, plan) {
  await client.send(
    new PutObjectCommand({
      Bucket: bucket,
      Key: plan.objectKey,
      Body: plan.bytes,
      ContentType: PACKAGE_CONTENT_TYPE,
      ChecksumSHA256: plan.contentSha256B64,
    }),
  );
  // Verify the object landed.
  const head = await client.send(
    new HeadObjectCommand({
      Bucket: bucket,
      Key: plan.objectKey,
      ChecksumMode: "ENABLED",
    }),
  );
  if (head.ContentLength !== plan.packageBytes) {
    throw new Error(
      `R2 verify failed for ${plan.objectKey}: ContentLength=${head.ContentLength} expected ${plan.packageBytes}`,
    );
  }
}

async function writeFirestoreDoc(db, plan) {
  const ref = db.collection("filters").doc(plan.filterId);
  const now = admin.firestore.FieldValue.serverTimestamp();
  const existing = await ref.get();
  const existingData = existing.exists ? existing.data() : null;

  const doc = {
    authorUid: plan.authorUid,
    title: plan.title,
    version: plan.version,
    category: plan.category,
    status: "approved",
    tags: plan.tags,
    priceCoins: 0,
    useCount: existingData?.useCount ?? 0,
    downloadCount: existingData?.downloadCount ?? 0,
    ratingAvg: existingData?.ratingAvg ?? null,
    reviewCount: existingData?.reviewCount ?? 0,
    likeCount: existingData?.likeCount ?? 0,
    sampleCount: existingData?.sampleCount ?? 0,
    coverURL: existingData?.coverURL ?? null,
    signatureSampleURL: existingData?.signatureSampleURL ?? null,
    description: existingData?.description ?? "",
    objectKey: plan.objectKey,
    packageBytes: plan.packageBytes,
    contentSha256: plan.contentSha256Hex,
    contentSha256Base64: plan.contentSha256B64,
    engine: {
      type: plan.engineType,
      minAppVersion: plan.minAppVersion,
      minIOSVersion: plan.minIOSVersion,
      lutSize: plan.lutSize,
    },
    author: {
      uid: plan.authorUid,
      displayName: plan.authorDisplayName,
    },
    createdAt: existingData?.createdAt ?? now,
    updatedAt: now,
    seed: true, // marker so we can find/clean these later if needed
  };

  await ref.set(doc, { merge: false });
  return existing.exists ? "updated" : "created";
}

async function confirm(question) {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  return await new Promise((resolveAnswer) => {
    rl.question(question, (answer) => {
      rl.close();
      resolveAnswer(answer.trim().toLowerCase());
    });
  });
}

async function main() {
  const flags = parseArgs(process.argv.slice(2));

  const manifest = readManifest();
  const plans = manifest.map(manifestToSeed);

  console.log("=".repeat(70));
  console.log(`mooditor seed plan: ${plans.length} filters`);
  console.log("=".repeat(70));
  for (const p of plans) {
    console.log(
      `  ${p.filterId.slice(-12)}  ${p.title.padEnd(18)}  ${p.category.padEnd(10)}  ${(p.packageBytes / 1024).toFixed(0).padStart(4)} KB  sha256:${p.contentSha256Hex.slice(0, 12)}…`,
    );
  }
  console.log("");

  if (!flags.apply) {
    console.log("DRY-RUN: pass --apply to actually write to Firestore + R2.");
    console.log("  • R2 path pattern: filters/{authorUid}/{filterId}.fmpkg");
    console.log("  • Firestore path:  /filters/{filterId}");
    console.log("");
    return;
  }

  const projectId = flags.projectId ?? process.env.GCLOUD_PROJECT ?? null;
  console.log(`APPLY mode — target project: ${projectId ?? "(default from ADC / .firebaserc)"}`);
  console.log(`         R2 bucket: ${process.env.R2_BUCKET ?? "(missing)"}`);
  console.log(`         R2 endpoint: ${process.env.R2_ENDPOINT ?? "(missing)"}`);
  console.log("");

  if (!flags.force) {
    const answer = await confirm(
      "Type 'apply' to write 20 docs + 20 R2 objects in this project: ",
    );
    if (answer !== "apply") {
      console.log("aborted.");
      process.exit(1);
    }
  }

  const r2Bucket = requireEnv("R2_BUCKET");
  const r2 = buildR2Client();
  admin.initializeApp(projectId ? { projectId } : {});
  const db = admin.firestore();

  let r2Done = 0;
  let fsDone = 0;
  for (const plan of plans) {
    process.stdout.write(`  [${(r2Done + 1).toString().padStart(2)}/${plans.length}] ${plan.title.padEnd(18)} `);
    try {
      await uploadPackage(r2, r2Bucket, plan);
      r2Done += 1;
      const verb = await writeFirestoreDoc(db, plan);
      fsDone += 1;
      console.log(`R2 ✓  Firestore ${verb} ✓`);
    } catch (error) {
      console.log(`FAILED: ${(error instanceof Error ? error.message : String(error))}`);
      throw error;
    }
  }

  console.log("");
  console.log(`✓ uploaded ${r2Done}/${plans.length} packages to R2`);
  console.log(`✓ wrote   ${fsDone}/${plans.length} docs to Firestore`);
  console.log("");
  console.log("Next: open the marketplace tab in the app — the 20 mooditor filters");
  console.log("should appear under Trending/New, and detail/download should work end-to-end.");
}

main().catch((error) => {
  console.error("seed failed:", error);
  process.exit(1);
});
