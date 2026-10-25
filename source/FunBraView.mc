import Toybox.ActivityMonitor;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Timer;
import Toybox.WatchUi;

//! The watch face view. Owns lifecycle, settings, data acquisition and the
//! dot blink timer, then delegates pixels to FaceRenderer (awake) or
//! AodRenderer (always-on). Strings, fonts and geometry are cached outside
//! the hot path.
class FunBraView extends WatchUi.WatchFace {
    // Blink: 1 s per phase (design: 2 s cycle, 100% <-> 25%), only during the
    // ~10 s high-power window after a wake.
    const BLINK_MS = 1000;
    const BLINK_TICKS = 10;

    private var _isAwake as Boolean = true;
    private var _layout as Layout?;
    private var _curves as CurveLayer = new CurveLayer();
    private var _fonts as Array<Graphics.FontType> = [];  // time, date, caption, value

    private var _timer as Timer.Timer?;
    private var _blinkTicks as Number = 0;
    private var _dimDots as Boolean = false;

    // User-setting-driven caches (rebuilt by applySettings)
    private var _indicators as Boolean = true;
    private var _metricL as Number = Metrics.ACTIVE;
    private var _metricR as Number = Metrics.BATTERY;
    private var _colL as Number = 0;
    private var _colR as Number = 0;
    private var _blink as Boolean = true;
    private var _caps as Array<String> = [];  // per Metrics index
    private var _dow as Array<String> = [];   // 7 weekday names (Sun-first)
    private var _mon as Array<String> = [];   // 12 month abbrev (Jan-first)

    public function initialize() {
        WatchFace.initialize();
    }

    public function onLayout(dc as Graphics.Dc) as Void {
        _layout = new Layout(dc);
        _curves.invalidate();
        loadFonts();
        applySettings();
    }

    //! Re-read settings when the face returns to the foreground — covers the
    //! on-device settings menu (which writes properties directly and may not
    //! trigger AppBase.onSettingsChanged).
    public function onShow() as Void {
        applySettings();
        startBlink();
    }

    public function onHide() as Void {
        stopBlink();
    }

    //! Cache the custom fonts once. Guarded: a font that fails to load falls
    //! back to a built-in, so the face never breaks.
    private function loadFonts() as Void {
        _fonts = [
            loadFont($.Rez.Fonts.NeonTime, Graphics.FONT_NUMBER_MEDIUM),
            loadFont($.Rez.Fonts.NeonDate, Graphics.FONT_XTINY),
            loadFont($.Rez.Fonts.NeonCap, Graphics.FONT_XTINY),
            loadFont($.Rez.Fonts.NeonVal, Graphics.FONT_TINY)
        ];
    }

    private function loadFont(id as ResourceId, fallback as Graphics.FontType) as Graphics.FontType {
        try {
            return WatchUi.loadResource(id) as WatchUi.FontResource;
        } catch (e) {
            return fallback;
        }
    }

    //! Re-read the user settings and re-cache every localized string for the
    //! effective language. Cheap and infrequent (layout / show / settings
    //! change) — never called from the hot path.
    public function applySettings() as Void {
        _indicators = SettingsMenu.getNum("curveMode", 0) == 0;
        _metricL = SettingsMenu.getNum("leftMetric", Metrics.ACTIVE);
        _metricR = SettingsMenu.getNum("rightMetric", Metrics.BATTERY);
        var palette = SettingsMenu.getNum("palette", 0);
        _colL = Theme.curveColor(palette, 0);
        _colR = Theme.curveColor(palette, 1);
        _blink = SettingsMenu.getBool("blink", true);
        if (!_blink) {
            stopBlink();
        }
        var ru = effectiveRu(SettingsMenu.getNum("langMode", 0));

        _caps = loadList(ru
            ? [$.Rez.Strings.capStepsRu, $.Rez.Strings.capActiveRu, $.Rez.Strings.capBatteryRu]
            : [$.Rez.Strings.capSteps, $.Rez.Strings.capActive, $.Rez.Strings.capBattery]);

        _dow = loadList(ru
            ? [$.Rez.Strings.dow0Ru, $.Rez.Strings.dow1Ru, $.Rez.Strings.dow2Ru, $.Rez.Strings.dow3Ru,
               $.Rez.Strings.dow4Ru, $.Rez.Strings.dow5Ru, $.Rez.Strings.dow6Ru]
            : [$.Rez.Strings.dow0, $.Rez.Strings.dow1, $.Rez.Strings.dow2, $.Rez.Strings.dow3,
               $.Rez.Strings.dow4, $.Rez.Strings.dow5, $.Rez.Strings.dow6]);

        _mon = loadList(ru
            ? [$.Rez.Strings.mon0Ru, $.Rez.Strings.mon1Ru, $.Rez.Strings.mon2Ru, $.Rez.Strings.mon3Ru,
               $.Rez.Strings.mon4Ru, $.Rez.Strings.mon5Ru, $.Rez.Strings.mon6Ru, $.Rez.Strings.mon7Ru,
               $.Rez.Strings.mon8Ru, $.Rez.Strings.mon9Ru, $.Rez.Strings.mon10Ru, $.Rez.Strings.mon11Ru]
            : [$.Rez.Strings.mon0, $.Rez.Strings.mon1, $.Rez.Strings.mon2, $.Rez.Strings.mon3,
               $.Rez.Strings.mon4, $.Rez.Strings.mon5, $.Rez.Strings.mon6, $.Rez.Strings.mon7,
               $.Rez.Strings.mon8, $.Rez.Strings.mon9, $.Rez.Strings.mon10, $.Rez.Strings.mon11]);
    }

