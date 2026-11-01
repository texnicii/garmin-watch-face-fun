#!/usr/bin/env python3
"""Generate the custom Connect IQ bitmap fonts for the Fun Bra (Neon Rings) face.

Four fonts, each an AngelCode BMFont text `.fnt` + a grayscale (white-on-black)
`.png` atlas, subset to exactly the glyphs the face can show, one size per
screen-resolution bucket (design px x screen_w / 450):

  NeonTime  digital clock              JetBrains Mono Light  (wght 300)  62px
  NeonDate  weekday + date             JetBrains Mono Medium (wght 500)  13px, tracking 3  (x BIG_SCALE)
  NeonCap   curve captions             JetBrains Mono Medium (wght 500)  11px, tracking 2  (x BIG_SCALE)
  NeonVal   curve values (72%)         JetBrains Mono Medium (wght 500)  18px              (x TEXT_SCALE)

The design (design/neon-rings/Neon.dc.html) names JetBrains Mono itself, which
carries full Cyrillic, so no substitution is needed (unlike ../wf).

Pipeline (render_glyph/build) is copied from ../wf/tools/fonts/gen_fonts.py.

Reproducible:  python3 tools/fonts/gen_fonts.py   (needs Pillow with FreeType —
               Xcode's /Applications/Xcode.app/Contents/Developer/usr/bin/python3)
Source TTF:    tools/fonts/src/JetBrainsMono-VF.ttf (+ JetBrainsMono-OFL.txt)
"""

import os
from PIL import Image, ImageFont, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "src")
REPO = os.path.normpath(os.path.join(HERE, "..", ".."))
PAD = 1                      # transparent gutter between packed glyphs
TTF = "JetBrainsMono-VF.ttf"
DESIGN = 450.0               # design canvas size (px)

# Resolution buckets: (screen_w, resource dir). Base serves 454 round + venux1
# (448 rect) fallback; the rest are auto-selected qualifier folders by W×H.
BUCKETS = [
    (454, "resources/fonts"),
    (416, "resources-round-416x416/fonts"),
    (390, "resources-round-390x390/fonts"),
    (360, "resources-round-360x360/fonts"),
]

# Uppercase only (date + captions are uppercase string resources). Full Latin +
# Cyrillic upper alphabets so any localized weekday / month / caption renders.
TEXT_CHARS = (" 0123456789.·-"
              + "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
              + "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ")

# The small readouts (date, captions, values) are drawn larger than the
# design's 13/11/18 px for legibility on the wrist; size and tracking scale
# together. The clock keeps the design size. The date and captions get
# BIG_SCALE (~1.5x TEXT_SCALE, user request); at that size the date only
# fits with abbreviated weekday names, so the widest-string check uses them.
TEXT_SCALE = 1.3
BIG_SCALE = TEXT_SCALE * 1.5

# (id, face name, wght, design px, design tracking px, glyphs, widest strings)
FONTS = [
    ("NeonTime", "JetBrains Mono Light", 300, 62, 0, "0123456789:", ["00:00"]),
    ("NeonDate", "JetBrains Mono Medium", 500, 13 * BIG_SCALE, 3 * BIG_SCALE, TEXT_CHARS,
     ["ЧТ · 24 ОКТ", "THU · 24 SEP"]),
    ("NeonCap", "JetBrains Mono Medium", 500, 11 * BIG_SCALE, 2 * BIG_SCALE, TEXT_CHARS,
     ["АКТИВН.", "BATTERY"]),
    ("NeonVal", "JetBrains Mono Medium", 500, 18 * TEXT_SCALE, 0, "0123456789%-", ["999%"]),
]


def load(ttf, px, wght):
    f = ImageFont.truetype(os.path.join(SRC, ttf), px)
    f.set_variation_by_axes([wght])
    return f


def widest_px(font, words):
    return max(font.getlength(w) for w in words)


def pow2_ceil(n):
    """Smallest power of two >= n."""
    p = 1
    while p < n:
        p <<= 1
    return p


