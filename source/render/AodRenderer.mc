import Toybox.Lang;
import Toybox.Graphics;

//! Always-on / low-power render. Burn-in safe per Garmin AMOLED rules:
//! sparse (<=10% pixels), grays only (no neon colors, no glow, no dots), and
//! the whole layout is pixel-shifted by a few px each minute.
module AodRenderer {

    function draw(dc as Graphics.Dc, layout as Layout, data as FaceData,
                  fonts as Array<Graphics.FontType>, indicators as Boolean) as Void {
        dc.setColor(Theme.AOD_TEXT, Theme.BACKGROUND);
        dc.clear();
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }

        // Minute-derived pixel shift in [-2, +2] on each axis.
        var m = data.minute;
        var dx = (m % 5) - 2;
        var dy = ((m / 5) % 5) - 2;

        // Curve outlines as hairlines; in indicator mode the filled part is a
        // slightly thicker, lighter line.
        Curve.stroke(dc, layout, 0, 100, 2, Theme.AOD_DIM, dx, dy);
        Curve.stroke(dc, layout, 1, 100, 2, Theme.AOD_DIM, dx, dy);
        if (indicators) {
            Curve.stroke(dc, layout, 0, data.pctL, 3, Theme.AOD_TEXT, dx, dy);
            Curve.stroke(dc, layout, 1, data.pctR, 3, Theme.AOD_TEXT, dx, dy);
        }

        dc.setColor(Theme.AOD_DIM, Graphics.COLOR_TRANSPARENT);
        FaceRenderer.text(dc, layout.cx + dx, layout.yDate + dy, fonts[1], data.dateText);

        dc.setColor(Theme.AOD_TEXT, Graphics.COLOR_TRANSPARENT);
        FaceRenderer.text(dc, layout.cx + dx, layout.yTime + dy, fonts[0], data.timeText);
    }
}
