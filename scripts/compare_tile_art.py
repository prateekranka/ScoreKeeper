#!/usr/bin/env python3
"""Verify that a game tile's on-screen artwork matches its reference image pixel-to-pixel.

The three game tiles ("Scoreboard", "Ten Phases", "What's for Dinner") render a bundled 4:3 reference
artwork at a uniform scale (no crop, no rotation, no stretch). This tool takes a
simulator screenshot plus a generous bounding box around one tile's artwork and:

  1. LOCATES the artwork: a coarse-to-fine search for the uniform-scale + translation
     placement of the reference inside (and slightly beyond) the approx box. The coarse
     stage brute-forces every (scale, offset) pair at reduced resolution using FFT-based
     normalized cross-correlation; refinement stages then re-optimize the rendered width
     and offset at half resolution, full resolution, and finally on the exact integer
     pixel grid.
  2. COMPARES pixels: the reference is Lanczos-resized to the located rect and diffed
     against the screenshot (per-channel mean absolute difference, overall RMS, and the
     percentage of pixels whose max channel delta exceeds 8 / 16). A diff heatmap and
     the aligned crop are written next to the screenshot (or into --out-dir).

Usage:
  compare_tile_art.py --reference REF.png --screenshot SHOT.png --approx-box X,Y,W,H \
      [--out-dir DIR] [--device-scale S] [--expected-scale S]
  compare_tile_art.py --self-test

--approx-box is in SCREENSHOT PIXELS (not points) and should generously contain the
artwork; the locate step tolerates coarse boxes. --device-scale converts the known
368pt artwork width into the expected on-screen scale (default 3.0 for @3x devices);
pass --expected-scale to override that computation directly.

Exit codes: 0 = PASS, 1 = compared but the metrics miss the PASS thresholds,
2 = no confident alignment (or bad input). Run --self-test to validate the whole
harness end-to-end against a synthetic screenshot built from the real Phase 10
reference; it asserts the ground-truth placement is recovered and diffs are near zero.
"""

from __future__ import annotations

import argparse
import math
import os
import sys
import tempfile
from dataclasses import dataclass

import numpy as np
from PIL import Image

# --------------------------------------------------------------------------
# Search parameters (coarse-to-fine locate)
# --------------------------------------------------------------------------
SEARCH_MARGIN_FRACTION = 0.12   # approx box is grown by this fraction per side before searching
SEARCH_MARGIN_MIN_PX = 24       # ... but by at least this many screenshot pixels
COARSE_MAX_REGION_WIDTH = 360   # the search region is downsampled to at most this width
COARSE_SCALE_MIN = 0.30         # candidate rendered widths start at 30% of the region width...
COARSE_SCALE_MAX = 1.10         # ...and are scanned up to 110% of the region width
COARSE_SCALE_STEP_FACTOR = 1.025  # multiplicative step, so the relative error stays <= 1.25%
REFINE1_SCALE_STEP = 0.01       # half-resolution refinement: width steps of 1%...
REFINE1_SCALE_RADIUS = 3        # ...within +/-3% of the coarse width
REFINE2_SCALE_STEP = 0.0025     # full-resolution refinement: width steps of 0.25%...
REFINE2_SCALE_RADIUS = 2        # ...within +/-0.5% of the refine-1 width
REFINE2_OFFSET_RADIUS = 2       # full-resolution offset search radius, in pixels
REFINE3_WIDTH_RADIUS_PX = 2     # final pass: integer-pixel width steps, +/-2px...
REFINE3_OFFSET_RADIUS = 2       # ...with a +/-2px offset search, so the located rect is
                                # the exact integer-grid optimum (screenshots render on
                                # whole device pixels)

# --------------------------------------------------------------------------
# Confidence / PASS thresholds (printed with every report)
# --------------------------------------------------------------------------
MATCH_NCC_MIN = 0.60            # normalized cross-correlation below this = no confident alignment
PASS_MEAN_ABS_MAX = 6.0         # overall mean abs channel delta, 0-255 scale
PASS_WITHIN16_MIN_PCT = 97.0    # % of pixels with max-channel delta <= 16 must be >= this
PASS_SCALE_TOL = 0.03           # located scale must be within 3% of the expected scale
HEATMAP_GAIN = 12.0             # heatmap gray level per unit of max-channel delta

