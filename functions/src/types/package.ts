/**
 * .fmpkg manifest types. Canonical schema: docs/FMPKG_SCHEMA.md.
 *
 * Package layout (zip):
 *   manifest.json   (this shape)
 *   lut.png         (33^3 packed RGBA8 by default)
 *   thumbnail.jpg   (square 1024x1024)
 *   shaders/*.metal (optional, Phase 3+)
 */
export interface FMPackageManifest {
  schemaVersion: number;
  id: string;
  slug: string;
  name: string;
  author: FMAuthor;
  category: string;
  tags: string[];
  engine: FMEngine;
  thumbnail: FMAsset;
  lut?: FMAsset;
  shaders?: FMAsset[];
  parameters?: FMParameter[];
  compat: FMCompat;
}

export interface FMAuthor {
  uid: string;
  handle: string;
  name: string;
}

export interface FMEngine {
  /** Pipeline tier — see SYSTEM_DESIGN §3.1. */
  tier: "lut" | "lut+params" | "msl";
  lutFormat: "rgba8_33cube" | "rgba16f_33cube" | "rgba16f_65cube";
  intensityMin: number;
  intensityMax: number;
}

export interface FMAsset {
  path: string;
  bytes: number;
  sha256: string;
  mimeType: string;
}

export interface FMParameter {
  key: string;
  label: string;
  default: number;
  min: number;
  max: number;
  step: number;
}

export interface FMCompat {
  minAppVersion: string;
  minIosVersion: string;
}
