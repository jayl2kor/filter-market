#!/usr/bin/env node
/**
 * Bootstrap script — sets the FIRST admin role on a Firebase Auth user.
 *
 * After this runs once, the bootstrapped admin can grant moderator/admin
 * roles to others via the `setRole` Cloud Function (see functions/src/http/identity.ts).
 *
 * Usage:
 *   1. Download the Firebase Admin SDK service account JSON:
 *      Firebase Console → ⚙️ Project settings → Service accounts → Generate new private key
 *      Save it OUTSIDE the repo (e.g., ~/Documents/secrets/moodit-admin.json).
 *
 *   2. Get the target user's Firebase Auth UID:
 *      Firebase Console → Authentication → Users → click the row → copy "User UID".
 *
 *   3. Run:
 *      node tools/bootstrap-admin.mjs \
 *        --service-account ~/Documents/secrets/moodit-admin.json \
 *        --uid <FIREBASE_UID> \
 *        --role admin
 *
 *   4. The target user signs out + signs back in (or calls
 *      `getIDToken(forcingRefresh: true)`) to pick up the new role.
 *
 * Args:
 *   --service-account <path>   Path to the Admin SDK JSON. Required.
 *   --uid <uid>                Firebase Auth UID. Required.
 *   --role <admin|moderator|none>   Role to set. "none" clears the role. Default: admin.
 */
import { readFile } from "node:fs/promises";
import { exit, argv } from "node:process";
import admin from "firebase-admin";

function parseArgs(args) {
  const out = {};
  for (let i = 0; i < args.length; i++) {
    const flag = args[i];
    if (!flag.startsWith("--")) continue;
    const value = args[i + 1];
    if (!value || value.startsWith("--")) {
      out[flag.slice(2)] = true;
      continue;
    }
    out[flag.slice(2)] = value;
    i++;
  }
  return out;
}

const args = parseArgs(argv.slice(2));
const serviceAccountPath = args["service-account"];
const targetUid = args.uid;
const role = (args.role ?? "admin").toLowerCase();

if (!serviceAccountPath || !targetUid) {
  console.error("Usage: node tools/bootstrap-admin.mjs --service-account <path> --uid <uid> [--role admin|moderator|none]");
  exit(1);
}

if (role !== "admin" && role !== "moderator" && role !== "none") {
  console.error(`Invalid --role: ${role}. Expected admin / moderator / none.`);
  exit(1);
}

let serviceAccount;
try {
  const raw = await readFile(serviceAccountPath, "utf8");
  serviceAccount = JSON.parse(raw);
} catch (err) {
  console.error(`Failed to read service account at ${serviceAccountPath}:`, err.message);
  exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

try {
  // Verify the target UID exists first — friendlier error than the silent
  // setCustomUserClaims success on a non-existent UID.
  const user = await admin.auth().getUser(targetUid);
  console.log(`✓ Found user: ${user.email ?? "(no email)"} — uid=${user.uid}`);

  const claims = role === "none" ? {} : { role };
  await admin.auth().setCustomUserClaims(targetUid, claims);

  if (role === "none") {
    console.log(`✓ Cleared role for ${targetUid}.`);
  } else {
    console.log(`✓ Set role=${role} for ${targetUid}.`);
  }
  console.log("");
  console.log("Note: the user must sign out + sign back in (or call");
  console.log("`Auth.auth().currentUser?.getIDToken(forcingRefresh: true)`)");
  console.log("for the new claim to take effect on the client.");
  exit(0);
} catch (err) {
  console.error(`✗ Failed:`, err.message);
  exit(1);
}