# --------------------------------------------------------------------------
# Geometry of the tile artwork inside the app (see scripts/README-tile-verification.md)
# --------------------------------------------------------------------------
EXPECTED_ARTWORK_WIDTH_PT = 368.0   # 440pt screen - 2*16pt outer margin - 2*20pt card padding
DEFAULT_DEVICE_SCALE = 3.0          # iPhone 17 Pro Max renders @3x

# --------------------------------------------------------------------------
# Self test
# --------------------------------------------------------------------------
SELF_TEST_REFERENCE = os.path.abspath(os.path.join(
    os.path.dirname(__file__),
    "..",
    "ScoreKeeper",
    "Assets.xcassets",
    "Phase10TileArtwork.imageset",
    "phase10-tile-art.png",
))
SELF_TEST_CANVAS = (1320, 2868)     # iPhone 17 Pro Max screenshot size @3x
SELF_TEST_ART_WIDTH_RANGE = (520, 1040)
SELF_TEST_NOISE_SIGMA = 1.2
SELF_TEST_MEAN_ABS_MAX = 2.5
SELF_TEST_PCT16_MAX = 0.5
SELF_TEST_SEED = 20260903

_LUMA = np.array([0.299, 0.587, 0.114])


@dataclass
class DiffStats:
    """Pixel diff metrics between the aligned reference and the screenshot crop."""

    mean_abs: float        # overall mean abs channel delta, 0-255 scale
    per_channel: tuple     # (R, G, B) mean abs deltas
    rms: float             # overall RMS delta, 0-255 scale
    pct_gt8: float         # % of pixels whose max channel delta exceeds 8
    pct_gt16: float        # % of pixels whose max channel delta exceeds 16


def load_rgb(path):
    """Load an image file as an RGB uint8 numpy array."""
    with Image.open(path) as im:
        return np.asarray(im.convert("RGB"))


def to_gray(rgb):
    """ITU-R BT.601 luma of an RGB uint8 array, as float64 in 0..255."""
    return rgb.astype(np.float64) @ _LUMA


def resize_gray(gray, width, height):
    """Lanczos-resize a 2-D float array to (width, height) via PIL."""
    im = Image.fromarray(gray.astype(np.float32), mode="F")
    out = im.resize((int(width), int(height)), Image.Resampling.LANCZOS)
    return np.asarray(out, dtype=np.float64)


def resize_rgb(rgb, width, height):
    """Lanczos-resize an RGB uint8 array to (width, height) via PIL."""
    im = Image.fromarray(np.ascontiguousarray(rgb))
    return np.asarray(im.resize((int(width), int(height)), Image.Resampling.LANCZOS))


