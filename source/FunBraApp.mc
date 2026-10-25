import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

//! Application entry point for the "Fun Bra" watch face.
class FunBraApp extends Application.AppBase {
    private var _view as FunBraView?;

    public function initialize() {
        AppBase.initialize();
    }

    public function onStart(state as Dictionary?) as Void {
    }

    public function onStop(state as Dictionary?) as Void {
    }

    //! Initial (and only) view. Pair it with a WatchFaceDelegate where supported.
    public function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        var view = new $.FunBraView();
        _view = view;
        if (WatchUi has :WatchFaceDelegate) {
            return [view, new $.FunBraDelegate(view)];
        }
        return [view];
    }

    //! On-device settings UI. Watch faces can't take input or push views
    //! themselves, so the system presents this Menu2 on our behalf. It writes
    //! the same Application.Properties as the mobile settings.xml.
    public function getSettingsView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] or Null {
        return [new $.SettingsMenu(), new $.SettingsMenuDelegate()];
    }

    //! Re-cache strings when mobile/system settings change.
    public function onSettingsChanged() as Void {
        if (_view != null) {
            _view.applySettings();
        }
        WatchUi.requestUpdate();
    }
}
