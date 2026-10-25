import Toybox.ActivityMonitor;
import Toybox.Lang;
import Toybox.System;

//! What a curve can indicate. Index order matches the `leftMetric` /
//! `rightMetric` settings (settings.xml, properties.xml, SettingsMenu).
module Metrics {
    const STEPS   = 0;  // steps toward the daily step goal
    const ACTIVE  = 1;  // active (intensity) minutes today toward 1/7 of the weekly goal
    const BATTERY = 2;  // battery charge
    const COUNT   = 3;

    // Garmin's default weekly intensity-minutes goal, used when the device
    // reports none.
    const DEFAULT_WEEK_GOAL = 150;

    //! Raw percent (may exceed 100 once a goal is beaten) for `metric`.
    function percent(metric as Number, am as ActivityMonitor.Info?) as Number {
        if (metric == BATTERY) {
            return System.getSystemStats().battery.toNumber();
        }
        if (am == null) {
            return 0;
        }
        if (metric == ACTIVE) {
            var day = am.activeMinutesDay;
            var total = (day != null) ? day.total : null;
            var goal = am.activeMinutesWeekGoal;
            if (goal == null or goal <= 0) {
                goal = DEFAULT_WEEK_GOAL;
            }
            return (total != null) ? (total * 700) / goal : 0;
        }
        var steps = am.steps;
        var stepGoal = am.stepGoal;
        if (steps == null or stepGoal == null or stepGoal <= 0) {
            return 0;
        }
        return (steps * 100) / stepGoal;
    }
}
