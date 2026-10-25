import Toybox.Lang;
import Toybox.Graphics;

//! Stroke one precomputed curve (side 0 = left, 1 = right) from its start up
//! to `pct` (0..100) of its length — the SVG `pathLength=100` +
//! `stroke-dasharray` of the design.
//!
//! The stroke is ONE filled polygon: the centerline offset by ±pen/2 along the
//! per-vertex normals (forward along one side, back along the other), plus a
//! round cap circle at each end. A single anti-aliased outline keeps the edge
//! smooth — chaining wide drawLine segments with joint circles left a beaded
//! edge. Allocation-free: fills Layout.poly in place.
module Curve {

    function stroke(dc as Graphics.Dc, layout as Layout, side as Number,
                    pct as Number, pen as Number, color as Number,
                    dx as Number, dy as Number) as Void {
        if (pct <= 0) {
            return;
        }
        var xs = (side == 0) ? layout.lx : layout.rx;
        var ys = (side == 0) ? layout.ly : layout.ry;
        var nx = (side == 0) ? layout.lnx : layout.rnx;
        var ny = (side == 0) ? layout.lny : layout.rny;
        var cum = layout.cum;
        var poly = layout.poly;
        var n = xs.size();

        // c = vertices on the lit path; the last one is interpolated.
        var c = n;
        var ex = xs[n - 1];
        var ey = ys[n - 1];
        var enx = nx[n - 1];
        var eny = ny[n - 1];
        for (var i = 1; i < n; i += 1) {
            if (cum[i] >= pct) {
                var span = cum[i] - cum[i - 1];
                var t = (span > 0) ? (pct - cum[i - 1]) / span : 1.0;
                ex = xs[i - 1] + (xs[i] - xs[i - 1]) * t;
                ey = ys[i - 1] + (ys[i] - ys[i - 1]) * t;
                enx = nx[i - 1] + (nx[i] - nx[i - 1]) * t;
                eny = ny[i - 1] + (ny[i] - ny[i - 1]) * t;
                c = i + 1;
                break;
            }
        }

        var h = pen / 2.0;
        for (var i = 0; i < c; i += 1) {
            var x = (i == c - 1) ? ex : xs[i];
            var y = (i == c - 1) ? ey : ys[i];
            var mx = ((i == c - 1) ? enx : nx[i]) * h;
            var my = ((i == c - 1) ? eny : ny[i]) * h;
            var a = poly[i];
            a[0] = x + mx + dx;
            a[1] = y + my + dy;
            var b = poly[2 * c - 1 - i];
            b[0] = x - mx + dx;
            b[1] = y - my + dy;
        }
        // Unused tail = copies of the closing point (zero-length edges), so the
        // preallocated buffer can be passed whole.
        var last = poly[2 * c - 1];
        for (var j = 2 * c; j < poly.size(); j += 1) {
            var p = poly[j];
            p[0] = last[0];
            p[1] = last[1];
        }

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(poly);
        dc.fillCircle(xs[0] + dx, ys[0] + dy, h);
        dc.fillCircle(ex + dx, ey + dy, h);
    }

    //! The dark full-length track under a curve.
    function track(dc as Graphics.Dc, layout as Layout, side as Number,
                   dx as Number, dy as Number) as Void {
        stroke(dc, layout, side, 100, layout.pen, Theme.TRACK, dx, dy);
    }

    //! The lit part of a curve up to `pct`: a pre-mixed halo (widest/dimmest
    //! first), then the core. Draw both tracks before either neon part — the
    //! curves meet at the center and a later track would cover the glow.
    function neon(dc as Graphics.Dc, layout as Layout, side as Number,
                  pct as Number, color as Number, dx as Number, dy as Number) as Void {
        var glow = layout.glow;
        stroke(dc, layout, side, pct, glow[0], Theme.mix(color, 0.07), dx, dy);
        stroke(dc, layout, side, pct, glow[1], Theme.mix(color, 0.16), dx, dy);
        stroke(dc, layout, side, pct, glow[2], Theme.mix(color, 0.32), dx, dy);
        stroke(dc, layout, side, pct, layout.pen, color, dx, dy);
    }
}
