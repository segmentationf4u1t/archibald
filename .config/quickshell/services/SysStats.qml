pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// CPU / memory / GPU / network sampling. Cheap reads of /proc every `interval`;
// expensive extras (top processes, per-core clocks) run only while a popup asks for them
// via cpuDetailUsers / memDetailUsers (increment on open, decrement on close).
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
    // [{index, name, util, memUsed, memTotal, temp, power, powerLimit, fan}] (MiB, °C, W, %; NaN = n/a)
    property var gpus: []
    property var gpuHistory: ({})                     // index -> [util...]
    readonly property real gpu: gpus.reduce((m, g) => Math.max(m, g.util || 0), 0)

    // ---- network ----
    property string netIface: ""
    property real netRx: 0                            // bytes/s
    property real netTx: 0
    property var netRxHistory: []
    property var netTxHistory: []

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
            if (tempFile.path !== "")
                tempFile.reload();
            if (root.cpuDetailUsers > 0) {
                cpuinfo.reload();
                if (!topCpuProc.running)
                    topCpuProc.running = true;
            }
            if (root.memDetailUsers > 0 && !topMemProc.running)
                topMemProc.running = true;
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

    // One long-running nvidia-smi streams a line per GPU every interval (no respawning).
    Process {
        running: true
        command: ["nvidia-smi", "--query-gpu=index,name,utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw,power.limit,fan.speed", "--format=csv,noheader,nounits", "-lms", String(root.interval)]
        stdout: SplitParser {
            onRead: line => {
                const f = line.split(",").map(s => s.trim());
                if (f.length < 9)
                    return;
                const num = s => {
                    const v = parseFloat(s);
                    return isNaN(v) ? NaN : v;
                };
                const g = {
                    index: Number(f[0]),
                    name: f[1].replace(/^NVIDIA /, ""),
                    util: num(f[2]),
                    memUsed: num(f[3]),
                    memTotal: num(f[4]),
                    temp: num(f[5]),
                    power: num(f[6]),
                    powerLimit: num(f[7]),
                    fan: num(f[8])
                };
                const list = root.gpus.filter(x => x.index !== g.index);
                list.push(g);
                list.sort((a, b) => a.index - b.index);
                root.gpus = list;
                const hist = Object.assign({}, root.gpuHistory);
                hist[g.index] = root.push(hist[g.index] || [], isNaN(g.util) ? 0 : g.util);
                root.gpuHistory = hist;
            }
        }
    }

    // ---- detail-only sampling ----
    // top's second iteration gives the current (not lifetime-average) per-process CPU.
    Process {
        id: topCpuProc
        command: ["sh", "-c", "top -b -n 2 -d 1 -w 512 -o %CPU | awk '/^ *PID /{n++; next} n==2 && NF>=12 && c<6 {cmd=$12; for(i=13;i<=NF;i++) cmd=cmd\" \"$i; print $1\"\\t\"$9\"\\t\"cmd; c++}'"]
        stdout: StdioCollector {
            onStreamFinished: root.topCpu = text.trim().split("\n").filter(l => l !== "").map(l => {
                const f = l.split("\t");
                return { pid: Number(f[0]), cpu: Number(f[1].replace(",", ".")), name: f[2] };
            })
        }
    }

    Process {
        id: topMemProc
        command: ["sh", "-c", "ps -eo pid=,rss=,comm= --sort=-rss | head -n 6"]
        stdout: StdioCollector {
            onStreamFinished: root.topMem = text.trim().split("\n").filter(l => l !== "").map(l => {
                const m = l.trim().match(/^(\d+)\s+(\d+)\s+(.*)$/);
                return m ? { pid: Number(m[1]), rss: Number(m[2]) * 1024, name: m[3] } : null;
            }).filter(x => x !== null)
        }
    }
}
