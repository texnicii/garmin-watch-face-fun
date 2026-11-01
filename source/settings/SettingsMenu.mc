import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

//! On-device settings UI for the watch face. Watch faces may not take input or
//! push views themselves, so the system presents this via
//! AppBase.getSettingsView(). It reads/writes the SAME Application.Properties
//! keys as the mobile settings.xml, so the two stay in sync.
//!
//! List rows cycle their property to the next value on select (compact, works
//! on touch + button devices); the blink row is a toggle.
class SettingsMenu extends WatchUi.Menu2 {

    public function initialize() {
        Menu2.initialize({:title => str($.Rez.Strings.setTitle)});
        addItem(new WatchUi.MenuItem(str($.Rez.Strings.setCurves), curvesLabel(), :curveMode, null));
        addItem(new WatchUi.MenuItem(str($.Rez.Strings.setLeft), metricLabel("leftMetric"), :leftMetric, null));
        addItem(new WatchUi.MenuItem(str($.Rez.Strings.setRight), metricLabel("rightMetric"), :rightMetric, null));
        addItem(new WatchUi.ToggleMenuItem(str($.Rez.Strings.setReadouts), null, :readouts,
            getBool("readouts", true), null));
        addItem(new WatchUi.MenuItem(str($.Rez.Strings.setPalette), paletteLabel(), :palette, null));
        addItem(new WatchUi.MenuItem(str($.Rez.Strings.setLang), langLabel(), :langMode, null));
        addItem(new WatchUi.ToggleMenuItem(str($.Rez.Strings.setBlink), null, :blink,
            getBool("blink", true), null));
    }

    static function str(id as ResourceId) as String {
        return WatchUi.loadResource(id) as String;
    }

    //! Property read coerced to a Number with a fallback default.
    static function getNum(key as String, dflt as Number) as Number {
        var v = Application.Properties.getValue(key);
        return (v instanceof Number) ? v : dflt;
    }

    //! Property read coerced to a Boolean with a fallback default.
    static function getBool(key as String, dflt as Boolean) as Boolean {
        var v = Application.Properties.getValue(key);
        return (v instanceof Boolean) ? v : dflt;
    }

    static function curvesLabel() as String {
        return str((getNum("curveMode", 0) == 1) ? $.Rez.Strings.setCurvesDeco : $.Rez.Strings.setCurvesInd);
    }

    static function metricLabel(key as String) as String {
        var m = getNum(key, key.equals("leftMetric") ? Metrics.ACTIVE : Metrics.BATTERY);
        var id = $.Rez.Strings.setMetricBattery;
        if (m == Metrics.STEPS) { id = $.Rez.Strings.setMetricSteps; }
        else if (m == Metrics.ACTIVE) { id = $.Rez.Strings.setMetricActive; }
        return str(id);
    }

    static function paletteLabel() as String {
        var p = getNum("palette", 0);
        var id = $.Rez.Strings.setPal0;
        if (p == 1) { id = $.Rez.Strings.setPal1; }
        else if (p == 2) { id = $.Rez.Strings.setPal2; }
        else if (p == 3) { id = $.Rez.Strings.setPal3; }
        return str(id);
    }

    static function langLabel() as String {
        var l = getNum("langMode", 0);
        var id = $.Rez.Strings.setLangAuto;
        if (l == 1) { id = $.Rez.Strings.setLangEn; }
        else if (l == 2) { id = $.Rez.Strings.setLangRu; }
        return str(id);
    }
}

//! Cycles the selected property and updates the row's sub-label in place.
class SettingsMenuDelegate extends WatchUi.Menu2InputDelegate {

    public function initialize() {
        Menu2InputDelegate.initialize();
    }

    public function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :curveMode) {
            Application.Properties.setValue("curveMode", 1 - SettingsMenu.getNum("curveMode", 0));
            item.setSubLabel(SettingsMenu.curvesLabel());
        } else if (id == :leftMetric) {
            cycle("leftMetric", Metrics.ACTIVE, Metrics.COUNT);
            item.setSubLabel(SettingsMenu.metricLabel("leftMetric"));
        } else if (id == :rightMetric) {
            cycle("rightMetric", Metrics.BATTERY, Metrics.COUNT);
            item.setSubLabel(SettingsMenu.metricLabel("rightMetric"));
        } else if (id == :palette) {
            cycle("palette", 0, Theme.PALETTES.size());
            item.setSubLabel(SettingsMenu.paletteLabel());
        } else if (id == :langMode) {
            cycle("langMode", 0, 3);
            item.setSubLabel(SettingsMenu.langLabel());
        } else if (id == :blink and item instanceof WatchUi.ToggleMenuItem) {
            Application.Properties.setValue("blink", item.isEnabled());
        } else if (id == :readouts and item instanceof WatchUi.ToggleMenuItem) {
            Application.Properties.setValue("readouts", item.isEnabled());
        }
        WatchUi.requestUpdate();
    }

    private function cycle(key as String, dflt as Number, count as Number) as Void {
        Application.Properties.setValue(key, (SettingsMenu.getNum(key, dflt) + 1) % count);
    }
}
