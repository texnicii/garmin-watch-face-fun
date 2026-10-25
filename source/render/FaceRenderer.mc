import Toybox.Lang;
import Toybox.Graphics;
import Toybox.WatchUi;

//! High-power render of the Neon Rings face (see the neon-rings-face skill).
//! Text is placed on the design's baselines: top = baseline - font ascent.
module FaceRenderer {

    const TOP_CENTER = Graphics.TEXT_JUSTIFY_CENTER;

    //! `indicators` false = decorative mode (curves full, no captions/values);
    //! `dimDots` = the 25% phase of the blink.
    function draw(dc as Graphics.Dc, layout as Layout, data as FaceData,
                  curves as CurveLayer, fonts as Array<Graphics.FontType>,
                  colL as Number, colR as Number,
                  indicators as Boolean, dimDots as Boolean) as Void {
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }
        dc.setColor(Theme.TIME, Theme.BACKGROUND);
        dc.clear();

        curves.draw(dc, layout, data.pctL, data.pctR, colL, colR);

        // Blinking dots inside the curves
        dc.setColor(dimDots ? Theme.mix(colL, 0.25) : colL, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(layout.dotLx, layout.dotY, layout.dotR);
        dc.setColor(dimDots ? Theme.mix(colR, 0.25) : colR, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(layout.dotRx, layout.dotY, layout.dotR);

        var fTime = fonts[0];
        var fDate = fonts[1];
        var fCap = fonts[2];
        var fVal = fonts[3];

        dc.setColor(Theme.TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        text(dc, layout.cx, layout.yDate, fDate, data.dateText);

        dc.setColor(Theme.TIME, Graphics.COLOR_TRANSPARENT);
        text(dc, layout.cx, layout.yTime, fTime, data.timeText);

        if (indicators) {
            dc.setColor(Theme.TEXT_DIM, Graphics.COLOR_TRANSPARENT);
            text(dc, layout.xLeft, layout.yCap, fCap, data.capL);
            text(dc, layout.xRight, layout.yCap, fCap, data.capR);
            dc.setColor(colL, Graphics.COLOR_TRANSPARENT);
            text(dc, layout.xLeft, layout.yVal, fVal, data.valL);
            dc.setColor(colR, Graphics.COLOR_TRANSPARENT);
            text(dc, layout.xRight, layout.yVal, fVal, data.valR);
        }
    }

    //! Centered text whose baseline sits at `baseline`.
    function text(dc as Graphics.Dc, x as Number, baseline as Number,
                  font as Graphics.FontType, s as String) as Void {
        dc.drawText(x, baseline - Graphics.getFontAscent(font), font, s, TOP_CENTER);
    }
}
