import Toybox.Lang;
import Toybox.Graphics;

//! Both neon curves (tracks + glow + cores), cached in a BufferedBitmap the
//! size of the curves' bounding box. The layer is 10 polygons + caps, but only
//! changes when a fill percent or the palette does, so the per-second blink
//! redraws just blit it. Devices without createBufferedBitmap (or when the
//! graphics pool purged it) draw the curves straight to the screen.
class CurveLayer {
    private var _ref as Graphics.BufferedBitmapReference?;
    private var _pctL as Number = -1;
    private var _pctR as Number = -1;
    private var _colL as Number = -1;
    private var _colR as Number = -1;

    public function initialize() {
    }

    //! Forget the cached pixels (new layout / screen geometry).
    public function invalidate() as Void {
        _ref = null;
        _pctL = -1;
    }

    public function draw(dc as Graphics.Dc, layout as Layout, pctL as Number,
                         pctR as Number, colL as Number, colR as Number) as Void {
        if (Graphics has :createBufferedBitmap) {
            var ref = _ref;
            if (ref == null) {
                ref = Graphics.createBufferedBitmap({
                    :width => layout.boxW,
                    :height => layout.boxH
                });
                _ref = ref;
                _pctL = -1;
            }
            var bmp = ref.get() as Graphics.BufferedBitmap?;
            if (bmp != null) {
                if (pctL != _pctL or pctR != _pctR or colL != _colL or colR != _colR) {
                    var bdc = bmp.getDc();
                    bdc.setColor(Theme.BACKGROUND, Theme.BACKGROUND);
                    bdc.clear();
                    render(bdc, layout, pctL, pctR, colL, colR, -layout.boxX, -layout.boxY);
                    _pctL = pctL;
                    _pctR = pctR;
                    _colL = colL;
                    _colR = colR;
                }
                dc.drawBitmap(layout.boxX, layout.boxY, bmp);
                return;
            }
            // Purged by the graphics pool — rebuild next frame.
            _ref = null;
        }
        render(dc, layout, pctL, pctR, colL, colR, 0, 0);
    }

    private function render(dc as Graphics.Dc, layout as Layout, pctL as Number,
                            pctR as Number, colL as Number, colR as Number,
                            dx as Number, dy as Number) as Void {
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }
        Curve.track(dc, layout, 0, dx, dy);
        Curve.track(dc, layout, 1, dx, dy);
        Curve.neon(dc, layout, 0, pctL, colL, dx, dy);
        Curve.neon(dc, layout, 1, pctR, colR, dx, dy);
    }
}