    //! Effective "use Russian?": langMode 1=EN, 2=RU, 0=Auto (follow system).
    private function effectiveRu(langMode as Number) as Boolean {
        if (langMode == 1) { return false; }
        if (langMode == 2) { return true; }
        return System.getDeviceSettings().systemLanguage == System.LANGUAGE_RUS;
    }

    //! Load a list of string resources into a String array.
    private function loadList(ids as Array<ResourceId>) as Array<String> {
        var out = [] as Array<String>;
        for (var i = 0; i < ids.size(); i += 1) {
            out.add(WatchUi.loadResource(ids[i]) as String);
        }
        return out;
    }

    public function onSettingsChanged() as Void {
        applySettings();
        WatchUi.requestUpdate();
    }

    public function onUpdate(dc as Graphics.Dc) as Void {
        var layout = _layout;
        if (layout == null) {
            return;
        }
        var data = buildData();
        if (_isAwake) {
            FaceRenderer.draw(dc, layout, data, _curves, _fonts, _colL, _colR,
                              _indicators, _dimDots);
        } else {
            AodRenderer.draw(dc, layout, data, _fonts, _indicators);
        }
    }

    //! Gather everything the renderers need into one FaceData.
    private function buildData() as FaceData {
        var d = new FaceData();
        var clock = System.getClockTime();
        d.minute = clock.min;

        // Time (honor the user's 12/24h preference)
        var hour = clock.hour;
        if (!System.getDeviceSettings().is24Hour) {
            hour = hour % 12;
            if (hour == 0) {
                hour = 12;
            }
        }
        d.timeText = hour.format("%02d") + ":" + clock.min.format("%02d");

        // Date — FORMAT_SHORT yields numeric day_of_week (1=Sun..7=Sat) and
        // month (1..12); index our own tables so the names follow the chosen
        // Language setting, not the device system locale.
        var greg = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var dowNum = greg.day_of_week as Number;
        var monNum = greg.month as Number;
        var dowStr = (dowNum >= 1 and dowNum <= _dow.size()) ? _dow[dowNum - 1] : "";
        var monStr = (monNum >= 1 and monNum <= _mon.size()) ? _mon[monNum - 1] : "";
        d.dateText = dowStr + " · " + (greg.day as Number).format("%d") + " " + monStr;

        if (_indicators) {
            var am = ActivityMonitor.getInfo();
            var pl = Metrics.percent(_metricL, am);
            var pr = Metrics.percent(_metricR, am);
            d.pctL = clamp(pl);
            d.pctR = clamp(pr);
            d.valL = ((pl > 999) ? 999 : pl).format("%d") + "%";
            d.valR = ((pr > 999) ? 999 : pr).format("%d") + "%";
            d.capL = caption(_metricL);
            d.capR = caption(_metricR);
        } else {
            d.pctL = 100;
            d.pctR = 100;
        }
        return d;
    }

    private function clamp(pct as Number) as Number {
        if (pct < 0) { return 0; }
        return (pct > 100) ? 100 : pct;
    }

    private function caption(metric as Number) as String {
        return (metric >= 0 and metric < _caps.size()) ? _caps[metric] : "";
    }

    public function onEnterSleep() as Void {
        _isAwake = false;
        stopBlink();
        WatchUi.requestUpdate();
    }

    public function onExitSleep() as Void {
        _isAwake = true;
        startBlink();
        WatchUi.requestUpdate();
    }

    //! Start a short blink run (high-power only). Restarting resets the count.
    private function startBlink() as Void {
        if (!_blink or !_isAwake) {
            return;
        }
        var timer = _timer;
        if (timer == null) {
            timer = new Timer.Timer();
            _timer = timer;
        }
        timer.stop();
        _blinkTicks = 0;
        _dimDots = false;
        timer.start(method(:onBlink), BLINK_MS, true);
    }

    private function stopBlink() as Void {
        var timer = _timer;
        if (timer != null) {
            timer.stop();
        }
        _dimDots = false;
    }

    public function onBlink() as Void {
        _blinkTicks += 1;
        _dimDots = !_dimDots;
        if (_blinkTicks >= BLINK_TICKS) {
            stopBlink();
        }
        WatchUi.requestUpdate();
    }

    //! Called by the delegate if the per-second power budget is exceeded.
    public function disablePartialUpdates() as Void {
        // No onPartialUpdate path; reserved in case seconds are ever added.
    }
}
