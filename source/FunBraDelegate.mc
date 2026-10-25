import Toybox.Lang;
import Toybox.WatchUi;

//! Watch face delegate — used on devices that support partial (per-second)
//! updates. The face draws no seconds, but wiring the delegate lets the
//! system tell us if a future seconds path ever blows the power budget.
class FunBraDelegate extends WatchUi.WatchFaceDelegate {
    private var _view as FunBraView;

    public function initialize(view as FunBraView) {
        WatchFaceDelegate.initialize();
        _view = view;
    }

    public function onPowerBudgetExceeded(powerInfo as WatchUi.WatchFacePowerInfo) as Void {
        _view.disablePartialUpdates();
    }
}
