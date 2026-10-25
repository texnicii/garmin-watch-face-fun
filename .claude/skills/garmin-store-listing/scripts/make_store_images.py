#!/usr/bin/env python3
"""Generate Connect IQ Store listing images that meet Garmin's constraints.

Garmin store card image rules:
  Cover image (Web/Mobile)  : 500 x 500, JPG/GIF/PNG, < 300 KB
  Screen images             : any size,  JPG/GIF/PNG, < 150 KB

This tool takes source images — real simulator/device screenshots of the *final*
build (do NOT use the concept mockups under design/, they differ from what ships) —
and emits compliant assets into ./images, picking the highest-quality encoding
(lossless PNG when it fits, else a JPEG quality sweep, else a gentle downscale)
that stays under each byte budget.

Examples
--------
  # Cover from a render (center-cropped to a 500x500 square) + two screenshots:
  python3 make_store_images.py \
      --cover ../../../images/image.png \
      --screens shot1.png shot2.png

  # Cover letter-boxed (padded) on the AMOLED background instead of cropped:
  python3 make_store_images.py --cover render.png --cover-fit contain

Outputs (into --outdir, default ./images):
  cover-500.(png|jpg)        500x500, < 300 KB
  screen-01.(png|jpg) ...    < 150 KB each
"""

import argparse
import io
import os
import sys
from PIL import Image, ImageCms

COVER_PX = 500
COVER_MAX = 300 * 1024
SCREEN_MAX = 150 * 1024
DEFAULT_BG = (0x04, 0x06, 0x0A)   # Theme.BACKGROUND (near-black AMOLED)


def encode(img, fmt, **kw):
    buf = io.BytesIO()
    img.save(buf, fmt, **kw)
    return buf.getvalue()


def to_srgb(img):
    """Convert an image carrying an embedded ICC profile into plain sRGB, so its
    colors stay correct once the profile is dropped on save. Untagged images (the
    common case for simulator renders) are returned unchanged.

    This matters for phone photos tagged Display P3 / HDR (PQ): simply stripping
    the profile leaves wide-gamut/HDR code values to be read as sRGB, which looks
    dark and flat. Converting remaps the pixels into sRGB first.
    """
    icc = img.info.get("icc_profile")
    if not icc:
        return img
    try:
        src = ImageCms.ImageCmsProfile(io.BytesIO(icc))
        return ImageCms.profileToProfile(
            img.convert("RGB"), src, ImageCms.createProfile("sRGB"), outputMode="RGB")
    except Exception:
        return img


def apply_gamma(img, g):
    """Midtone brightness lift via a per-channel LUT (g>1 brightens, preserving
    highlights). Use it to compensate an SDR export for the extra brightness an
    HDR source displayed on-screen; g==1.0 is a no-op."""
    if abs(g - 1.0) < 1e-3:
        return img
    lut = [round(255 * ((i / 255.0) ** (1.0 / g))) for i in range(256)]
    return img.convert("RGB").point(lut * 3)


def flatten(img, bg):
    """RGB image with any transparency composited over bg."""
    if img.mode in ("RGBA", "LA", "P"):
        img = img.convert("RGBA")
        canvas = Image.new("RGB", img.size, bg)
        canvas.paste(img, mask=img.split()[-1])
        return canvas
    return img.convert("RGB")


def best_encoding(img, max_bytes, bg):
    """Return (ext, data) for the highest-quality encoding <= max_bytes, or None.

    Tries lossless PNG (best for flat UI), a 256-color palette PNG, then a JPEG
    quality sweep. Among everything that fits, keeps the largest (= best fidelity).
    """
    cands = []
    cands.append(("png", encode(img.convert("RGBA"), "PNG", optimize=True)))
    try:
        pal = flatten(img, bg).quantize(colors=256, method=Image.MEDIANCUT)
        cands.append(("png", encode(pal, "PNG", optimize=True)))
    except Exception:
        pass
    rgb = flatten(img, bg)
    for q in (92, 88, 82, 76, 70, 62, 55, 48):
        cands.append(("jpg", encode(rgb, "JPEG", quality=q, optimize=True, progressive=True)))
    fitting = [c for c in cands if len(c[1]) <= max_bytes]
    if not fitting:
        return None
    return max(fitting, key=lambda c: len(c[1]))


