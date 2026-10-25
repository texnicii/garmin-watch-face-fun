---
name: neon-rings-face
description: Source of truth for the "Fun Bra" watch-face design (Claude Design artboard "01 · Неон-кольца" / Neon Rings). Use whenever implementing, restyling, reviewing, or verifying any rendering/layout/color/typography of this Garmin watch face — it defines the layout anatomy, color tokens, curve geometry, glow, blink and AMOLED/always-on adaptation. Consult before writing or changing any code under source/render/, Layout.mc, Theme.mc, or resources/fonts & strings.
---

# Neon Rings («Fun Bra») — design source of truth

The design is a single artboard exported from Claude Design:

- `design/neon-rings/Neon.dc.html` — the artboard. Its inline SVG attributes are
  the spec (read it as data; don't ship it). Props: `left` `#3EE6E0`,
  `right` `#FF4FA3`, `leftPct` 72, `rightPct` 64.
- `design/neon-rings/reference.png` — headless-Chrome render of the artboard
  (450×450). **Open it and compare** when verifying a render. Note: the mockup's
  `{{leftPct}}%` text placeholders don't interpolate in the export, so the
  reference shows a bare `%` under each curve — the face shows e.g. `72%`.

The canvas is **450×450 round** on `#050507`. Every value below is in design
px; the code scales by `k = s/450` (`s` = min screen dim) and centers, so it
fits 360/390/416/454 round and the 448×486 rect (`venux1`). See `Layout.mc`.

## Concept (don't lose this)

A playful neon face: a big thin digital clock up top, and two mirrored glowing
curves (cups) meeting at the center, each with a dot inside. The curves are
**progress indicators** — each fills from its outer top end toward the center
— or, in decorative mode, simply full. Everything else is quiet gray metadata.

## Anatomy (design px on the 450 canvas)

| Element | Geometry | Style |
|---|---|---|
| **Date** | centered, baseline y=96 | JetBrains Mono 500, 13px, tracking 3 (**device: ×1.3**), `#8C8CA0`, `СУББОТА · 24 ОКТ` (full weekday · day · month abbrev, uppercase) |
| **Time** | centered, baseline y=162 | JetBrains Mono **300**, 62px, `#F4F4FA`, `10:09` (12/24h per device) |
| **Curves** | nested svg at (45,70), 360×360, viewBox 512 → `x = 45 + v·0.703`, `y = 70 + v·0.703` | stroke `34·0.703 ≈ 23.9px`, round caps |
| ↳ left path | `M55 155 C-5 215 15 330 110 370 C190 400 255 330 256 238` | track `#1C1C26` full length; lit part = left color |
| ↳ right path | mirror of left (`x → 512 − x`) | lit part = right color |
| **Fill** | `pathLength=100`, `stroke-dasharray="pct 100"` → lit from path **start** (outer top) toward the center | clamp 0..100 |
| **Glow** | `drop-shadow(0 0 10px color)` in the nested svg's units (~7 design px) | lit part only, not the track |
| **Dots** | r = `22·0.703 ≈ 15.5`, centers viewBox (120,283) / (392,283) | fill = curve color, no glow |
| **Blink** | dots: 2 s cycle, `steps(1)`: 1 s at 100% → 1 s at 25% | |
| **Captions** | baseline y=384 (**device: 380**), x=129 / 321 | 500, 11px, tracking 2 (**device: ×1.3**), `#8C8CA0` (`АКТИВН.`, `ЗАРЯД`) |
| **Values** | baseline y=404 (**device: 405**), x=129 / 321 | 500, 18px (**device: ×1.3**), curve color, `72%` |

**Deliberate deviation:** the date, captions and values are drawn **1.3× the
design size** (user request: legibility on the wrist). This is `TEXT_SCALE` in
`tools/fonts/gen_fonts.py`; the clock keeps its design size. To keep the
caption/value gap and clear the curve glow, their baselines are 380/405 instead
of 384/404 (`Layout.mc`). Retune both together if the scale changes.

Text is placed by **baseline**: `top = baseline − Graphics.getFontAscent(font)`,
drawn `TEXT_JUSTIFY_CENTER`. Tracking is baked into the bitmap fonts'
`xadvance` (see `tools/fonts/`), so it also trails the last glyph exactly like
SVG `letter-spacing` with `text-anchor="middle"`.

## Color tokens (→ `Theme.mc`)

```
BACKGROUND  0x000000   // field — design says #050507, see note below
TIME        0xF4F4FA   // clock
TEXT_DIM    0x8C8CA0   // date + captions
TRACK       0x1C1C26   // unlit curve track
AOD_TEXT    0xB0B0B0   // AOD clock + lit curve line
AOD_DIM     0x5A5A5A   // AOD date + curve hairline
```

**Background is pure black on device**, not the design's `#050507`: 16-bit
screens quantize `#050507` to black but the cached curve `BufferedBitmap` keeps
it, so the curve layer showed as a lighter rectangle in the simulator. Don't
reintroduce a non-black field without making the layer background match.

Curve color pairs (`Theme.PALETTES`, setting `palette`): **0 = `3EE6E0` /
`FF4FA3` (design)**, 1 = `B6FF3B` / `A86BFF`, 2 = `FF8A3D` / `3DB2FF`,
3 = `FF3B5C` / `FFC93D`. Glow halos and the 25% blink phase are colors
**pre-mixed over `BACKGROUND`** (`Theme.mix`) — no alpha needed on any device.

## Rendering recipe (what the code does — keep it)

1. `Layout` flattens each curve into 31 vertices (15 samples per cubic), a
   cumulative length normalized to 0..100 and a unit normal per vertex, once
   in `onLayout`; it also preallocates a 62-point outline buffer.
2. `Curve.stroke` builds the stroke up to `pct` as **one `fillPolygon`** (the
   centerline offset ±pen/2 along the normals, last vertex interpolated,
   unused buffer tail padded with the closing point) plus a round-cap
   `fillCircle` at each end. Don't go back to chained wide `drawLine`s +
   joint circles: their AA edges bead visibly. Keep vertices ≤ 32 per curve —
   `fillPolygon` takes at most 64 points. The tightest bend (~64 px radius
   @454) is far wider than the widest halo half-width (19 px), so the outline
   never folds.
3. Order: **both tracks first**, then each lit part as 3 halo passes (pen +
   2·{7, 4.5, 2.5}·k at mix {0.07, 0.16, 0.32}) and the core. A later track
   would cover the other curve's glow where they meet at the center.
4. `CurveLayer` caches step 3 in a `BufferedBitmap` (curve bbox) keyed by
   (pctL, pctR, colors); the per-second blink just blits it. Without
   `createBufferedBitmap` (or after a pool purge) it draws direct.
5. Then dots, date, time, and — only in indicator mode — captions + values.

## Metrics (`Metrics.mc`, settings `leftMetric` / `rightMetric`)

0 = steps / step goal · 1 = active (intensity) minutes today / (weekly goal ÷ 7,
default 150) · 2 = battery. Curve fill is clamped to 100; the value text shows
the real percent (capped at 999). Defaults: left = 1 (design caption
`АКТИВН.`), right = 2 (`ЗАРЯД`). Captions: STEPS/ШАГИ, ACTIVE/АКТИВН.,
BATTERY/ЗАРЯД.

Decorative mode (`curveMode` = 1): both curves at 100%, no captions/values.

## AMOLED always-on (AOD) — required

- Grays only, no glow, no dots, no captions/values. Clock in `AOD_TEXT` with the
  same `NeonTime` font (thin Light strokes), date in `AOD_DIM`.
- Curves as 2 px `AOD_DIM` hairlines; in indicator mode the lit part as a 3 px
  `AOD_TEXT` line.
- Whole layout pixel-shifted by `dx = m%5 − 2`, `dy = (m/5)%5 − 2` each minute.
- Well under the 10 % lit-pixel budget — keep it that way.

## Blink (high-power only)

`Timer` 1 s, started in `onShow`/`onExitSleep` (when the `blink` setting is
on), stopped in `onHide`/`onEnterSleep`, and self-stops after 10 ticks (~the
high-power window), ending at full brightness. Never blink in AOD.
