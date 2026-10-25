import Toybox.Lang;

//! Per-frame snapshot of everything the renderers draw. Built by
//! FunBraView.buildData(), consumed by FaceRenderer / AodRenderer.
class FaceData {
    public var timeText as String = "";
    public var dateText as String = "";
    public var minute as Number = 0;

    // Curve fill (0..100, clamped) and the matching readout ("72%")
    public var pctL as Number = 0;
    public var pctR as Number = 0;
    public var valL as String = "";
    public var valR as String = "";
    public var capL as String = "";
    public var capR as String = "";

    public function initialize() {
    }
}
