# Seeding mooditor default filters

This guide walks through installing the 20 mooditor-authored default filters into
Firestore + Cloudflare R2 so they are downloadable end-to-end through the
production app.

The pipeline:

```
scripts/generate_seed_luts.py   →  20 PNG (bundled) + 20 .cube (R2 packages)
                                        │
                                        ▼
functions/scripts/seed-mooditor-filters.mjs
   → R2 PUT     filters/{authorUid}/{filterId}.fmpkg  (with sha256 checksum)
   → Firestore  /filters/{filterId}                  (status="approved", priceCoins=0)
```

The Node admin script is **idempotent** (re-running overwrites the same R2 object
key + Firestore doc) and **dry-run by default** — no remote writes happen until
you pass `--apply` and confirm at the prompt.

## 1. Prerequisites

### 1.1 R2 secrets

Pull the Cloudflare R2 secrets the cloud functions already use into your shell:

```bash
export R2_ENDPOINT=$(firebase functions:secrets:access R2_ENDPOINT)
export R2_ACCESS_KEY_ID=$(firebase functions:secrets:access R2_ACCESS_KEY_ID)
export R2_SECRET_ACCESS_KEY=$(firebase functions:secrets:access R2_SECRET_ACCESS_KEY)
export R2_BUCKET=$(firebase functions:secrets:access R2_BUCKET)
export R2_PUBLIC_BASE_URL=$(firebase functions:secrets:access R2_PUBLIC_BASE_URL)
```

> If your Firebase CLI is logged into multiple projects, prefix with
> `firebase use moodit-a9e7a` first so the secrets resolve from prod.

### 1.2 Firebase Admin credentials

Either use Application Default Credentials (recommended for one-off seeding):

```bash
gcloud auth application-default login
gcloud config set project moodit-a9e7a
```

…or point `GOOGLE_APPLICATION_CREDENTIALS` at a service-account JSON key with
Firestore write permission on the project.

### 1.3 Node + Python deps

```bash
# Python (one-off, creates .venv-luts at the repo root)
python3 -m venv .venv-luts
.venv-luts/bin/pip install --quiet numpy Pillow

# Node (already installed in the functions/ workspace)
cd functions && npm install
```

## 2. Generate LUT packages

```bash
.venv-luts/bin/python scripts/generate_seed_luts.py
```

Outputs:
- `Sources/Marketplace/Resources/SeedFilters/luts/*.png` — 20 PNG LUTs bundled
  with the iOS app (used by `BundleSeedFilterRepository`)
- `dist/seed-filter-cubes/*.cube` — 20 `.cube` text files uploaded to R2 as
  `.fmpkg` packages (~948 KB each)

The script is deterministic — re-running produces byte-identical PNGs/cubes.

## 3. Dry-run the seeder

```bash
node functions/scripts/seed-mooditor-filters.mjs
```

Prints the 20-filter plan with computed sha256 hashes. Nothing is written.

## 4. Apply

```bash
node functions/scripts/seed-mooditor-filters.mjs --apply
```

Asks for an interactive `apply` confirmation. After confirming:

- For each filter: `PutObject` to R2 (with sha256 checksum) → `HeadObject` verify →
  Firestore `set()` on `/filters/{filterId}`.
- Existing useCount / downloadCount / ratingAvg are preserved on re-run; createdAt
  is preserved on first write and not overwritten on subsequent runs.

Pass `--force` to skip the prompt (only when scripted).

## 5. Verify

After `--apply`, smoke-test in the prod app:

1. Cold-start the app → marketplace home should show the 20 mooditor filters
   under "트렌딩" / "새로 들어온 필터".
2. Tap one (e.g. `Sunlit Portra`) → detail screen should load *and stay*
   (no notFound regression — see issue #273).
3. Tap "무료 다운로드" → `getFilterDetail` returns a presigned R2 URL → download
   completes → checksum verifies → filter appears in 저장됨 tab.

You can also verify directly in Firestore:

```bash
firebase firestore:read --project moodit-a9e7a 'filters' --limit 30 \
  --query 'where authorUid == "J14Dg6JaH0M25xpcOkCEMJH3qFy1"'
```

…or in the Cloud Console (`https://console.firebase.google.com/project/moodit-a9e7a/firestore/data/~2Ffilters`).

## 6. Rollback

If you need to remove the seeded filters:

```bash
# Destructive — review the doc IDs first.
firebase firestore:delete --project moodit-a9e7a \
  'filters' --where 'seed,==,true' --recursive --force
```

R2 objects can be left in place (orphaned R2 objects don't cost much, and a future
re-seed will overwrite them).

## Troubleshooting

| Symptom | Cause |
|---|---|
| `missing required env var: R2_ENDPOINT` | R2 secrets not exported in current shell — see §1.1 |
| `missing cube package for ... — run python scripts/generate_seed_luts.py first` | `.cube` files not generated — run §2 |
| `Could not load default credentials` | `gcloud auth application-default login` not run, or wrong project — see §1.2 |
| `PERMISSION_DENIED: Missing or insufficient permissions` | Service-account doesn't have `roles/datastore.user` on the project |
| Apply succeeds but app still shows old data | iOS `FilterLibraryStore` caches `filters` for the session — kill & relaunch the app, or pull-to-refresh on marketplace home |

## Notes

- The `seed: true` marker on every doc lets future migrations target only these
  documents (e.g. wholesale recreation when the LUT recipes change).
- `engine.lutFile` in the Firestore doc points at the bundle path
  (`SeedFilters/luts/{slug}.png`) so `BundleSeedFilterRepository` keeps working
  if the device is offline. The R2 `.fmpkg` is the canonical download source.
- The package format is currently raw `.cube` text. If `.fmpkg` evolves into a
  binary archive (e.g. tar/zip with manifest.json + lut.cube + cover.jpg), update
  the python `save_lut_cube` step and the node uploader's `ContentType` header
  together.
