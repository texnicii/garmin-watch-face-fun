---
name: garmin-store-listing
description: Fill out the Connect IQ Store listing card for this watch face — draft the Title (≤50 chars) and Description (≤4000 chars) and generate the Cover Image (500×500, <300 KB) and Screen images (<150 KB) into ./images. Use when preparing the app for the Garmin Connect IQ Store, publishing a new version, or updating store metadata/screenshots.
---

# Garmin Connect IQ Store listing

Produce everything the Connect IQ Store app-listing card needs for «Fun Bra».
**Outputs:** the listing text → **`GARMIN_STORE.md`** at the repo root
(both languages in one file); the images → **`./images`**.

## Card fields & hard limits

| Field | Limit | Format |
|---|---|---|
| **Title** | ≤ **50** characters | text |
| **Description** | ≤ **4000** characters | text |
| **Cover Image** (Web/Mobile) | **500 × 500** px, < **300 KB** | JPG / GIF / PNG |
| **Screen images** | < **150 KB** each | JPG / GIF / PNG |

The store keeps metadata **per listing language**. This app declares `rus`
(`manifest.xml`), so fill **both** the English and the Russian listing.

## Workflow

### 1 — Title + Description → `GARMIN_STORE.md`
Write/maintain the listing text in **`GARMIN_STORE.md` at the repo root** — both
languages in one file, **English first, then Russian**, each with its Title and
Description (the file already holds ready drafts grounded in the real feature set).
Keep each Title and Description inside a ```` ``` ```` fenced block so the counter
below can read them. After editing, **validate the lengths** (Title ≤ 50,
Description ≤ 4000, counted in characters — Cyrillic counts as 1 each):

```bash
python3 - <<'PY'
import re
t = open("GARMIN_STORE.md", encoding="utf-8").read()
blocks = re.findall(r"```\n(.*?)\n```", t, re.S)   # Title, Desc per language, in order
labels = ["EN Title", "EN Description", "RU Title", "RU Description"]
for lab, b in zip(labels, blocks):
    lim = 50 if "Title" in lab else 4000
    print(f"{lab:16s} {len(b):4d}/{lim}  {'OK' if len(b) <= lim else 'OVER'}")
PY
```
Only claim features the build actually has (big digital clock, weekday + date,
two glowing neon curves as progress indicators — steps to goal / active minutes
today / battery, selectable per curve — or a decorative mode, blinking dots after
wake (can be turned off), 4 color pairs, always-on/burn-in, EN/RU + language
setting). No complications/HR/GPS/weather.

### 1b — Changelog → `GARMIN_STORE.md`
`GARMIN_STORE.md` ends with a **`## Changelog`** section — keep it current. It is
the source for the store's per-version **Version Notes** field. Rules:
- **Newest version first.** Add a new version header for each release and put the
  matching language block (English + Русский) under it, inside a ```` ``` ````
  fence so it pastes straight into the store.
- **User-facing only, and brief.** List just what a user would notice — new
  features, visible design/behavior changes, important fixes. A few bullets max.
- **Exclude** refactors, build/toolchain, font-generation, code-structure, and
  other internal changes. If a change isn't visible on the watch or in settings,
  it doesn't belong here.
- Keep the version header in sync with the version string you actually upload.

These changelog fences come **after** the four Title/Description blocks, so the
length-check below still reads the listing fields correctly.

### 2 — Images → ./images
Use the helper, which enforces every Garmin limit (square cover, byte budgets,
allowed formats) and picks the best-quality encoding that fits:

```bash
python3 .claude/skills/garmin-store-listing/scripts/make_store_images.py \
    --cover  <source-render-or-screenshot> \
    --screens <shot1> <shot2> <shot3> \
    --outdir images
```

Outputs: `images/cover-500.(png|jpg)` (500×500, <300 KB) and
`images/screen-NN.(png|jpg)` (<150 KB each). The script center-crops the cover to
a square (`--cover-fit contain` to pad on the AMOLED background `000000` instead).

**Where source images come from — capture the REAL, final build only:**
- **Simulator captures** (truest render). Build & run the *current* code, then save
  a frame from the ConnectIQ simulator (its toolbar has a screenshot/save-image
  action). Grab several states for variety: different color pairs, indicator
  vs decorative mode, different metrics, EN and RU, and the always-on screen.
- **On-device screenshots** of an installed build are equally fine.

⚠️ Do **not** use the mockups under `design/` (e.g. `design/screenshots/`): they
are early concept art and differ from the shipped layout, fonts and colors. Store
images must show exactly what users get. Likewise re-capture if the face changed
since an old screenshot was taken.

Capture at the target device resolution (round 454/416/390/360). The script will
downscale/recompress anything oversized to hit the byte budget.

**Color profiles & HDR phone photos.** The script auto-converts any embedded ICC
profile to sRGB so colors stay correct after the profile is dropped on save. A
real on-wrist photo from a phone is often tagged **Display P3 / HDR (PQ)** — after
the (necessary) flatten to sRGB it can look darker than it did on the HDR display.
For such a source, add a midtone lift, e.g. `--brighten 1.3` (≈1.2–1.4 is the
useful range; >1.6 starts to wash out). Renders from the simulator are already
sRGB and need neither. To append a screen in a separate run without renumbering
the existing ones, use `--start-index N` (e.g. generate the renders as 01–02,
then `--screens photo.png --brighten 1.3 --start-index 3` for screen-03).

### 3 — Verify
```bash
python3 - <<'PY'
import os, glob
from PIL import Image
for p in sorted(glob.glob("images/*")):
    if p.lower().endswith((".png",".jpg",".jpeg",".gif")):
        kb=os.path.getsize(p)/1024; w,h=Image.open(p).size
        print(f"{p:28s} {w}x{h:<4} {kb:6.1f} KB")
PY
```
Confirm: cover is exactly 500×500 and < 300 KB; every screen image < 150 KB; all
are JPG/GIF/PNG. Re-run the character check after any text edit.

## Output checklist
- [ ] `GARMIN_STORE.md` exists at the repo root with both languages (EN then RU)
- [ ] Title ≤ 50 chars — EN and RU
- [ ] Description ≤ 4000 chars — EN and RU, feature-accurate
- [ ] `## Changelog` updated — newest version first, brief, user-facing only, EN + RU
- [ ] `images/cover-500.*` — 500×500, < 300 KB
- [ ] `images/screen-*.*` — < 150 KB each, multiple states (palettes, modes, langs, AOD)
