import Toybox.Lang;
import Toybox.Graphics;
import Toybox.Math;

//! Resolution-relative geometry for the Neon Rings face. Every anchor is the
//! design value on its 450 px canvas scaled by s/450 (s = min screen dim) and
//! centered, so the face scales across 360/390/416/454 round screens and the
//! venux1 rectangle. Both bezier curves are flattened into polylines here,
//! once, so the renderers only walk precomputed arrays. See the
//! neon-rings-face skill for the canonical anatomy.
class Layout {
    const DESIGN = 450.0;
    // Polyline samples per cubic segment. 2*15+1 = 31 vertices -> a stroke
    // outline of 62 points, inside Dc.fillPolygon's 64-point limit.
    const STEPS = 15;

    public var w as Number = 0;
    public var h as Number = 0;
    public var cx as Number = 0;

    // Text baselines (y) and caption/value columns (x), pixels
    public var yDate as Number = 0;
    public var yTime as Number = 0;
    public var yCap as Number = 0;
    public var yVal as Number = 0;
    public var xLeft as Number = 0;
    public var xRight as Number = 0;

    // Curves: polyline vertices + cumulative length normalized to 0..100
    public var lx as Array<Float> = [];
    public var ly as Array<Float> = [];
    public var rx as Array<Float> = [];
    public var ry as Array<Float> = [];
    public var cum as Array<Float> = [];  // shared — the curves are mirrors
    // Unit normals per vertex (central-difference tangent rotated 90°)
    public var lnx as Array<Float> = [];
    public var lny as Array<Float> = [];
    public var rnx as Array<Float> = [];
    public var rny as Array<Float> = [];
    // Reused outline buffer for Curve.stroke (2 points per vertex)
    public var poly as Array<Graphics.Point2D> = [];
    public var pen as Number = 0;          // curve stroke width
    public var glow as Array<Number> = []; // halo pen widths, widest first

    // Blinking dots
    public var dotR as Number = 0;
    public var dotY as Number = 0;
    public var dotLx as Number = 0;
    public var dotRx as Number = 0;

    // Bounding box of both curves incl. glow (the cached curve layer)
    public var boxX as Number = 0;
    public var boxY as Number = 0;
    public var boxW as Number = 0;
    public var boxH as Number = 0;

    private var _k as Float = 1.0;
    private var _ox as Float = 0.0;
    private var _oy as Float = 0.0;

    public function initialize(dc as Graphics.Dc) {
        w = dc.getWidth();
        h = dc.getHeight();
        cx = w / 2;
        var s = (w < h) ? w : h;
        _k = s / DESIGN;
        _ox = (w - s) / 2.0;
        _oy = (h - s) / 2.0;

        yDate  = py(96.0);
        yTime  = py(162.0);
        // Design baselines are 384 / 404; with the readout fonts at
        // TEXT_SCALE / BIG_SCALE (tools/fonts) the pair moves to keep the
        // design's ~7 px gap between caption and value and clear the curve
        // glow above.
        yCap   = py(376.0);
        yVal   = py(400.0);
        xLeft  = px(129.0);
        xRight = px(321.0);

        // The curves live in a nested 360x360 svg at (45, 70), viewBox 512.
        pen = sz(34.0 * 360.0 / 512.0);
        if (pen < 4) { pen = 4; }
        // Halo bands approximating the design's drop-shadow(0 0 10px), whose
        // blur is in the nested svg's user units (~7 design px on screen).
        glow = [pen + 2 * sz(7.0), pen + 2 * sz(4.5), pen + 2 * sz(2.5)];

        dotR  = sz(22.0 * 360.0 / 512.0);
        dotY  = py(curveY(283.0));
        dotLx = px(curveX(120.0));
        dotRx = px(curveX(392.0));

        flatten();
    }