def save_under(img, out_base, max_bytes, bg, min_px=120):
    """Encode under budget, downscaling in steps if even min quality is too big."""
    while True:
        r = best_encoding(img, max_bytes, bg)
        if r is not None:
            ext, data = r
            path = out_base + "." + ext
            with open(path, "wb") as fp:
                fp.write(data)
            return path, ext, len(data), img.size
        nw, nh = int(img.size[0] * 0.85), int(img.size[1] * 0.85)
        if min(nw, nh) < min_px:           # safety floor — emit lowest JPEG anyway
            rgb = flatten(img, bg)
            data = encode(rgb, "JPEG", quality=40, optimize=True, progressive=True)
            path = out_base + ".jpg"
            with open(path, "wb") as fp:
                fp.write(data)
            return path, "jpg", len(data), img.size
        img = img.resize((nw, nh), Image.LANCZOS)


def to_square(img, size, fit, bg):
    if fit == "cover":                      # center-crop to square, then scale
        w, h = img.size
        s = min(w, h)
        img = img.crop(((w - s) // 2, (h - s) // 2, (w - s) // 2 + s, (h - s) // 2 + s))
        return img.resize((size, size), Image.LANCZOS)
    img = img.copy()                        # contain: scale to fit, pad with bg
    img.thumbnail((size, size), Image.LANCZOS)
    canvas = Image.new("RGB", (size, size), bg)
    src = img.convert("RGBA")
    canvas.paste(src, ((size - img.size[0]) // 2, (size - img.size[1]) // 2), src.split()[-1])
    return canvas


def parse_bg(s):
    s = s.lstrip("#")
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4))


def report(label, path, ext, nbytes, size, budget):
    ok = "OK " if nbytes <= budget else "OVER"
    kb = nbytes / 1024.0
    print(f"  [{ok}] {label:11s} {os.path.basename(path):18s} {size[0]}x{size[1]:<4} "
          f"{ext.upper():3s} {kb:6.1f} KB / {budget // 1024} KB")
    return nbytes <= budget


def main():
    ap = argparse.ArgumentParser(description="Generate Connect IQ Store listing images.")
    ap.add_argument("--cover", help="source image for the 500x500 cover")
    ap.add_argument("--screens", nargs="*", default=[], help="source image(s) for screen images")
    ap.add_argument("--outdir", default="images", help="output directory (default: images)")
    ap.add_argument("--cover-fit", choices=["cover", "contain"], default="cover",
                    help="cover: center-crop to square (default); contain: pad on bg")
    ap.add_argument("--bg", default="000000", help="pad/flatten background hex (default 000000)")
    ap.add_argument("--max-screen-px", type=int, default=800,
                    help="cap longest screen-image side (default 800)")
    ap.add_argument("--brighten", type=float, default=1.0,
                    help="midtone gamma lift applied after sRGB conversion "
                         "(>1 brightens; use ~1.3 for dark HDR/Display-P3 photos)")
    ap.add_argument("--start-index", type=int, default=1,
                    help="first screen-NN number (default 1); use to append "
                         "screens in a later run without renumbering existing ones")
    args = ap.parse_args()

    if not args.cover and not args.screens:
        ap.error("nothing to do: pass --cover and/or --screens")

    bg = parse_bg(args.bg)
    os.makedirs(args.outdir, exist_ok=True)
    all_ok = True
    print(f"-> {args.outdir}/")

    if args.cover:
        cov = apply_gamma(to_srgb(Image.open(args.cover)), args.brighten)
        sq = to_square(cov, COVER_PX, args.cover_fit, bg)
        path, ext, n, size = save_under(sq, os.path.join(args.outdir, "cover-500"), COVER_MAX, bg)
        all_ok &= report("cover", path, ext, n, size, COVER_MAX)

    for i, src in enumerate(args.screens, args.start_index):
        img = apply_gamma(to_srgb(Image.open(src)), args.brighten)
        if max(img.size) > args.max_screen_px:
            img.thumbnail((args.max_screen_px, args.max_screen_px), Image.LANCZOS)
        base = os.path.join(args.outdir, "screen-%02d" % i)
        path, ext, n, size = save_under(img, base, SCREEN_MAX, bg)
        all_ok &= report("screen %d" % i, path, ext, n, size, SCREEN_MAX)

    if not all_ok:
        print("WARNING: an asset exceeds its budget (should not happen).", file=sys.stderr)
        sys.exit(1)
    print("All assets within Garmin limits.")


if __name__ == "__main__":
    main()
