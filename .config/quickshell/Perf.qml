pragma Singleton

import QtQuick
import Quickshell

// Bench instrumentation, read by ~/.config/quickshell/bench/run. Off unless `qs ipc call perf enable`
// (IpcHandler "perf" in shell.qml); while off every call is one bool check. Output goes to the
// Quickshell log as single lines "[perf] <kind> key=value ...":
//   [perf] enabled
//   [perf] open name=<dropdown> loaded=<ms> frame=<ms>      shown -> Loader loaded -> first frame swapped
//   [perf] data name=<cpu|memory|disk> ms=<ms>              dropdown opened -> first fresh data
//   [perf] fetch name=<procs|disk> spawn=<ms> parse=<ms>    process start -> output, then JS handling
//   [perf] counters {"frames:bar:<screen>": n, "frames:dropdown:<name>": n, ...}   on report()
Singleton {
    id: root

    property bool enabled: false
    property var _marks: ({})
    property var counters: ({})

    // interval `key` starts now
    function begin(key) {
        if (enabled)
            _marks[key] = Date.now();
    }

    function has(key) {
        return enabled && _marks[key] !== undefined;
    }

    // ms since begin(key), -1 if there is none
    function since(key) {
        return has(key) ? Date.now() - _marks[key] : -1;
    }

    function clear(key) {
        delete _marks[key];
    }

    // emit("open", {name: "cpu", loaded: 12, frame: 30}) -> "[perf] open name=cpu loaded=12 frame=30"
    function emit(kind, fields) {
        if (!enabled)
            return;
        console.info("[perf] " + kind + Object.keys(fields ?? {}).map(k => " " + k + "=" + fields[k]).join(""));
    }

    function count(key) {
        if (enabled)
            counters[key] = (counters[key] ?? 0) + 1;
    }

    // log the counters collected since the last report, then start over
    function report() {
        console.info("[perf] counters " + JSON.stringify(counters));
        counters = {};
    }

    function setEnabled(on) {
        enabled = on;
        _marks = {};
        counters = {};
        if (on)
            console.info("[perf] enabled");
    }
}