    //! Sample the left curve
    //! `M55 155 C-5 215 15 330 110 370 C190 400 255 330 256 238`
    //! (viewBox 512) into 2*STEPS+1 vertices; the right curve mirrors x.
    private function flatten() as Void {
        var n = 2 * STEPS + 1;
        lx = new Array<Float>[n];
        ly = new Array<Float>[n];
        rx = new Array<Float>[n];
        ry = new Array<Float>[n];
        cum = new Array<Float>[n];
        sample(0, [55.0, 155.0, -5.0, 215.0, 15.0, 330.0, 110.0, 370.0]);
        sample(STEPS, [110.0, 370.0, 190.0, 400.0, 255.0, 330.0, 256.0, 238.0]);

        var total = 0.0 as Float;
        cum[0] = 0.0;
        for (var i = 1; i < n; i += 1) {
            var dx = lx[i] - lx[i - 1];
            var dy = ly[i] - ly[i - 1];
            total += Math.sqrt(dx * dx + dy * dy).toFloat();
            cum[i] = total;
        }
        var minX = lx[0];
        var maxY = ly[0];
        var minY = ly[0];
        for (var i = 0; i < n; i += 1) {
            cum[i] = (total > 0) ? cum[i] * 100.0 / total : 0.0;
            if (lx[i] < minX) { minX = lx[i]; }
            if (ly[i] < minY) { minY = ly[i]; }
            if (ly[i] > maxY) { maxY = ly[i]; }
        }
        var pad = glow[0] / 2 + 2;
        boxX = minX.toNumber() - pad;
        boxY = minY.toNumber() - pad;
        boxW = w - 2 * boxX;
        boxH = maxY.toNumber() + pad - boxY;

        lnx = new Array<Float>[n];
        lny = new Array<Float>[n];
        rnx = new Array<Float>[n];
        rny = new Array<Float>[n];
        normals(lx, ly, lnx, lny);
        normals(rx, ry, rnx, rny);
        poly = [] as Array<Graphics.Point2D>;
        for (var i = 0; i < 2 * n; i += 1) {
            poly.add([0.0, 0.0] as Graphics.Point2D);
        }
    }

    //! Unit normal at each vertex from the central-difference tangent
    //! (one-sided at the ends). The tightest bend (~64 px radius @454) is far
    //! wider than the widest halo half-width, so offset outlines never fold.
    private function normals(xs as Array<Float>, ys as Array<Float>,
                             nx as Array<Float>, ny as Array<Float>) as Void {
        var n = xs.size();
        for (var i = 0; i < n; i += 1) {
            var a = (i > 0) ? i - 1 : 0;
            var b = (i < n - 1) ? i + 1 : n - 1;
            var tx = xs[b] - xs[a];
            var ty = ys[b] - ys[a];
            var len = Math.sqrt(tx * tx + ty * ty).toFloat();
            if (len <= 0) {
                len = 1.0;
            }
            nx[i] = -ty / len;
            ny[i] = tx / len;
        }
    }

    //! Write STEPS+1 samples of one cubic (p = x0 y0 x1 y1 x2 y2 x3 y3, viewBox
    //! units) starting at vertex `at`.
    private function sample(at as Number, p as Array<Float>) as Void {
        for (var j = 0; j <= STEPS; j += 1) {
            var t = j.toFloat() / STEPS;
            var u = 1.0 - t;
            var a = u * u * u;
            var b = 3.0 * u * u * t;
            var c = 3.0 * u * t * t;
            var d = t * t * t;
            var vx = a * p[0] + b * p[2] + c * p[4] + d * p[6];
            var vy = a * p[1] + b * p[3] + c * p[5] + d * p[7];
            lx[at + j] = pxf(curveX(vx));
            ly[at + j] = pyf(curveY(vy));
            rx[at + j] = pxf(curveX(512.0 - vx));
            ry[at + j] = ly[at + j];
        }
    }

    // viewBox-512 curve coordinates -> design-canvas coordinates
    private function curveX(v as Float) as Float { return 45.0 + v * 360.0 / 512.0; }
    private function curveY(v as Float) as Float { return 70.0 + v * 360.0 / 512.0; }

    // design-canvas coordinates/sizes -> screen pixels
    private function pxf(v as Float) as Float { return _ox + v * _k; }
    private function pyf(v as Float) as Float { return _oy + v * _k; }
    private function px(v as Float) as Number { return (pxf(v) + 0.5).toNumber(); }
    private function py(v as Float) as Number { return (pyf(v) + 0.5).toNumber(); }
    private function sz(v as Float) as Number { return (v * _k + 0.5).toNumber(); }
}
