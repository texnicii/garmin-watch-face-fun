import Toybox.Lang;

//! Color tokens for the Neon Rings face (see the neon-rings-face skill).
//! Values are taken verbatim from design/neon-rings/Neon.dc.html. 0xRRGGBB.
module Theme {
    // High-power palette
    // Pure black, not the design's #050507: 16-bit screens quantize that to
    // black while the curve BufferedBitmap keeps it, which shows the cached
    // layer as a visible rectangle. Black also keeps AMOLED pixels off.
    const BACKGROUND = 0x000000;
    const TIME       = 0xF4F4FA;  // digital clock
    const TEXT_DIM   = 0x8C8CA0;  // date + curve captions
    const TRACK      = 0x1C1C26;  // unlit curve track

    // Always-on (AOD) safe grays — no white/blue floods
    const AOD_TEXT   = 0xB0B0B0;  // clock + lit curve part in AOD
    const AOD_DIM    = 0x5A5A5A;  // date + curve hairline in AOD

    // Curve color pairs [left, right] — the `palette` setting indexes this.
    // Index order matches settings.xml / properties.xml / SettingsMenu.
    const PALETTES = [
        [0x3EE6E0, 0xFF4FA3],  // 0 — turquoise / pink (design default)
        [0xB6FF3B, 0xA86BFF],  // 1 — lime / violet
        [0xFF8A3D, 0x3DB2FF],  // 2 — orange / sky blue
        [0xFF3B5C, 0xFFC93D]   // 3 — scarlet / gold
    ] as Array<Array<Number> >;

    //! Left (side 0) or right (side 1) curve color of palette `idx`, falling
    //! back to the design pair for any out-of-range value.
    function curveColor(idx as Number, side as Number) as Number {
        if (idx < 0 or idx >= PALETTES.size()) {
            idx = 0;
        }
        return PALETTES[idx][side];
    }

    //! `rgb` blended over BACKGROUND at `a` (0.0..1.0). Glow halos and the dim
    //! blink phase are pre-mixed against the black field, so they render the
    //! same on every device without needing alpha support.
    function mix(rgb as Number, a as Float) as Number {
        var r = mixChannel((rgb >> 16) & 0xFF, (BACKGROUND >> 16) & 0xFF, a);
        var g = mixChannel((rgb >> 8) & 0xFF, (BACKGROUND >> 8) & 0xFF, a);
        var b = mixChannel(rgb & 0xFF, BACKGROUND & 0xFF, a);
        return (r << 16) | (g << 8) | b;
    }

    function mixChannel(c as Number, bg as Number, a as Float) as Number {
        return (bg + (c - bg) * a + 0.5).toNumber();
    }
}
