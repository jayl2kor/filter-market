#!/usr/bin/env node
/**
 * Audit (and optionally reset) the useCount / downloadCount fields on every
 * /filters/{id} document.
 *
 * Why this exists
 *   The bundled seed manifest at Sources/Marketplace/Resources/SeedFilters/manifest.json
 *   used to ship hardcoded inflated useCount / downloadCount values (introduced in
 *   commit 9efe130). The seed-mooditor-filters.mjs script does NOT push manifest
 *   counts to Firestore (it preserves existingData?.downloadCount ?? 0), but the
 *   bundled values still flashed through the BundleSeedFilterRepository fast-path
 *   and any code path that fell back to local filters when Firestore fetch failed.
 *
 *   The manifest has now been zeroed. This script verifies what Firestore actually
 *   stores per filter, and can optionally normalise any filter whose download
 *   count exceeds a sanity threshold (default 50).
 *
 * Usage
 *   # 1. Dry-run audit only (default — never writes)
 *   node functions/scripts/audit-filter-counts.mjs
 *
 *   # 2. Audit + reset useCount/downloadCount for filters above the sanity
 *   #    threshold to 0 (also clears the /downloads and /uses subcollections so
 *   #    the idempotency ledger matches the counter).
 *   node functions/scripts/audit-filter-counts.mjs --apply
 *
 *   # 3. Customise the sanity threshold (e.g. anything over 100 is suspicious).
 *   node functions/scripts/audit-filter-counts.mjs --threshold 100
 *
 * Auth: relies on Application Default Credentials. Easiest path is:
 *   gcloud auth application-default login --project moodit-a9e7a
 * or set GOOGLE_APPLICATION_CREDENTIALS to a service-account JSON.
 */

import admin from "firebase-admin";

function parseArgs(argv) {
  const flags = { apply: false, projectId: null, threshold: 50 };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--apply") flags.apply = true;
    else if (arg === "--project") flags.projectId = argv[++i];
    else if (arg === "--threshold") flags.threshold = Number(argv[++i]);
    else if (arg === "--help" || arg === "-h") {
      console.log(
        "Usage: node functions/scripts/audit-filter-counts.mjs [--apply] [--threshold N] [--project ID]",
      );
      process.exit(0);
    } else {
      console.error(`Unknown flag: ${arg}`);
      process.exit(2);
    }
  }
  if (!Number.isFinite(flags.threshold) || flags.threshold < 0) {
    console.error(`Invalid --threshold: ${flags.threshold}`);
    process.exit(2);
  }
  return flags;
}

async function clearSubcollection(ref, name) {
  const sub = ref.collection(name);
  const snap = await sub.get();
  if (snap.empty) return 0;
  const batch = sub.firestore.batch();
  snap.docs.forEach((doc) => batch.delete(doc.ref));
  await batch.commit();
  return snap.size;
}

async function main() {
  const flags = parseArgs(process.argv.slice(2));
  const projectId =
    flags.projectId ?? process.env.GCLOUD_PROJECT ?? process.env.GOOGLE_CLOUD_PROJECT ?? null;
  admin.initializeApp(projectId ? { projectId } : {});
  const db = admin.firestore();

  const snap = await db.collection("filters").get();
  if (snap.empty) {
    console.log("No /filters documents found.");
    return;
  }

  const rows = [];
  snap.forEach((doc) => {
    const data = doc.data();
    rows.push({
      id: doc.id,
      title: data.title ?? "(no title)",
      status: data.status ?? "?",
      seed: !!data.seed,
      useCount: Number(data.useCount ?? 0),
      downloadCount: Number(data.downloadCount ?? 0),
    });
  });
  rows.sort((a, b) => b.downloadCount - a.downloadCount);

  const overUse = rows.filter((r) => r.useCount > flags.threshold);
  const overDownload = rows.filter((r) => r.downloadCount > flags.threshold);

  console.log(`Project: ${projectId ?? "(default ADC project)"}`);
  console.log(`/filters documents: ${rows.length}`);
  console.log(`useCount > ${flags.threshold}: ${overUse.length} doc(s)`);
  console.log(`downloadCount > ${flags.threshold}: ${overDownload.length} doc(s)`);
  console.log("");
  console.log(
    "  id (tail)     title                  status      seed   useCount  downloadCount",
  );
  console.log("  ".padEnd(2) + "-".repeat(78));
  for (const r of rows) {
    const tail = r.id.slice(-12);
    const flag = r.downloadCount > flags.threshold || r.useCount > flags.threshold ? "!" : " ";
    console.log(
      `${flag} ${tail}  ${r.title.padEnd(22).slice(0, 22)}  ${(r.status ?? "?").padEnd(10)}  ${r.seed ? "yes " : "no  "}  ${String(r.useCount).padStart(8)}  ${String(r.downloadCount).padStart(13)}`,
    );
  }
  console.log("");

  if (!flags.apply) {
    console.log("Dry-run only — pass --apply to reset flagged docs.");
    return;
  }

  const targets = rows.filter(
    (r) => r.useCount > flags.threshold || r.downloadCount > flags.threshold,
  );
  if (targets.length === 0) {
    console.log("Nothing to reset.");
    return;
  }

  console.log(`Resetting ${targets.length} doc(s)...`);
  let done = 0;
  for (const target of targets) {
    const ref = db.collection("filters").doc(target.id);
    await ref.update({
      useCount: 0,
      downloadCount: 0,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    // Clear idempotency ledgers so the next legitimate download/use can count
    // again and the public counter stays consistent with the per-user records.
    const usesCleared = await clearSubcollection(ref, "uses");
    const downloadsCleared = await clearSubcollection(ref, "downloads");
    done += 1;
    console.log(
      `  [${done}/${targets.length}] ${target.id.slice(-12)} ${target.title.padEnd(20).slice(0, 20)} reset (uses cleared: ${usesCleared}, downloads cleared: ${downloadsCleared})`,
    );
  }
  console.log("");
  console.log(`Done. Reset ${done} filter doc(s) and their per-user ledgers.`);
}

main().catch((error) => {
  console.error("audit failed:", error);
  process.exit(1);
});
