# Custom font pipeline — `NeonTime`, `NeonDate`, `NeonCap`, `NeonVal`

Generates the bitmap fonts the Fun Bra face draws with
(`source/render/FaceRenderer.mc`, `AodRenderer.mc`). The design itself names
**JetBrains Mono**, which ships full Cyrillic, so no substitution is needed.

| Font | Role | Face | design px @450 | tracking | glyphs |
|---|---|---|---|---|---|
| `NeonTime` | clock | JetBrains Mono Light (wght 300) | 62 | 0 | `0–9 :` |
| `NeonDate` | weekday abbrev · date | JetBrains Mono Medium (500) | 13 × 1.95 | 3 × 1.95 | space `0–9 . · -`, A–Z, А–ЯЁ |
| `NeonCap` | curve captions | JetBrains Mono Medium (500) | 11 × 1.95 | 2 × 1.95 | same as NeonDate |
| `NeonVal` | curve values | JetBrains Mono Medium (500) | 18 × 1.3 | 0 | `0–9 % -` |

The small readouts are drawn larger than design for legibility (the clock is
not scaled): values `TEXT_SCALE` = 1.3×, date + captions `BIG_SCALE` = 1.95×
(~1.5× the old size — at that scale the date needs abbreviated weekday names).
Changing either? Re-check the caption/value baselines in `source/Layout.mc`.

Each is a Connect IQ bitmap font (AngelCode BMFont `.fnt` + grayscale
white-on-black `.png`), sized `round(px · screen_w / 450)` per resolution
bucket and registered in each bucket's `fonts.xml`:

| Bucket | serves |
|---|---|
| `resources/fonts/` (base) | 454 round + `venux1` 448×486 rect |
| `resources-round-416x416/fonts/` | 416 round |
| `resources-round-390x390/fonts/` | 390 round |
| `resources-round-360x360/fonts/` | 360 round |

Text is uppercase only (string resources are uppercase), so lowercase is not
subset. Adding a character to any string? Add it to `TEXT_CHARS` and rerun.

## Regenerate

```bash
/Applications/Xcode.app/Contents/Developer/usr/bin/python3 tools/fonts/gen_fonts.py
```

(Pillow with FreeType lives in Xcode's python here.) Source font + license:
`tools/fonts/src/JetBrainsMono-VF.ttf`, `JetBrainsMono-OFL.txt`. The packer is
the same as `../wf/tools/fonts/gen_fonts.py` — atlas width padded to a power of
two (an unaligned width shears glyphs on device).