def render_glyph(font, ch, track):
    """Render one glyph; return (cropped 'L' image|None, xoff, yoff, xadvance).

    Drawn with anchor 'la' so (0,0) is the line top; the ink bbox gives BMFont
    x/y offsets directly. `track` (px) is added to xadvance for letter-spacing.
    """
    asc, desc = font.getmetrics()
    w = int(font.getlength(ch)) + 4 * PAD + asc
    h = asc + desc + 4 * PAD
    img = Image.new("L", (max(w, 2), max(h, 2)), 0)
    ox = oy = 2 * PAD
    ImageDraw.Draw(img).text((ox, oy), ch, font=font, fill=255, anchor="la")
    adv = int(round(font.getlength(ch))) + track
    bbox = img.getbbox()
    if bbox is None:                      # whitespace
        return None, 0, 0, adv
    l, t, r, b = bbox
    return img.crop(bbox), l - ox, t - oy, adv


def build(name, ttf, wght, face, chars, em, track_em, screen_w, out_rel, widest):
    font = load(ttf, em, wght)
    asc, desc = font.getmetrics()
    track = int(round(track_em * em))

    glyphs = []
    for ch in chars:
        img, xoff, yoff, xadv = render_glyph(font, ch, track)
        gw, gh = (img.size if img else (0, 0))
        glyphs.append((ch, img, gw, gh, xoff, yoff, xadv))

    drawn = [g for g in glyphs if g[1] is not None]
    total = sum((g[2] + PAD) * (g[3] + PAD) for g in drawn)
    shelf_w = max(max(g[2] for g in drawn) + PAD, int((total ** 0.5) * 1.15))
    drawn.sort(key=lambda g: g[3], reverse=True)

    placed = {}
    x = y = row_h = 0
    for ch, img, gw, gh, *_ in drawn:
        if x + gw + PAD > shelf_w:
            x = 0
            y += row_h + PAD
            row_h = 0
        placed[ch] = (x, y)
        x += gw + PAD
        row_h = max(row_h, gh)
    atlas_h = y + row_h + PAD

    # Connect IQ's font blitter uses the atlas width as the row stride. An
    # unaligned (e.g. odd) width shears every glyph into diagonal scanlines on
    # device, so pad the width up to a power of two (the SDK's own bitmap fonts
    # are 256-wide). Glyphs were packed within shelf_w, so every x position stays
    # valid; the extra right-hand columns are just black padding.
    atlas_w = pow2_ceil(shelf_w)

    atlas = Image.new("L", (atlas_w, atlas_h), 0)
    for ch, img, *_ in drawn:
        atlas.paste(img, placed[ch])

    out_dir = os.path.join(REPO, out_rel)
    os.makedirs(out_dir, exist_ok=True)
    png = name + "_0.png"
    atlas.save(os.path.join(out_dir, png), optimize=True)

    lines = [
        'info face="%s" size=-%d bold=0 italic=0 charset="" unicode=1 '
        'stretchH=100 smooth=1 aa=1 padding=0,0,0,0 spacing=1,1 outline=0'
        % (face, em),
        'common lineHeight=%d base=%d scaleW=%d scaleH=%d pages=1 packed=0 '
        'alphaChnl=1 redChnl=0 greenChnl=0 blueChnl=0'
        % (asc + desc, asc, atlas_w, atlas_h),
        'page id=0 file="%s"' % png,
        'chars count=%d' % len(glyphs),
    ]
    for ch, img, gw, gh, xoff, yoff, xadv in glyphs:
        gx, gy = placed.get(ch, (0, 0))
        lines.append(
            'char id=%-5d x=%-5d y=%-5d width=%-5d height=%-5d xoffset=%-5d '
            'yoffset=%-5d xadvance=%-5d page=0 chnl=15'
            % (ord(ch), gx, gy, gw, gh, xoff, yoff, xadv))
    with open(os.path.join(out_dir, name + ".fnt"), "w", encoding="utf-8") as fp:
        fp.write("\n".join(lines) + "\n")

    wpx = widest_px(font, widest) + track * max(len(w) for w in widest)
    print("  %-30s em=%-3d atlas=%dx%-4d widest=%dpx(%.0f%%W) png=%dB"
          % (out_rel, em, atlas_w, atlas_h, round(wpx),
             100.0 * wpx / screen_w,
             os.path.getsize(os.path.join(out_dir, png))))


if __name__ == "__main__":
    for sw, out in BUCKETS:
        k = sw / DESIGN
        for name, face, wght, px, track_px, chars, widest in FONTS:
            em = int(round(px * k))
            track = int(round(track_px * k))
            build(name, TTF, wght, face, chars, em, float(track) / em, sw, out, widest)
