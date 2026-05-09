#!/usr/bin/env python3
"""Generate moodit seed filter LUTs.

Produces 33×33×33 LUTs as 1089×33 RGBA PNG files using the layout decoded by
``Sources/FilterEngine/LUTImageDecoder.swift``: ``x = blue*33 + red``, ``y = green``.

Design principle (per product directive): muted, editorial, low-saturation
defaults. Most filters keep ``sat ≤ 0.90``; only a few travel/landscape filters
nudge ≤ 1.05 on selective channels. Identity ``sat == 1`` is treated as the
upper bound for the catalog.

The generator is purely deterministic: identical inputs produce byte-identical
PNGs across runs/platforms — re-run safely whenever a recipe changes.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import Callable

import numpy as np
from PIL import Image

SIZE = 33

Recipe = Callable[[np.ndarray], np.ndarray]


# --- LUT grid + PNG serialization ------------------------------------------


def identity_grid() -> np.ndarray:
    """Return shape (SIZE, SIZE, SIZE, 3) indexed (r, g, b, channel)."""
    idx = np.arange(SIZE, dtype=np.float64) / (SIZE - 1)
    R, G, B = np.meshgrid(idx, idx, idx, indexing="ij")
    return np.stack([R, G, B], axis=-1)


def save_lut_png(rgb: np.ndarray, path: Path) -> None:
    """Serialize LUT to PNG using moodit layout (y=green, x=blue*SIZE+red)."""
    # rgb axes: (r, g, b, c). Permute to (g, b, r, c) so the inner two axes
    # collapse to width = b*SIZE + r exactly as the decoder expects.
    out = rgb.transpose(1, 2, 0, 3).reshape(SIZE, SIZE * SIZE, 3)
    rgba = np.concatenate([out, np.ones((SIZE, SIZE * SIZE, 1))], axis=-1)
    pixels = np.clip(np.round(rgba * 255), 0, 255).astype(np.uint8)
    Image.fromarray(pixels, "RGBA").save(path, optimize=True)


def save_lut_cube(rgb: np.ndarray, path: Path, *, title: str) -> None:
    """Serialize LUT to Adobe ``.cube`` text — matches CubeLUTWriter.swift exactly.

    Iteration order: outer ``b``, middle ``g``, inner ``r`` (red fastest).
    Values printed as ``%.6f`` to match the Swift writer byte-for-byte after
    UTF-8 encoding so checksums computed here line up with on-device parsers.
    """
    lines: list[str] = [f'TITLE "{title}"', f"LUT_3D_SIZE {SIZE}"]
    for b in range(SIZE):
        for g in range(SIZE):
            for r in range(SIZE):
                c = rgb[r, g, b]
                lines.append(f"{c[0]:.6f} {c[1]:.6f} {c[2]:.6f}")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


# --- Color transform helpers -----------------------------------------------


def saturation(rgb: np.ndarray, sat: float) -> np.ndarray:
    """sat=0 → grayscale, sat=1 → identity. ITU BT.601 luma."""
    luma = 0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2]
    luma3 = np.stack([luma, luma, luma], axis=-1)
    return np.clip(luma3 + (rgb - luma3) * sat, 0, 1)


def s_curve(c: np.ndarray, strength: float) -> np.ndarray:
    """Smoothstep-mixed S-curve. strength>0 adds contrast, strength<0 lifts/flattens."""
    if strength == 0:
        return c
    if strength > 0:
        smooth = c * c * (3 - 2 * c)
        return np.clip(c + (smooth - c) * strength, 0, 1)
    flat = 0.5 + (c - 0.5) * 0.7  # compresses dynamic range toward mid
    return np.clip(c + (flat - c) * (-strength), 0, 1)


def lift_gamma_gain(
    c: np.ndarray, lift: float = 0.0, gamma: float = 1.0, gain: float = 1.0
) -> np.ndarray:
    out = c + lift * (1 - c)
    out = np.power(np.clip(out, 1e-6, 1), 1.0 / gamma)
    out = out * gain
    return np.clip(out, 0, 1)


def channel_offset(
    rgb: np.ndarray, dr: float = 0, dg: float = 0, db: float = 0
) -> np.ndarray:
    out = rgb.copy()
    out[..., 0] += dr
    out[..., 1] += dg
    out[..., 2] += db
    return np.clip(out, 0, 1)


def channel_scale(
    rgb: np.ndarray, sr: float = 1, sg: float = 1, sb: float = 1
) -> np.ndarray:
    out = rgb.copy()
    out[..., 0] *= sr
    out[..., 1] *= sg
    out[..., 2] *= sb
    return np.clip(out, 0, 1)


def split_tone(
    rgb: np.ndarray,
    shadow_color: tuple[float, float, float],
    highlight_color: tuple[float, float, float],
    *,
    balance: float = 0.5,
    amount: float = 0.15,
) -> np.ndarray:
    """Drift shadows/highlights toward target colors based on luma."""
    luma = 0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2]
    sh_w = np.clip(1 - luma / max(balance, 1e-6), 0, 1) ** 1.5
    hi_w = np.clip((luma - balance) / max(1 - balance, 1e-6), 0, 1) ** 1.5
    sh_w = sh_w[..., None]
    hi_w = hi_w[..., None]
    sh_t = np.array(shadow_color, dtype=np.float64)
    hi_t = np.array(highlight_color, dtype=np.float64)
    out = rgb + amount * (sh_w * (sh_t - rgb) + hi_w * (hi_t - rgb))
    return np.clip(out, 0, 1)


def to_luminance(rgb: np.ndarray) -> np.ndarray:
    luma = 0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2]
    return np.stack([luma, luma, luma], axis=-1)


# --- Filter recipes (all designed for low default saturation) --------------


def f_sunlit_portra(g: np.ndarray) -> np.ndarray:
    out = channel_offset(g, dr=0.012, db=-0.012)
    out = lift_gamma_gain(out, lift=0.020)
    out = s_curve(out, 0.18)
    return saturation(out, 0.82)


def f_golden_hour(g: np.ndarray) -> np.ndarray:
    out = channel_offset(g, dr=0.030, dg=0.005, db=-0.022)
    out = lift_gamma_gain(out, lift=0.015)
    out = s_curve(out, 0.16)
    return saturation(out, 0.84)


def f_soft_velvia(g: np.ndarray) -> np.ndarray:
    # Velvia traditionally vivid; we tame it to a gentle natural pop only.
    out = s_curve(g, 0.18)
    out = channel_offset(out, dg=0.005)
    return saturation(out, 0.95)


def f_pro_400h(g: np.ndarray) -> np.ndarray:
    out = channel_offset(g, dg=0.014, db=0.006)
    out = lift_gamma_gain(out, lift=0.038)
    out = s_curve(out, -0.08)
    return saturation(out, 0.70)


def f_cinestill_night(g: np.ndarray) -> np.ndarray:
    out = split_tone(
        g,
        shadow_color=(0.06, 0.20, 0.40),
        highlight_color=(0.95, 0.55, 0.30),
        amount=0.16,
    )
    out = s_curve(out, 0.20)
    return saturation(out, 0.76)


def f_tri_x_mono(g: np.ndarray) -> np.ndarray:
    luma = to_luminance(g)
    return s_curve(luma, 0.32)


def f_acros_soft(g: np.ndarray) -> np.ndarray:
    luma = to_luminance(g)
    return s_curve(luma, 0.10)


def f_sepia_memory(g: np.ndarray) -> np.ndarray:
    luma = to_luminance(g)
    sepia = np.stack(
        [
            np.clip(luma[..., 0] * 1.05 + 0.06, 0, 1),
            np.clip(luma[..., 1] * 0.95 + 0.04, 0, 1),
            np.clip(luma[..., 2] * 0.78, 0, 1),
        ],
        axis=-1,
    )
    return s_curve(sepia, -0.05)


def f_teal_orange(g: np.ndarray) -> np.ndarray:
    out = split_tone(
        g,
        shadow_color=(0.08, 0.36, 0.42),
        highlight_color=(0.88, 0.55, 0.32),
        amount=0.14,
    )
    out = s_curve(out, 0.16)
    return saturation(out, 0.86)


def f_bleach_bypass(g: np.ndarray) -> np.ndarray:
    luma = to_luminance(g)
    out = g * 0.5 + luma * 0.5  # half desaturate before global sat
    out = s_curve(out, 0.30)
    return saturation(out, 0.55)


def f_polaroid_fade(g: np.ndarray) -> np.ndarray:
    out = lift_gamma_gain(g, lift=0.075)
    out = channel_offset(out, dr=0.014, dg=-0.005, db=0.006)
    out = s_curve(out, -0.08)
    return saturation(out, 0.70)


def f_lomo_mood(g: np.ndarray) -> np.ndarray:
    # Originally "Lomo Punch"; toned down per low-sat directive.
    out = s_curve(g, 0.22)
    out = channel_offset(out, dr=0.010, db=-0.012)
    return saturation(out, 0.88)


def f_cafe_cream(g: np.ndarray) -> np.ndarray:
    out = lift_gamma_gain(g, lift=0.038)
    out = channel_offset(out, dr=0.022, dg=0.006, db=-0.018)
    out = s_curve(out, 0.10)
    return saturation(out, 0.78)


def f_honey_glow(g: np.ndarray) -> np.ndarray:
    out = channel_offset(g, dr=0.024, dg=0.010, db=-0.026)
    out = lift_gamma_gain(out, lift=0.022)
    out = s_curve(out, 0.13)
    return saturation(out, 0.82)


def f_seoul_night(g: np.ndarray) -> np.ndarray:
    out = split_tone(
        g,
        shadow_color=(0.10, 0.14, 0.34),
        highlight_color=(0.55, 0.32, 0.55),
        amount=0.13,
    )
    out = s_curve(out, 0.18)
    return saturation(out, 0.72)


def f_cherry_blossom(g: np.ndarray) -> np.ndarray:
    out = lift_gamma_gain(g, lift=0.055)
    out = channel_offset(out, dr=0.018, dg=-0.004, db=0.010)
    out = s_curve(out, -0.06)
    return saturation(out, 0.72)


def f_cobalt_sky(g: np.ndarray) -> np.ndarray:
    out = g.copy()
    out[..., 2] = np.clip(out[..., 2] * 1.04 + 0.008, 0, 1)
    out = s_curve(out, 0.14)
    return saturation(out, 0.84)


def f_anime_cel(g: np.ndarray) -> np.ndarray:
    out = lift_gamma_gain(g, gamma=0.92)
    out = channel_offset(out, dg=-0.006, db=0.012)
    out = s_curve(out, 0.16)
    return saturation(out, 0.86)


def f_indigo_fog(g: np.ndarray) -> np.ndarray:
    out = lift_gamma_gain(g, lift=0.080)
    out = channel_offset(out, dr=-0.018, db=0.022)
    out = s_curve(out, -0.10)
    return saturation(out, 0.55)


def f_skin_bloom(g: np.ndarray) -> np.ndarray:
    out = channel_offset(g, dr=0.012, db=-0.008)
    out = lift_gamma_gain(out, lift=0.024)
    out = s_curve(out, 0.08)
    return saturation(out, 0.80)


# (slug, title, recipe). Slug is the LUT filename stem; title is embedded in the
# .cube TITLE header (and appears in the Firestore manifest entry).
RECIPES: list[tuple[str, str, Recipe]] = [
    ("sunlit-portra", "Sunlit Portra", f_sunlit_portra),
    ("golden-hour", "Golden Hour", f_golden_hour),
    ("soft-velvia", "Soft Velvia", f_soft_velvia),
    ("pro-400h", "Pro 400H", f_pro_400h),
    ("cinestill-night", "Cinestill Night", f_cinestill_night),
    ("tri-x-mono", "Tri-X Mono", f_tri_x_mono),
    ("acros-soft", "Acros Soft", f_acros_soft),
    ("sepia-memory", "Sepia Memory", f_sepia_memory),
    ("teal-orange", "Teal & Orange", f_teal_orange),
    ("bleach-bypass", "Bleach Bypass", f_bleach_bypass),
    ("polaroid-fade", "Polaroid Fade", f_polaroid_fade),
    ("lomo-mood", "Lomo Mood", f_lomo_mood),
    ("cafe-cream-mooditor", "Cafe Cream", f_cafe_cream),
    ("honey-glow", "Honey Glow", f_honey_glow),
    ("seoul-night-mooditor", "Seoul Night", f_seoul_night),
    ("cherry-blossom", "Cherry Blossom", f_cherry_blossom),
    ("cobalt-sky", "Cobalt Sky", f_cobalt_sky),
    ("anime-cel", "Anime Cel", f_anime_cel),
    ("indigo-fog", "Indigo Fog", f_indigo_fog),
    ("skin-bloom", "Skin Bloom", f_skin_bloom),
]


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--out",
        type=Path,
        default=Path("Sources/Marketplace/Resources/SeedFilters/luts"),
        help="Output directory for PNG LUTs (bundled with the app).",
    )
    parser.add_argument(
        "--cube-out",
        type=Path,
        default=Path("dist/seed-filter-cubes"),
        help="Output directory for .cube text packages (uploaded to R2 as .fmpkg).",
    )
    args = parser.parse_args(argv)
    out_dir: Path = args.out
    cube_dir: Path = args.cube_out
    out_dir.mkdir(parents=True, exist_ok=True)
    cube_dir.mkdir(parents=True, exist_ok=True)

    grid = identity_grid()
    for slug, title, fn in RECIPES:
        baked = fn(grid)

        png_path = out_dir / f"{slug}.png"
        save_lut_png(baked, png_path)
        png_size = png_path.stat().st_size

        cube_path = cube_dir / f"{slug}.cube"
        save_lut_cube(baked, cube_path, title=title)
        cube_size = cube_path.stat().st_size

        print(
            f"  {slug:<24}  png {png_size:>6,} B   cube {cube_size:>7,} B"
        )

    print(f"\ngenerated {len(RECIPES)} LUTs (PNG → {out_dir}, .cube → {cube_dir})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
