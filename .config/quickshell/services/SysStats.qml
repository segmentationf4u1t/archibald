pragma Singleton

import QtQuick
import Quickshell
import qs
import Quickshell.Io

// CPU / memory / GPU / network / disk sampling. Cheap reads of /proc every `interval`;
// extras (top processes, per-core clocks, disk temperatures, df, the full nvidia-smi query) run only
// while a popup asks for them via cpuDetailUsers / memDetailUsers / diskDetailUsers / gpuDetailUsers
// (increment on open, decrement on close), and start the moment it opens instead of waiting for the next tick.
Singleton {
    id: root

    readonly property int interval: 2000
    readonly property int historyLength: 60          // 60 x 2 s = 2 min
    // full-screen monitor behind the CPU/memory dropdown footers: btop, else htop, else top
    readonly property var monitorCommand: ["kitty", "-e", "sh", "-c",
        "if command -v btop >/dev/null 2>&1; then exec btop; elif command -v htop >/dev/null 2>&1; then exec htop; else exec top; fi"]

    // ---- CPU ----
    property real cpu: 0                              // % of all threads
    property var cpuHistory: []
    property var cores: []                            // % per logical CPU
    property real cpuTemp: -1                         // °C (coretemp package), -1 = unknown
    property var cpuTempHistory: []
    property real cpuFreqAvg: 0                       // MHz, only while cpuDetailUsers > 0
    property real cpuFreqMax: 0
    property var loadAvg: [0, 0, 0]
    property real uptime: 0                           // seconds
    property var topCpu: []                           // [{pid, name, cpu}], cpu in % of one thread (like top)
    property int cpuDetailUsers: 0
    readonly property string cpuModel: _cpuModel      // "Intel Core i7-12700K": parsed once from /proc/cpuinfo
    property string _cpuModel: ""

    // ---- memory (bytes) ----
    property real memTotal: 0
    property real memUsed: 0                          // total - available
    property real memAvailable: 0
    property real memCached: 0                        // page cache + reclaimable slab - shmem
    property real memBuffers: 0
    property real swapTotal: 0
    property real swapUsed: 0
    readonly property real mem: memTotal > 0 ? 100 * memUsed / memTotal : 0
    property var memHistory: []
    property var topMem: []                           // [{pid, name, rss}], rss in bytes
    property int memDetailUsers: 0

    // ---- GPU (nvidia-smi) ----
    // [{index, name, util, memUsed, memTotal, temp, power, powerLimit, fan}] (MiB, °C, W, %; NaN = n/a).
    // Only index/util are live while no GPU popup is open (gpuDetailUsers == 0); the rest is NaN / "".
    property var gpus: []
    property var gpuHistory: ({})                     // index -> [util...]
    readonly property real gpu: gpus.reduce((m, g) => Math.max(m, g.util || 0), 0)
    property int gpuDetailUsers: 0

    // Stream rows land in these plain objects (mutated in place, nothing binds to them) and are published
    // to gpus / gpuHistory by the Timer tick, so one tick = one repaint however the streams' phases drift.
    property var _gpuUtil: ({})                       // index -> util
    property var _gpuDetail: ({})                     // index -> {memUsed, memTotal, temp, power, powerLimit, fan}, detail stream only
    property var _gpuNames: ({})                      // index -> name (static, kept after the detail stream stops)
    property bool _gpuDirty: false                    // a row arrived since the last tick publish
    property bool _gpuDetailPending: false            // popup just opened: publish rows right away until all GPUs have details

    onGpuDetailUsersChanged: {
        const on = gpuDetailUsers > 0;
        if (on === gpuDetailStream.wanted)
            return;
        gpuDetailStream.wanted = on;
        _gpuDetailPending = on;
        if (!on) {
            _gpuDetail = {};
            _gpuDirty = true;   // next tick publishes the details gone
        }
        _syncGpuStreams();
    }

    // start / stop each stream to match `wanted`
    function _syncGpuStreams() {
        for (const s of [gpuUtilStream, gpuDetailStream])
            s.running = s.wanted;
    }

    // build gpus (and, once per tick, the history) from the plain rows
    function _publishGpus(pushHistory) {
        const idx = Object.keys(_gpuUtil).map(Number).sort((a, b) => a - b);
        if (idx.length === 0)
            return;
        const hist = pushHistory ? Object.assign({}, gpuHistory) : null;
        gpus = idx.map(i => {
            const d = _gpuDetail[i];
            const util = _gpuUtil[i];
            if (hist)
                hist[i] = push(hist[i] || [], isNaN(util) ? 0 : util);
            return {
                index: i,
                name: _gpuNames[i] || "",
                util: util,
                memUsed: d ? d.memUsed : NaN,
                memTotal: d ? d.memTotal : NaN,
                temp: d ? d.temp : NaN,
                power: d ? d.power : NaN,
                powerLimit: d ? d.powerLimit : NaN,
                fan: d ? d.fan : NaN
            };
        });
        if (hist)
            gpuHistory = hist;
    }

    function _onGpuLine(line, detail) {
        const f = line.split(",");
        if (f.length < (detail ? 9 : 2))
            return;
        const index = Number(f[0]);
        _gpuUtil[index] = parseFloat(f[detail ? 2 : 1]);
        _gpuDirty = true;
        if (!detail)
            return;
        if (gpuDetailUsers === 0)
            return;   // late row from a stream that is shutting down
        _gpuNames[index] = f[1].trim().replace(/^NVIDIA /, "");
        _gpuDetail[index] = {
            memUsed: parseFloat(f[3]),
            memTotal: parseFloat(f[4]),
            temp: parseFloat(f[5]),
            power: parseFloat(f[6]),
            powerLimit: parseFloat(f[7]),
            fan: parseFloat(f[8])
        };
        if (_gpuDetailPending) {
            _publishGpus(false);   // first view of the popup is not empty
            if (Object.keys(_gpuDetail).length >= Object.keys(_gpuUtil).length)
                _gpuDetailPending = false;
        }
    }

    // ---- network ----
    property string netIface: ""
    property real netRx: 0                            // bytes/s
    property real netTx: 0
    property var netRxHistory: []
    property var netTxHistory: []

    // ---- disks (/proc/diskstats, whole physical disks) ----
    // [{name, model, size, read, write, util, readTotal, writtenTotal}]: bytes, bytes/s, % of time busy;
    // totals count since boot
    property var disks: []
    property var diskReadHistory: ({})                // name -> [bytes/s...]
    property var diskWriteHistory: ({})
    readonly property real diskUtil: disks.reduce((m, d) => Math.max(m, d.util), 0)   // busiest disk
    readonly property real diskRead: disks.reduce((s, d) => s + d.read, 0)
    readonly property real diskWrite: disks.reduce((s, d) => s + d.write, 0)
    property var diskTemps: ({})                      // name -> °C, only while diskDetailUsers > 0
    property var filesystems: []                      // [{source, fstype, size, used, avail, target}], ditto
    property int diskDetailUsers: 0

    onDiskDetailUsersChanged: {
        const opened = diskDetailUsers > 0 && _diskUsersSeen === 0;   // 0 -> 1: dropdown just opened
        if (opened)
            Perf.begin("data:disk");
        _diskUsersSeen = diskDetailUsers;
        if (!opened)
            return;
        sampleDisk();
        if (_diskTempPaths === null)
            diskTempFind.running = true;
        else
            _readDiskTemps();
    }

    // run df unless one is already in flight (on open, then every 15 s while open)
    function sampleDisk() {
        if (!diskDetailProc.running) {
            Perf.begin("fetch:disk");
            diskDetailProc.running = true;
        }
    }

    // temp1_input files of the disks ([{name, path}]), discovered on first open; null = not yet
    property var _diskTempPaths: null
    property var _diskTempVals: ({})
    property int _diskTempPending: 0                  // files still to answer in this read round

    // reload every temperature file; the last answer publishes diskTemps once
    function _readDiskTemps() {
        const n = diskTempFiles.count;
        if (n === 0)
            return;
        _diskTempPending = n;
        for (let i = 0; i < n; i++)
            diskTempFiles.objectAt(i).reload();
    }

    function _diskTempLoaded(name, content) {
        const v = Number(content) / 1000;
        if (content !== "" && !isNaN(v))
            _diskTempVals[name] = v;
        if (_diskTempPending > 0 && --_diskTempPending === 0)
            diskTemps = Object.assign({}, _diskTempVals);
    }

    // previous *DetailUsers values: the changed handlers fire on every change, the data marks need 0 -> 1
    property int _cpuUsersSeen: 0
    property int _memUsersSeen: 0
    property int _diskUsersSeen: 0

    onCpuDetailUsersChanged: {
        if (cpuDetailUsers > 0 && _cpuUsersSeen === 0)
            Perf.begin("data:cpu");
        _cpuUsersSeen = cpuDetailUsers;
        if (cpuDetailUsers > 0) {
            cpuinfo.reload();
            sampleProcs();
        }
    }
    onMemDetailUsersChanged: {
        if (memDetailUsers > 0 && _memUsersSeen === 0)
            Perf.begin("data:memory");
        _memUsersSeen = memDetailUsers;
        if (memDetailUsers > 0)
            sampleProcs();
    }

    function push(history, value) {
        const next = history.slice(-(historyLength - 1));
        next.push(value);
        return next;
    }

    function formatBytes(bytes) {
        const units = ["B", "KiB", "MiB", "GiB", "TiB"];
        let v = bytes;
        let i = 0;
        while (v >= 1024 && i < units.length - 1) {
            v /= 1024;
            i++;
        }
        return (i === 0 ? v.toFixed(0) : v.toFixed(v < 10 ? 1 : 0)) + " " + units[i];
    }

    function formatRate(bytesPerSec) {
        return formatBytes(bytesPerSec) + "/s";
    }

    // ---------------------------------------------------------------- sampling
    property var _prevStat: []
    property var _prevNet: null
    property var _prevDisk: ({})                      // name -> {rd, wr, busy, t}
    property var _diskInfo: ({})                      // name -> {model, size} from lsblk
    readonly property var _wholeDisk: /^(nvme\d+n\d+|sd[a-z]+|vd[a-z]+|xvd[a-z]+|mmcblk\d+)$/

    Timer {
        interval: root.interval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            stat.reload();
            meminfo.reload();
            loadavg.reload();
            uptimeFile.reload();
            route.reload();
            diskstats.reload();
            if (tempFile.path !== "")
                tempFile.reload();
            if (root.cpuDetailUsers > 0)
                cpuinfo.reload();
            if (root.cpuDetailUsers > 0 || root.memDetailUsers > 0)
                root.sampleProcs();
            if (root.diskDetailUsers > 0)
                root._readDiskTemps();
            if (root._gpuDirty) {
                root._gpuDirty = false;
                root._publishGpus(true);
            }
        }
    }

    FileView {
        id: stat
        path: "/proc/stat"
        onLoaded: {
            const prev = root._prevStat;
            const next = [];
            const cores = [];
            let total = 0;
            for (const line of text().split("\n")) {
                if (!line.startsWith("cpu"))
                    break;
                const f = line.trim().split(/\s+/).slice(1, 9).map(Number);
                const idle = f[3] + f[4];
                const sum = f.reduce((a, b) => a + b, 0);
                const p = prev[next.length];
                let usage = 0;
                if (p && sum > p[1])
                    usage = 100 * (1 - (idle - p[0]) / (sum - p[1]));
                if (next.length === 0)
                    total = usage;
                else
                    cores.push(usage);
                next.push([idle, sum]);
            }
            root._prevStat = next;
            if (prev.length === 0)
                return;   // the first read has nothing to diff against
            root.cpu = total;
            root.cores = cores;
            root.cpuHistory = root.push(root.cpuHistory, total);
        }
    }

    FileView {
        id: meminfo
        path: "/proc/meminfo"
        onLoaded: {
            const kv = {};
            for (const line of text().split("\n")) {
                const m = line.match(/^(\w+):\s+(\d+)/);
                if (m)
                    kv[m[1]] = Number(m[2]) * 1024;
            }
            root.memTotal = kv.MemTotal || 0;
            root.memAvailable = kv.MemAvailable || 0;
            root.memUsed = root.memTotal - root.memAvailable;
            root.memBuffers = kv.Buffers || 0;
            root.memCached = (kv.Cached || 0) + (kv.SReclaimable || 0) - (kv.Shmem || 0);
            root.swapTotal = kv.SwapTotal || 0;
            root.swapUsed = root.swapTotal - (kv.SwapFree || 0);
            root.memHistory = root.push(root.memHistory, root.mem);
        }
    }

    FileView {
        id: loadavg
        path: "/proc/loadavg"
        onLoaded: root.loadAvg = text().trim().split(/\s+/).slice(0, 3).map(Number)
    }

    FileView {
        id: uptimeFile
        path: "/proc/uptime"
        onLoaded: root.uptime = Number(text().split(" ")[0])
    }

    FileView {
        id: cpuinfo
        path: "/proc/cpuinfo"
        onLoaded: {
            const re = /^cpu MHz\s*:\s*([\d.]+)/gm;
            const content = text();
            const mhz = [];
            let m;
            while ((m = re.exec(content)) !== null)
                mhz.push(Number(m[1]));
            if (mhz.length === 0)
                return;
            root.cpuFreqAvg = mhz.reduce((a, b) => a + b, 0) / mhz.length;
            root.cpuFreqMax = Math.max(...mhz);
        }
    }

    // CPU model name, read once and released (the popup used to load /proc/cpuinfo itself)
    FileView {
        id: cpuModelFile
        path: "/proc/cpuinfo"
        onLoaded: {
            const m = /^model name\s*:\s*(.+)$/m.exec(text());
            root._cpuModel = m ? m[1].replace(/\((R|TM)\)/g, "").replace(/\s+CPU\b.*$/, "").replace(/\s+/g, " ").trim() : "";
            path = "";
        }
    }

    // coretemp's hwmon index changes between boots: resolve it once by name.
    Process {
        running: true
        command: ["sh", "-c", "for h in /sys/class/hwmon/hwmon*; do [ \"$(cat \"$h/name\")\" = coretemp ] && echo \"$h\" && break; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const dir = text.trim();
                if (dir !== "")
                    tempFile.path = dir + "/temp1_input";
            }
        }
    }

    FileView {
        id: tempFile
        path: ""
        onLoaded: {
            root.cpuTemp = Number(text()) / 1000;
            root.cpuTempHistory = root.push(root.cpuTempHistory, root.cpuTemp);
        }
    }

    // default route interface, then its counters
    FileView {
        id: route
        path: "/proc/net/route"
        onLoaded: {
            let iface = "";
            for (const line of text().split("\n").slice(1)) {
                const f = line.trim().split(/\s+/);
                if (f[1] === "00000000") {
                    iface = f[0];
                    break;
                }
            }
            if (iface !== root.netIface) {
                root.netIface = iface;
                root._prevNet = null;
            }
            if (iface !== "")
                netdev.reload();
        }
    }

    FileView {
        id: netdev
        path: "/proc/net/dev"
        onLoaded: {
            const line = text().split("\n").find(l => l.trim().startsWith(root.netIface + ":"));
            if (!line)
                return;
            const f = line.split(":")[1].trim().split(/\s+/).map(Number);
            const now = Date.now();
            const cur = { rx: f[0], tx: f[8], t: now };
            const prev = root._prevNet;
            root._prevNet = cur;
            if (!prev || now <= prev.t)
                return;
            const dt = (now - prev.t) / 1000;
            root.netRx = Math.max(0, (cur.rx - prev.rx) / dt);
            root.netTx = Math.max(0, (cur.tx - prev.tx) / dt);
            root.netRxHistory = root.push(root.netRxHistory, root.netRx);
            root.netTxHistory = root.push(root.netTxHistory, root.netTx);
        }
    }

    FileView {
        id: diskstats
        path: "/proc/diskstats"
        onLoaded: {
            const now = Date.now();
            const prev = root._prevDisk;
            const next = {};
            const list = [];
            let fresh = false;
            for (const line of text().split("\n")) {
                // major minor name | reads merged sectors ms | writes merged sectors ms | in-flight io_ticks ...
                const f = line.trim().split(/\s+/);
                if (f.length < 14 || !root._wholeDisk.test(f[2]))
                    continue;
                const name = f[2];
                const cur = { rd: Number(f[5]) * 512, wr: Number(f[9]) * 512, busy: Number(f[12]), t: now };
                next[name] = cur;
                const info = root._diskInfo[name];
                if (info && info.size === 0)
                    continue;   // empty card-reader slot
                const p = prev[name];
                const dt = p && now > p.t ? now - p.t : 0;
                fresh = fresh || dt > 0;
                list.push({
                    name: name,
                    model: info ? info.model : "",
                    size: info ? info.size : 0,
                    read: dt ? Math.max(0, (cur.rd - p.rd) * 1000 / dt) : 0,
                    write: dt ? Math.max(0, (cur.wr - p.wr) * 1000 / dt) : 0,
                    util: dt ? Math.min(100, Math.max(0, 100 * (cur.busy - p.busy) / dt)) : 0,
                    readTotal: cur.rd,
                    writtenTotal: cur.wr
                });
            }
            // disk plugged in / removed (or first read): refresh models and sizes
            if (Object.keys(next).sort().join(" ") !== Object.keys(prev).sort().join(" "))
                lsblkProc.running = true;
            root._prevDisk = next;
            list.sort((a, b) => a.name.localeCompare(b.name));
            root.disks = list;
            if (!fresh)
                return;   // the first read has nothing to diff against
            const rh = {};
            const wh = {};
            for (const d of list) {
                rh[d.name] = root.push(root.diskReadHistory[d.name] || [], d.read);
                wh[d.name] = root.push(root.diskWriteHistory[d.name] || [], d.write);
            }
            root.diskReadHistory = rh;
            root.diskWriteHistory = wh;
        }
    }

    Process {
        id: lsblkProc
        command: ["lsblk", "-J", "-d", "-b", "-o", "NAME,MODEL,SIZE"]
        stdout: StdioCollector {
            onStreamFinished: {
                const info = {};
                try {
                    for (const d of JSON.parse(text).blockdevices)
                        info[d.name] = { model: (d.model || "").trim(), size: Number(d.size) || 0 };
                } catch (e) {
                    return;
                }
                root._diskInfo = info;
            }
        }
    }

    // Two long-running nvidia-smi streams (no respawning): index+util always, the full query only while a
    // GPU popup is open. A stream that dies is restarted after 5 s instead of freezing the value.
    Process {
        id: gpuUtilStream
        property bool wanted: true
        command: ["nvidia-smi", "--query-gpu=index,utilization.gpu", "--format=csv,noheader,nounits", "-lms", String(root.interval)]
        stdout: SplitParser {
            onRead: line => root._onGpuLine(line, false)
        }
        onExited: if (wanted) gpuRetry.restart()
        Component.onCompleted: root._syncGpuStreams()
    }

    Process {
        id: gpuDetailStream
        property bool wanted: false
        command: ["nvidia-smi", "--query-gpu=index,name,utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw,power.limit,fan.speed", "--format=csv,noheader,nounits", "-lms", String(root.interval)]
        stdout: SplitParser {
            onRead: line => root._onGpuLine(line, true)
        }
        onExited: if (wanted) gpuRetry.restart()
    }

    Timer {
        id: gpuRetry
        interval: 5000
        onTriggered: root._syncGpuStreams()
    }

    // ---- top processes (CPU and memory dropdowns) ----
    // One `cat` of /proc/uptime and every /proc/<pid>/stat (~10 ms for ~600 processes) instead of
    // `top -n 2 -d 1` (two full scans, 1.2 s) and `ps`. CPU % is the utime+stime delta between two
    // samples, so the first list needs a previous sample: hovering the bar module takes one (warmProcs),
    // otherwise a second sample follows 250 ms after the first. Memory is RSS of a single sample.
    property int _clkTck: 100                         // USER_HZ, confirmed by getconf below
    property int _pageSize: 4096
    property var _procPrev: null                      // {uptime, at, ticks: {pid: utime + stime}, starts: {pid: starttime}}

    function sampleProcs() {
        if (!procSampler.running) {
            Perf.begin("fetch:procs");
            procSampler.running = true;
        }
    }

    // forget the previous process sample (bench IPC `perf cold`)
    function resetProcs() { _procPrev = null; }

    // bar module hovered: take the first sample so the CPU list is ready when the dropdown opens
    function warmProcs() {
        if (!_procPrev || Date.now() - _procPrev.at > 1000)
            sampleProcs();
    }

    // The first sample line is /proc/uptime; the rest are /proc/<pid>/stat lines. Walk them with indexOf
    // (no split / per-line arrays): "pid (comm) state ..." where comm may contain spaces and parentheses.
    // Wanted fields: 14 utime, 15 stime, 22 starttime, 24 rss (pages), counted from the state at field 3.
    function _onProcSample(text) {
        const uptime = parseFloat(text);
        const ticks = {};
        const starts = {};
        const procs = [];
        const end = text.length;
        let pos = text.indexOf("\n") + 1;
        while (pos > 0 && pos < end) {
            let eol = text.indexOf("\n", pos);
            if (eol < 0)
                eol = end;
            const open = text.indexOf(" (", pos);
            const close = text.lastIndexOf(") ", eol - 1);
            if (eol > pos && open > 0 && open < eol && close > open) {
                let utime = 0, stime = 0, start = 0, rss = 0;
                let p = close + 2;
                for (let field = 3; field <= 24 && p < eol; field++) {
                    let sp = text.indexOf(" ", p);
                    if (sp < 0 || sp > eol)
                        sp = eol;
                    if (field === 14)
                        utime = Number(text.substring(p, sp));
                    else if (field === 15)
                        stime = Number(text.substring(p, sp));
                    else if (field === 22)
                        start = Number(text.substring(p, sp));
                    else if (field === 24)
                        rss = Number(text.substring(p, sp));
                    p = sp + 1;
                }
                const pid = Number(text.substring(pos, open));
                ticks[pid] = utime + stime;
                starts[pid] = start;
                // the name is cut out only for the few rows that make a top list
                procs.push({ pid: pid, ns: open + 2, ne: close, start: start, ticks: utime + stime, rss: rss * root._pageSize, cpu: 0 });
            }
            pos = eol + 1;
        }

        if (root.memDetailUsers > 0) {
            root.topMem = root._top6(procs, "rss").map(p => ({ pid: p.pid, name: text.substring(p.ns, p.ne), rss: p.rss }));
            if (Perf.has("data:memory")) {
                Perf.emit("data", { name: "memory", ms: Perf.since("data:memory") });
                Perf.clear("data:memory");
            }
        }

        const prev = root._procPrev;
        root._procPrev = { uptime: uptime, at: Date.now(), ticks: ticks, starts: starts };
        if (root.cpuDetailUsers === 0)
            return;
        const dt = prev ? uptime - prev.uptime : 0;
        if (dt < 0.1 || dt > 5) {   // no usable previous sample (none, too close, or stale)
            procResample.restart();
            return;
        }
        // a pid only matches its previous ticks when the start time agrees (pid reuse); deltas never go negative
        const known = [];
        for (const p of procs) {
            if (prev.ticks[p.pid] !== undefined && prev.starts[p.pid] === p.start) {
                p.cpu = 100 * Math.max(0, p.ticks - prev.ticks[p.pid]) / root._clkTck / dt;
                known.push(p);
            }
        }
        root.topCpu = root._top6(known, "cpu").map(p => ({ pid: p.pid, name: text.substring(p.ns, p.ne), cpu: p.cpu }));
        if (Perf.has("data:cpu")) {
            Perf.emit("data", { name: "cpu", ms: Perf.since("data:cpu") });
            Perf.clear("data:cpu");
        }
    }

    // the 6 entries with the largest `key`, descending (ties keep input order, like a stable sort)
    function _top6(list, key) {
        const top = [];
        for (const p of list) {
            const v = p[key];
            let i = top.length;
            if (i === 6) {
                if (v <= top[5][key])
                    continue;
                i = 5;
                top[5] = p;
            } else {
                top.push(p);
            }
            while (i > 0 && top[i - 1][key] < v) {
                top[i] = top[i - 1];
                top[i - 1] = p;
                i--;
            }
        }
        return top;
    }

    Process {
        id: procSampler
        command: ["sh", "-c", "cat /proc/uptime /proc/[0-9]*/stat 2>/dev/null"]   // a pid may vanish mid-glob
        stdout: StdioCollector {
            onStreamFinished: {
                const spawn = Perf.since("fetch:procs");   // process start -> output
                root._onProcSample(text);   // early returns inside must not skip the emit
                if (Perf.has("fetch:procs")) {
                    Perf.emit("fetch", { name: "procs", spawn: spawn, parse: Perf.since("fetch:procs") - spawn });
                    Perf.clear("fetch:procs");
                }
            }
        }
    }

    Timer {
        id: procResample
        interval: 250
        onTriggered: {
            if (root.cpuDetailUsers > 0)   // the popup may have closed meanwhile
                root.sampleProcs();
        }
    }

    Process {
        running: true
        command: ["sh", "-c", "getconf CLK_TCK; getconf PAGESIZE"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = text.trim().split(/\s+/).map(Number);
                if (v[0] > 0)
                    root._clkTck = v[0];
                if (v[1] > 0)
                    root._pageSize = v[1];
            }
        }
    }

    // Disk temperatures (NVMe hwmon / SATA drivetemp): find the files once, then FileViews read them each tick.
    Process {
        id: diskTempFind
        command: ["sh", "-c", `
            for b in /sys/block/*; do
                for f in "$b"/device/hwmon*/temp1_input "$b"/device/hwmon/hwmon*/temp1_input; do
                    [ -r "$f" ] && echo "\${b##*/} $f" && break
                done
            done`]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = [];
                for (const line of text.split("\n")) {
                    const sp = line.indexOf(" ");
                    if (sp > 0)
                        list.push({ name: line.slice(0, sp), path: line.slice(sp + 1) });
                }
                root._diskTempPaths = list;   // instantiates the FileViews below
                root._readDiskTemps();
            }
        }
    }

    Instantiator {
        id: diskTempFiles
        model: root._diskTempPaths ?? []
        delegate: FileView {
            required property var modelData
            path: modelData.path
            onLoaded: root._diskTempLoaded(modelData.name, text())
            onLoadFailed: root._diskTempLoaded(modelData.name, "")
        }
    }

    Timer {
        interval: 15000
        repeat: true
        running: root.diskDetailUsers > 0
        onTriggered: root.sampleDisk()
    }

    // Local filesystem usage: one df per sample.
    Process {
        id: diskDetailProc
        command: ["df", "-B1", "-l", "-x", "tmpfs", "-x", "devtmpfs", "-x", "efivarfs", "-x", "overlay", "-x", "squashfs", "-x", "ramfs",
            "--output=source,fstype,size,used,avail,target"]
        stdout: StdioCollector {
            onStreamFinished: {
                const spawn = Perf.since("fetch:disk");   // process start -> output
                const fs = [];
                const seen = new Set();
                const lines = text.split("\n");
                for (let i = 1; i < lines.length; i++) {   // line 0 is the header
                    const m = lines[i].match(/^(\S+)\s+(\S+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(.+)$/);
                    // one row per device (btrfs subvolumes mount the same one several times)
                    if (m && !seen.has(m[1])) {
                        seen.add(m[1]);
                        fs.push({ source: m[1], fstype: m[2], size: Number(m[3]), used: Number(m[4]), avail: Number(m[5]), target: m[6].trim() });
                    }
                }
                root.filesystems = fs;
                if (Perf.has("data:disk")) {
                    Perf.emit("data", { name: "disk", ms: Perf.since("data:disk") });
                    Perf.clear("data:disk");
                }
                if (Perf.has("fetch:disk")) {
                    Perf.emit("fetch", { name: "disk", spawn: spawn, parse: Perf.since("fetch:disk") - spawn });
                    Perf.clear("fetch:disk");
                }
            }
        }
    }
}