def _fft_size(n):
    """Round an FFT length up to the next multiple of 16 so factorization stays fast."""
    return ((n + 15) // 16) * 16


def fft_ncc(region, template):
    """Normalized cross-correlation of `template` over `region` at every valid offset.

    Both inputs are 2-D float arrays. Returns a map of shape (H-h+1, W-w+1) whose entry
    (dy, dx) is the Pearson correlation between the template and the region window whose
    top-left corner sits at (dx, dy); flat windows correlate as 0. Returns None when the
    template does not fit inside the region. This evaluates the brute-force offset scan
    for one scale in a single FFT pass.
    """
    rh, rw = region.shape
    th, tw = template.shape
    if th > rh or tw > rw:
        return None
    fh, fw = _fft_size(rh + th - 1), _fft_size(rw + tw - 1)
    t_centered = template - template.mean()
    corr = np.fft.irfft2(
        np.fft.rfft2(region, (fh, fw)) * np.conj(np.fft.rfft2(t_centered, (fh, fw))),
        (fh, fw),
    )
    corr = corr[: rh - th + 1, : rw - tw + 1]

    # Sliding-window sums and sums of squares via integral images.
    integral = np.zeros((rh + 1, rw + 1))
    integral[1:, 1:] = region.cumsum(0).cumsum(1)
    integral_sq = np.zeros((rh + 1, rw + 1))
    integral_sq[1:, 1:] = np.square(region).cumsum(0).cumsum(1)
    s1 = integral[th:, tw:] - integral[:-th, tw:] - integral[th:, :-tw] + integral[:-th, :-tw]
    s2 = integral_sq[th:, tw:] - integral_sq[:-th, tw:] - integral_sq[th:, :-tw] + integral_sq[:-th, :-tw]

    win_ss = np.maximum(s2 - np.square(s1) / (th * tw), 0.0)   # sum of squared window deviations
    t_ss = float(np.square(t_centered).sum())
    denom = np.sqrt(win_ss * t_ss)
    ncc = np.zeros_like(corr)
    np.divide(corr, denom, out=ncc, where=denom > 1e-9)
    return ncc


def ncc_at(region, template, x, y):
    """Pearson correlation between `template` and the region window at top-left (x, y).

    Returns -1.0 when the window would fall outside the region.
    """
    th, tw = template.shape
    rh, rw = region.shape
    if x < 0 or y < 0 or x + tw > rw or y + th > rh:
        return -1.0
    win = region[y:y + th, x:x + tw]
    t_centered = template - template.mean()
    win_centered = win - win.mean()
    denom = math.sqrt(
        float(np.square(win_centered).sum()) * float(np.square(t_centered).sum())
    )
    if denom < 1e-9:
        return 0.0
    return float(np.multiply(win_centered, t_centered).sum() / denom)


def _coarse_scan(region_gray, ref_gray, aspect, down):
    """Brute-force scan over rendered widths and every offset at 1/`down` resolution.

    Candidate rendered widths run geometrically from COARSE_SCALE_MIN to COARSE_SCALE_MAX
    of the region width in COARSE_SCALE_STEP_FACTOR steps, so the relative width error
    after this stage is at most ~1.25%. Returns (width, x, y, ncc) in full-resolution
    region coordinates, or None when no candidate fits.
    """
    rh, rw = region_gray.shape
    if rh < 2 or rw < 2:
        return None
    region_d = resize_gray(region_gray, max(2, round(rw / down)), max(2, round(rh / down)))
    best = None
    w = COARSE_SCALE_MIN * rw
    while w <= COARSE_SCALE_MAX * rw:
        tw = round(w / down)
        th = round(w * aspect / down)
        if 8 <= tw <= region_d.shape[1] and 8 <= th <= region_d.shape[0]:
            ncc = fft_ncc(region_d, resize_gray(ref_gray, tw, th))
            if ncc is not None and ncc.size:
                dy, dx = np.unravel_index(int(np.argmax(ncc)), ncc.shape)
                value = float(ncc[dy, dx])
                if best is None or value > best[3]:
                    best = (w, int(dx) * down, int(dy) * down, value)
        w *= COARSE_SCALE_STEP_FACTOR
    return best


def _refine_stage(region_gray, ref_gray, aspect, w0, x0, y0, ncc0,
                  down, scale_step, scale_radius, offset_radius):
    """Local re-optimization of rendered width and offset around (w0, x0, y0).

    Evaluates direct NCC at 1/`down` resolution for widths w0*(1 +/- scale_radius *
    scale_step) and offsets within +/-offset_radius. Coordinates are always expressed in
    full-resolution region pixels.
    """
    rh, rw = region_gray.shape
    if down > 1:
        region_d = resize_gray(region_gray, max(2, round(rw / down)), max(2, round(rh / down)))
    else:
        region_d = region_gray
    best_w, best_x, best_y, best_ncc = w0, x0, y0, ncc0
    for k in range(-scale_radius, scale_radius + 1):
        w = w0 * (1.0 + k * scale_step)
        tw = max(4, round(w / down))
        th = max(4, round(w * aspect / down))
        if tw >= region_d.shape[1] or th >= region_d.shape[0]:
            continue
        template_d = resize_gray(ref_gray, tw, th)
        for dy in range(-offset_radius, offset_radius + 1):
            for dx in range(-offset_radius, offset_radius + 1):
                x = round(x0 / down) + dx
                y = round(y0 / down) + dy
                value = ncc_at(region_d, template_d, x, y)
                if value > best_ncc:
                    best_w, best_x, best_y, best_ncc = w, x * down, y * down, value
    return best_w, best_x, best_y, best_ncc


def locate_in_region(region_gray, ref_gray, aspect):
    """Coarse-to-fine uniform-scale + translation search inside one region.

    Stage 1 brute-forces (scale, offset) at reduced resolution; stage 2 re-optimizes the
    width (+/-3%) and offset at half resolution; stage 3 re-optimizes the width
    (+/-0.5%) and offset at full resolution; stage 4 locks onto the exact integer-pixel
    rect (+/-2px width and offset), since screenshots render on whole device pixels.
    Returns (width, x, y, ncc) in full-resolution region coordinates, or None when no
    scale candidate fits the region.
    """
    down = max(1, int(math.ceil(region_gray.shape[1] / COARSE_MAX_REGION_WIDTH)))
    coarse = _coarse_scan(region_gray, ref_gray, aspect, down)
    if coarse is None:
        return None
    best = _refine_stage(region_gray, ref_gray, aspect, *coarse[:3], -1.0,
                         down=down, scale_step=REFINE1_SCALE_STEP,
                         scale_radius=REFINE1_SCALE_RADIUS, offset_radius=down + 1)
    best = _refine_stage(region_gray, ref_gray, aspect, *best,
                         down=1, scale_step=REFINE2_SCALE_STEP,
                         scale_radius=REFINE2_SCALE_RADIUS, offset_radius=REFINE2_OFFSET_RADIUS)
    # One scale_step == 1 rendered pixel here, so this pass visits every integer width.
    best = _refine_stage(region_gray, ref_gray, aspect, *best,
                         down=1, scale_step=1.0 / best[0],
                         scale_radius=REFINE3_WIDTH_RADIUS_PX,
                         offset_radius=REFINE3_OFFSET_RADIUS)
    return best


def expand_box(box, shot_w, shot_h):
    """Grow the approx box by SEARCH_MARGIN_FRACTION per side (min SEARCH_MARGIN_MIN_PX)
    and clip it to the screenshot bounds. Returns (x, y, w, h)."""
    x, y, w, h = box
    mx = max(SEARCH_MARGIN_MIN_PX, int(round(SEARCH_MARGIN_FRACTION * w)))
    my = max(SEARCH_MARGIN_MIN_PX, int(round(SEARCH_MARGIN_FRACTION * h)))
    x0, y0 = max(0, x - mx), max(0, y - my)
    x1, y1 = min(shot_w, x + w + mx), min(shot_h, y + h + my)
    return x0, y0, x1 - x0, y1 - y0


def locate_reference(screenshot_gray, ref_gray, aspect, approx_box):
    """Locate the reference near `approx_box` (x, y, w, h in screenshot pixels).

    The box is padded, clipped and searched; the winning placement is translated back to
    screenshot coordinates. Returns ((x, y, w, h), ncc), or None when no scale candidate
    fits the search region.
    """
    sx, sy, sw, sh = expand_box(approx_box, screenshot_gray.shape[1], screenshot_gray.shape[0])
    found = locate_in_region(screenshot_gray[sy:sy + sh, sx:sx + sw], ref_gray, aspect)
    if found is None:
        return None
    w, x, y, ncc = found
    w = int(round(w))
    rect = (sx + int(round(x)), sy + int(round(y)), w, int(round(w * aspect)))
    return rect, ncc


def compare_at(screenshot_rgb, ref_rgb, rect):
    """Resize the reference to `rect` (Lanczos) and diff it against the screenshot pixels.

    Returns (DiffStats, max_delta) where max_delta is the per-pixel max channel delta
    used for the heatmap.
    """
    x, y, w, h = rect
    crop = screenshot_rgb[y:y + h, x:x + w]
    ref = resize_rgb(ref_rgb, w, h).astype(np.float64)
    delta = crop.astype(np.float64) - ref
    absd = np.abs(delta)
    maxd = absd.max(axis=2)
    stats = DiffStats(
        mean_abs=float(absd.mean()),
        per_channel=tuple(float(c) for c in absd.reshape(-1, 3).mean(axis=0)),
        rms=float(math.sqrt(float(np.square(delta).mean()))),
        pct_gt8=float((maxd > 8).mean() * 100.0),
        pct_gt16=float((maxd > 16).mean() * 100.0),
    )
    return stats, maxd


def write_artifacts(out_dir, stem, crop_rgb, maxd):
    """Write the diff heatmap and aligned screenshot crop; returns their paths."""
    os.makedirs(out_dir, exist_ok=True)
    heat_path = os.path.join(out_dir, f"{stem}.tile-diff-heatmap.png")
    heat = np.clip(maxd * HEATMAP_GAIN, 0, 255).astype(np.uint8)
    Image.fromarray(heat, mode="L").save(heat_path)
    crop_path = os.path.join(out_dir, f"{stem}.tile-aligned-crop.png")
    Image.fromarray(np.ascontiguousarray(crop_rgb)).save(crop_path)
    return heat_path, crop_path


def decide_pass(stats, scale_dev):
    """Apply the documented PASS criteria to the diff metrics and scale deviation."""
    return (stats.mean_abs <= PASS_MEAN_ABS_MAX
            and (100.0 - stats.pct_gt16) >= PASS_WITHIN16_MIN_PCT
            and scale_dev <= PASS_SCALE_TOL)


def print_metrics(rect, ncc, located_scale, expected_scale, expected_source, stats):
    """Print the located placement and diff metrics (everything except the verdict)."""
    scale_dev = abs(located_scale - expected_scale) / expected_scale
    print(f"located rect   : x={rect[0]} y={rect[1]} w={rect[2]} h={rect[3]} (screenshot px)")
    print(f"located scale  : {located_scale:.4f} (located width / reference width)")
    print(f"expected scale : {expected_scale:.4f} ({expected_source})")
    print(f"scale deviation: {scale_dev * 100:.2f}% (PASS allows <= {PASS_SCALE_TOL * 100:g}%)")
    print(f"match ncc      : {ncc:.4f} (confidence requires >= {MATCH_NCC_MIN:.2f})")
    if stats is not None:
        r, g, b = stats.per_channel
        print(f"mean abs diff  : {stats.mean_abs:.2f}/255 (R {r:.2f} G {g:.2f} B {b:.2f})"
              f" (PASS allows <= {PASS_MEAN_ABS_MAX:g}/255)")
        print(f"rms diff       : {stats.rms:.2f}/255")
        print(f"pixels >8      : {stats.pct_gt8:.2f}% exceed max-channel delta 8 (report only)")
        print(f"pixels >16     : {stats.pct_gt16:.2f}% exceed max-channel delta 16"
              f" (PASS allows <= {100.0 - PASS_WITHIN16_MIN_PCT:g}%)")
    print(f"PASS criteria  : mean abs diff <= {PASS_MEAN_ABS_MAX:g}/255 AND >="
          f" {PASS_WITHIN16_MIN_PCT:g}% of pixels within max-channel delta 16 AND located"
          f" scale within {PASS_SCALE_TOL * 100:g}% of expected scale")


def resolve_expected_scale(args, ref_width_px):
    """Expected rendered scale (located width / reference width), either taken from
    --expected-scale or computed from the known artwork point width and device scale."""
    if args.expected_scale is not None:
        return args.expected_scale, "--expected-scale"
    expected = EXPECTED_ARTWORK_WIDTH_PT * args.device_scale / ref_width_px
    source = (f"{EXPECTED_ARTWORK_WIDTH_PT:g}pt artwork width * device scale"
              f" {args.device_scale:g} / reference width {ref_width_px}px")
    return expected, source


def run_compare(args, box):
    """Run the locate + compare pipeline on a real screenshot; returns the exit code."""
    ref = load_rgb(args.reference)
    shot = load_rgb(args.screenshot)
    ref_h, ref_w = ref.shape[:2]
    aspect = ref_h / ref_w

    located = locate_reference(to_gray(shot), to_gray(ref), aspect, box)
    if located is None:
        print("ERROR: no candidate placement of the reference fits the search region.")
        print("       The approx box (plus its search margin) is probably smaller than"
              " the artwork; enlarge --approx-box.")
        return 2
    rect, ncc = located

    stats, maxd = compare_at(shot, ref, rect)
    screenshot_stem = os.path.splitext(os.path.basename(args.screenshot))[0]
    reference_stem = os.path.splitext(os.path.basename(args.reference))[0]
    stem = f"{screenshot_stem}.{reference_stem}"
    out_dir = args.out_dir or os.path.dirname(os.path.abspath(args.screenshot))
    crop = shot[rect[1]:rect[1] + rect[3], rect[0]:rect[0] + rect[2]]
    heat_path, crop_path = write_artifacts(out_dir, stem, crop, maxd)

    expected_scale, expected_source = resolve_expected_scale(args, ref_w)
    located_scale = rect[2] / ref_w
    confident = ncc >= MATCH_NCC_MIN
    passed = confident and decide_pass(stats, abs(located_scale - expected_scale) / expected_scale)

    print("== tile art comparison ==")
    print(f"reference      : {args.reference} ({ref_w}x{ref_h} px)")
    print(f"screenshot     : {args.screenshot} ({shot.shape[1]}x{shot.shape[0]} px)")
    print(f"approx box     : {box[0]},{box[1]},{box[2]},{box[3]} (screenshot px)")
    print_metrics(rect, ncc, located_scale, expected_scale, expected_source, stats)
    print(f"heatmap        : {heat_path}")
    print(f"aligned crop   : {crop_path}")
    if not confident:
        print(f"VERDICT: NO CONFIDENT ALIGNMENT (ncc {ncc:.4f} < {MATCH_NCC_MIN:.2f})."
              " Check the approx box, the crop mode (full 4:3, no crop/letterbox) and"
              " that the reference belongs to this tile.")
        return 2
    if not passed:
        failed = []
        if stats.mean_abs > PASS_MEAN_ABS_MAX:
            failed.append("mean abs diff")
        if (100.0 - stats.pct_gt16) < PASS_WITHIN16_MIN_PCT:
            failed.append("pixels within max-channel delta 16")
        if abs(located_scale - expected_scale) / expected_scale > PASS_SCALE_TOL:
            failed.append("scale deviation vs expected")
        print("FAILED criteria: " + ", ".join(failed))
    print(f"VERDICT: {'PASS' if passed else 'FAIL'}")
    return 0 if passed else 1


def synthetic_background(width, height, rng):
    """Vertical gradient plus random colored rectangles, as a float64 RGB canvas.

    Busy enough that the locate step has to do real work, unlike a flat backdrop.
    """
    top = rng.uniform(30, 220, size=3)
    bottom = rng.uniform(30, 220, size=3)
    t = np.linspace(0.0, 1.0, height, dtype=np.float64)[:, None]      # (height, 1)
    gradient = (1.0 - t) * top[None, :] + t * bottom[None, :]         # (height, 3)
    canvas = np.broadcast_to(gradient[:, None, :], (height, width, 3)).copy()
    for _ in range(60):
        rw = int(rng.integers(30, 420))
        rh = int(rng.integers(16, 260))
        x0 = int(rng.integers(0, width - rw))
        y0 = int(rng.integers(0, height - rh))
        canvas[y0:y0 + rh, x0:x0 + rw, :] = rng.uniform(0, 255, size=3)
    return canvas


def run_self_test():
    """End-to-end harness check using the real Phase 10 reference.

    A synthetic screenshot is generated with the reference pasted at a known random
    offset/scale on a busy background plus sensor-like noise; the same locate + compare
    pipeline is then run against a deliberately generous approx box and the ground truth
    must be recovered with near-zero diffs. Returns the exit code.
    """
    if not os.path.isfile(SELF_TEST_REFERENCE):
        print(f"SELF-TEST FAIL: reference image not found: {SELF_TEST_REFERENCE}")
        return 1
    ref = load_rgb(SELF_TEST_REFERENCE)
    ref_h, ref_w = ref.shape[:2]
    aspect = ref_h / ref_w
    rng = np.random.default_rng(SELF_TEST_SEED)
    width, height = SELF_TEST_CANVAS

    art_w = int(rng.integers(*SELF_TEST_ART_WIDTH_RANGE))
    art_h = int(round(art_w * aspect))
    x_true = int(rng.integers(24, width - art_w - 24))
    y_true = int(rng.integers(200, height - art_h - 200))

    canvas = synthetic_background(width, height, rng)
    canvas[y_true:y_true + art_h, x_true:x_true + art_w, :] = resize_rgb(ref, art_w, art_h)
    canvas += rng.normal(0.0, SELF_TEST_NOISE_SIGMA, size=(height, width, 1))
    shot = np.clip(canvas, 0.0, 255.0).astype(np.uint8)

    # A generous approx box, like a runner would derive from approximate layout math.
    pad_x = int(rng.uniform(0.03, 0.15) * art_w)
    pad_y = int(rng.uniform(0.03, 0.15) * art_h)
    box = (max(0, x_true - pad_x), max(0, y_true - pad_y), art_w + 2 * pad_x, art_h + 2 * pad_y)

    located = locate_reference(to_gray(shot), to_gray(ref), aspect, box)
    out_dir = tempfile.mkdtemp(prefix="tile-self-test-")
    Image.fromarray(shot).save(os.path.join(out_dir, "self-test.synthetic-screenshot.png"))
    if located is None:
        print("SELF-TEST FAIL: locate found no candidate placement inside the search region.")
        print(f"synthetic screenshot kept at: {out_dir}")
        return 1
    rect, ncc = located
    stats, maxd = compare_at(shot, ref, rect)
    crop = shot[rect[1]:rect[1] + rect[3], rect[0]:rect[0] + rect[2]]
    heat_path, crop_path = write_artifacts(out_dir, "self-test", crop, maxd)

    expected_scale = art_w / ref_w
    located_scale = rect[2] / ref_w
    pos_err = max(abs(rect[0] - x_true), abs(rect[1] - y_true))
    width_err = abs(rect[2] - art_w)
    checks = [
        ("located position within 2px of ground truth", pos_err <= 2),
        ("located width within 2px of ground truth", width_err <= 2),
        ("alignment confident (ncc)", ncc >= MATCH_NCC_MIN),
        ("mean abs diff near zero", stats.mean_abs <= SELF_TEST_MEAN_ABS_MAX),
        ("no pixels beyond max-channel delta 16", stats.pct_gt16 <= SELF_TEST_PCT16_MAX),
    ]

    print("== self test ==")
    print(f"synthetic screenshot : {out_dir}/self-test.synthetic-screenshot.png"
          f" ({width}x{height} px)")
    print(f"ground truth rect    : x={x_true} y={y_true} w={art_w} h={art_h}")
    print(f"approx box           : {box[0]},{box[1]},{box[2]},{box[3]} (screenshot px)")
    print_metrics(rect, ncc, located_scale, expected_scale,
                  f"ground truth ({art_w}/{ref_w}px)", stats)
    print(f"artifacts            : {heat_path} , {crop_path}")
    for name, ok in checks:
        print(f"  [{'ok' if ok else 'FAIL'}] {name}")
    passed = all(ok for _, ok in checks)
    print(f"SELF-TEST {'PASS' if passed else 'FAIL'}")
    return 0 if passed else 1


def parse_box(text):
    """Parse an --approx-box argument "X,Y,W,H" (screenshot pixels) into int tuples."""
    parts = [p.strip() for p in text.split(",")]
    if len(parts) != 4:
        raise ValueError("--approx-box expects X,Y,W,H")
    x, y, w, h = (int(p) for p in parts)
    if w <= 0 or h <= 0:
        raise ValueError("--approx-box width and height must be positive")
    return (x, y, w, h)


def parse_args(argv):
    """Parse the command line."""
    parser = argparse.ArgumentParser(
        description="Verify a game tile's on-screen artwork against its reference image"
                    " (locate by uniform scale + translation, then diff pixels).")
    parser.add_argument("--reference", help="path to the reference artwork PNG")
    parser.add_argument("--screenshot", help="path to the simulator screenshot PNG")
    parser.add_argument("--approx-box", dest="approx_box",
                        help="X,Y,W,H of a generous bounding box around the artwork,"
                             " in SCREENSHOT PIXELS")
    parser.add_argument("--out-dir", help="directory for the diff heatmap and aligned"
                                          " crop (default: alongside the screenshot)")
    parser.add_argument("--device-scale", type=float, default=DEFAULT_DEVICE_SCALE,
                        help="device scale factor used with the known 368pt artwork width"
                             " to compute the expected scale (default: 3.0)")
    parser.add_argument("--expected-scale", type=float,
                        help="override the expected rendered scale (located width /"
                             " reference width) instead of deriving it from --device-scale")
    parser.add_argument("--self-test", action="store_true",
                        help="run the built-in synthetic end-to-end test and exit")
    return parser.parse_args(argv)


def main(argv=None):
    """CLI entry point; returns the process exit code."""
    args = parse_args(argv)
    if args.self_test:
        return run_self_test()
    if not args.reference or not args.screenshot or args.approx_box is None:
        print("error: --reference, --screenshot and --approx-box are required"
              " (or run with --self-test)")
        return 2
    if args.device_scale <= 0 or (args.expected_scale is not None and args.expected_scale <= 0):
        print("error: --device-scale / --expected-scale must be positive")
        return 2
    for path in (args.reference, args.screenshot):
        if not os.path.isfile(path):
            print(f"error: file not found: {path}")
            return 2
    try:
        box = parse_box(args.approx_box)
    except ValueError as exc:
        print(f"error: {exc}")
        return 2
    return run_compare(args, box)


if __name__ == "__main__":
    sys.exit(main())
