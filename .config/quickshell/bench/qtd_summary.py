#!/usr/bin/env python3
"""Summarize a qmlprofiler .qtd trace (XML) from a Quickshell instance.

usage: qtd_summary.py trace.qtd [--top N] [--json] [--root CONFIG_DIR]

Prints markdown tables (default) or the same data as JSON (--json) so two
runs can be diffed.  Sections whose feature is missing from the trace are
simply omitted.  Times: all ms unless stated; the trace itself is in ns.

.qtd layout (Qt 6.12 "version 1.02"):
  <eventData>  <event index=N> type, filename, line, column, details, ...
  <profilerDataModel> <range startTime=ns [duration=ns] eventIndex=N attrs.../>
Duration ranges (Javascript, Binding, HandlingSignal, Creating, Compiling)
nest (Binding > Javascript > Javascript ...), so we also compute SELF time
with one stack over all of them.  SceneGraph / Pixmap / Memory ranges are
point events carrying numeric attributes instead of a duration.
"""
import argparse
import json
import os
import sys
import xml.etree.ElementTree as ET
from collections import defaultdict

DURATION_TYPES = ("Javascript", "Binding", "HandlingSignal", "Creating", "Compiling")

# sgEventType -> (label, names of timing1..timingN).  Mirrors Qt Creator's
# SceneGraphTimelineModel / QQuickProfiler::SceneGraphFrameType.  GUI-thread
# frames: PolishAndSync.  Render-thread frames: RenderLoopFrame.
SG_TYPES = {
    0: ("RendererFrame", ["preprocess", "update", "bind", "render"]),
    1: ("AdaptationLayer", ["glyph_render", "glyph_store"]),
    2: ("ContextFrame", ["material_compile"]),
    3: ("RenderLoopFrame (render thread)", ["sync", "render", "swap"]),
    4: ("TexturePrepare", ["bind", "convert", "swizzle", "upload", "mipmap"]),
    5: ("TextureDeletion", ["delete"]),
    6: ("PolishAndSync (GUI thread)", ["polish", "wait", "sync", "animations"]),
    7: ("WindowsRenderLoopFrame", ["t1", "t2", "t3"]),
    8: ("WindowsAnimations", ["animations"]),
    9: ("PolishFrame", ["polish"]),
}
MEM_TYPES = {0: "HeapPage", 1: "LargeItem", 2: "SmallItem"}


# ---------------------------------------------------------------- parsing
def parse(path):
    """Return (trace_attrs, events{idx: dict}, ranges[list of (start, dur|None, idx, attrs)])."""
    events, ranges, trace = {}, [], {}
    for _, el in ET.iterparse(path, events=("end",)):
        if el.tag == "event":
            ev = {c.tag: (c.text or "") for c in el}
            events[int(el.get("index"))] = ev
            el.clear()
        elif el.tag == "range":
            a = dict(el.attrib)
            dur = a.pop("duration", None)
            ranges.append((int(a.pop("startTime")), int(dur) if dur is not None else None,
                           int(a.pop("eventIndex")), a))
            el.clear()
        elif el.tag == "trace":
            trace = dict(el.attrib)
    return trace, events, ranges


def shorten(fn, root):
    """qs:@/qs/bar/X.qml and file:///<root>/bar/X.qml -> bar/X.qml."""
    for pre in ("qs:@/qs/", "file://" + root.rstrip("/") + "/", "file://"):
        if fn.startswith(pre):
            return fn[len(pre):]
    return fn


def label(ev, root):
    fn = shorten(ev.get("filename", ""), root)
    s = f"{fn}:{ev.get('line', '0')}:{ev.get('column', '0')}" if fn else ev.get("displayname", "?")
    d = ev.get("details", "")
    return f"{s} {d}" if d else s


def stats(vals):
    """count/total/avg/p50/p95/max of a list of numbers (already in output unit)."""
    if not vals:
        return None
    v = sorted(vals)
    n = len(v)
    pick = lambda q: v[min(n - 1, max(0, int(round(q * n + 0.5)) - 1))]  # nearest rank
    return {"n": n, "total": sum(v), "avg": sum(v) / n, "p50": pick(0.5), "p95": pick(0.95), "max": v[-1]}


def ms(ns):
    return ns / 1e6


# ------------------------------------------------------------- analysis
def self_times(ranges):
    """Return {range position -> self ns} for duration ranges (negative durations ignored)."""
    idx = [i for i, r in enumerate(ranges) if r[1] is not None and r[1] >= 0]
    idx.sort(key=lambda i: (ranges[i][0], -ranges[i][1]))
    selft = {i: ranges[i][1] for i in idx}
    stack = []  # (end, i)
    for i in idx:
        st, d = ranges[i][0], ranges[i][1]
        while stack and stack[-1][0] <= st:
            stack.pop()
        if stack:
            p = stack[-1][1]
            selft[p] -= min(d, stack[-1][0] - st)  # clamp child that overruns parent
        stack.append((st + d, i))
    return {i: max(0, v) for i, v in selft.items()}


def analyze(trace, events, ranges, root, top):
    out = {}
    t0, t1 = int(trace.get("traceStart", 0)), int(trace.get("traceEnd", 0))
    dur_ns = t1 - t0 if t1 > t0 else (max((r[0] for r in ranges), default=0) - min((r[0] for r in ranges), default=0))
    dur_s = max(dur_ns / 1e9, 1e-9)
    out["recording"] = {"duration_s": round(dur_s, 3), "events": len(events), "ranges": len(ranges)}

    selft = self_times(ranges)
    typ = lambda r: events.get(r[2], {}).get("type", "?")

    # per-type overview
    feat = defaultdict(lambda: {"ranges": 0, "total_ms": 0.0, "self_ms": 0.0})
    for i, r in enumerate(ranges):
        f = feat[typ(r)]
        f["ranges"] += 1
        if r[1] is not None and r[1] >= 0:
            f["total_ms"] += ms(r[1])
            f["self_ms"] += ms(selft.get(i, 0))
    out["features"] = {k: {a: round(b, 3) for a, b in v.items()} for k, v in sorted(feat.items())}

    # JS / Binding / HandlingSignal / Compiling: per event aggregate
    agg = defaultdict(lambda: defaultdict(lambda: {"tot": [], "self": 0}))
    for i, r in enumerate(ranges):
        t = typ(r)
        if t in DURATION_TYPES and r[1] is not None and r[1] >= 0:
            a = agg[t][r[2]]
            a["tot"].append(ms(r[1]))
            a["self"] += ms(selft.get(i, 0))

    def rows(t, key_fn=None):
        res = []
        for idx, a in agg[t].items():
            s = stats(a["tot"])
            res.append({"name": label(events[idx], root), "count": s["n"], "total_ms": round(s["total"], 3),
                        "self_ms": round(a["self"], 3), "avg_ms": round(s["avg"], 4), "max_ms": round(s["max"], 3)})
        res.sort(key=lambda x: -x["total_ms"])
        return res

    for t in ("Javascript", "Binding", "HandlingSignal"):
        if agg[t]:
            out[t] = rows(t)[:top]

    # Creating / Compiling per file
    for t in ("Creating", "Compiling"):
        if not agg[t]:
            continue
        per = defaultdict(lambda: {"tot": [], "self": 0})
        for idx, a in agg[t].items():
            f = shorten(events[idx].get("filename", "?"), root)
            per[f]["tot"] += a["tot"]
            per[f]["self"] += a["self"]
        res = []
        for f, a in per.items():
            s = stats(a["tot"])
            res.append({"file": f, "count": s["n"], "total_ms": round(s["total"], 3), "self_ms": round(a["self"], 3),
                        "avg_ms": round(s["avg"], 4), "max_ms": round(s["max"], 3)})
        res.sort(key=lambda x: -x["self_ms"])
        out[t + "_by_file"] = res[:top]
        if t == "Creating":
            out["Creating_sites"] = rows("Creating")[:top]

    # SceneGraph
    sg = defaultdict(lambda: defaultdict(list))
    sg_n = defaultdict(int)
    for r in ranges:
        ev = events.get(r[2], {})
        if ev.get("type") != "SceneGraph":
            continue
        k = int(ev.get("sgEventType", -1))
        sg_n[k] += 1
        names = SG_TYPES.get(k, (f"type{k}", []))[1]
        for j in range(1, 6):
            v = r[3].get(f"timing{j}")
            if v is not None and int(v) >= 0:  # negative = profiler glitch, drop
                sg[k][names[j - 1] if j <= len(names) else f"t{j}"].append(int(v) / 1e3)  # ns -> us
    if sg_n:
        res = []
        for k in sorted(sg_n):
            ph = {}
            order = SG_TYPES.get(k, ("", []))[1]
            for name, vals in sorted(sg[k].items(), key=lambda kv: order.index(kv[0]) if kv[0] in order else 99):
                s = stats(vals)
                ph[name] = {a: round(b, 1) for a, b in s.items() if a != "total"} if s else None
            res.append({"type": SG_TYPES.get(k, (f"type{k}",))[0], "frames": sg_n[k],
                        "fps_avg": round(sg_n[k] / dur_s, 2), "phases_us": ph})
        out["SceneGraph"] = res
    anim = [r for r in ranges if events.get(r[2], {}).get("type") == "Event" and "framerate" in r[3]]
    if anim:
        fr = [int(r[3]["framerate"]) for r in anim]
        out["AnimationFrames"] = {"count": len(anim), "avg_framerate": round(sum(fr) / len(fr), 1),
                                  "max_animations": max(int(r[3].get("animationcount", 0)) for r in anim)}

    # Pixmap cache: pair LoadingStarted(3) -> LoadingFinished(4)/Error(5) per url
    pix = defaultdict(lambda: {"loads": 0, "errors": 0, "load_ms": [], "size": None})
    started = {}
    cache_cnt = []
    for r in sorted((r for r in ranges if events.get(r[2], {}).get("type") == "PixmapCache"), key=lambda r: r[0]):
        ev = events[r[2]]
        url, k = shorten(ev.get("filename", "?"), root), int(ev.get("cacheEventType", -1))
        p = pix[url]
        if k == 3:
            started[url] = r[0]
        elif k in (4, 5):
            if url in started:
                p["load_ms"].append(ms(r[0] - started.pop(url)))
            p["loads" if k == 4 else "errors"] += 1
        elif k == 0 and "width" in r[3]:
            p["size"] = f"{r[3]['width']}x{r[3].get('height', '?')}"
        elif k == 2 and "refCount" in r[3]:
            cache_cnt.append(int(r[3]["refCount"]))
    if pix:
        res = []
        for url, p in pix.items():
            s = stats(p["load_ms"])
            res.append({"url": url[:80], "loads": p["loads"], "errors": p["errors"], "size": p["size"],
                        "load_ms_avg": round(s["avg"], 3) if s else None, "load_ms_max": round(s["max"], 3) if s else None,
                        "_t": s["total"] if s else 0})
        res.sort(key=lambda x: -x["_t"])
        for x in res:
            del x["_t"]
        out["PixmapCache"] = {"urls": len(res), "max_cache_count": max(cache_cnt) if cache_cnt else None, "top": res[:top]}

    # Memory (QV4 allocator): amount = signed byte delta
    mem = defaultdict(lambda: {"allocs": 0, "frees": 0, "alloc_bytes": 0, "freed_bytes": 0})
    for r in ranges:
        ev = events.get(r[2], {})
        if ev.get("type") == "MemoryAllocation" and "amount" in r[3]:
            m, a = mem[MEM_TYPES.get(int(ev.get("memoryEventType", -1)), "?")], int(r[3]["amount"])
            if a >= 0:
                m["allocs"] += 1
                m["alloc_bytes"] += a
            else:
                m["frees"] += 1
                m["freed_bytes"] += -a
    if mem:
        out["Memory"] = {k: dict(v, net_bytes=v["alloc_bytes"] - v["freed_bytes"]) for k, v in sorted(mem.items())}

    # input events (anything of type Event that is not an animation frame)
    ie = defaultdict(int)
    for r in ranges:
        ev = events.get(r[2], {})
        if ev.get("type") in ("Event", "InputEvent") and "animationFrame" not in ev:
            ie[ev.get("displayname", "?")] += 1
    if ie:
        out["InputEvents"] = dict(ie)
    return out


# ------------------------------------------------------------ rendering
def table(rows, cols):
    """rows: list of dicts; cols: list of (header, key)."""
    if not rows:
        return "_none_\n"
    lines = ["| " + " | ".join(h for h, _ in cols) + " |", "|" + "|".join("---" for _ in cols) + "|"]
    for r in rows:
        lines.append("| " + " | ".join(str(r.get(k, "")).replace("|", "\\|") for _, k in cols) + " |")
    return "\n".join(lines) + "\n"


def render(o, top):
    p = []
    rec = o["recording"]
    p.append(f"# QML profile summary\n\nrecording: **{rec['duration_s']} s**, {rec['events']} event types, {rec['ranges']} ranges\n")
    p.append("## Features (ms; self excludes nested ranges)\n")
    p.append(table([dict(type=k, **v) for k, v in o["features"].items()],
                   [("type", "type"), ("ranges", "ranges"), ("total ms", "total_ms"), ("self ms", "self_ms")]))
    cols = [("location / details", "name"), ("count", "count"), ("total ms", "total_ms"), ("self ms", "self_ms"),
            ("avg ms", "avg_ms"), ("max ms", "max_ms")]
    for t, title in (("Javascript", "JavaScript"), ("Binding", "Bindings"), ("HandlingSignal", "Signal handlers")):
        if t in o:
            p.append(f"## Top {top} {title} (by total)\n")
            p.append(table(o[t], cols))
    fcols = [("file", "file"), ("count", "count"), ("total ms", "total_ms"), ("self ms", "self_ms"),
             ("avg ms", "avg_ms"), ("max ms", "max_ms")]
    if "Creating_by_file" in o:
        p.append(f"## Component creation per file (top {top} by self)\n")
        p.append(table(o["Creating_by_file"], fcols))
        p.append(f"### Creation sites (top {top} by total)\n")
        p.append(table(o["Creating_sites"], cols))
    if "Compiling_by_file" in o:
        p.append("## Compiling per file\n")
        p.append(table(o["Compiling_by_file"], fcols))
    if "SceneGraph" in o:
        p.append("## Scene graph (us; windows are not distinguishable in the trace)\n")
        for e in o["SceneGraph"]:
            p.append(f"### {e['type']}: {e['frames']} frames ({e['fps_avg']}/s avg over recording)\n")
            p.append(table([dict(phase=k, **v) for k, v in e["phases_us"].items() if v],
                           [("phase", "phase"), ("n", "n"), ("avg", "avg"), ("p50", "p50"), ("p95", "p95"), ("max", "max")]))
    if "AnimationFrames" in o:
        a = o["AnimationFrames"]
        p.append(f"## Animation frames\n\n{a['count']} frames, avg framerate {a['avg_framerate']}, max concurrent animations {a['max_animations']}\n")
    if "PixmapCache" in o:
        pc = o["PixmapCache"]
        p.append(f"## Pixmap cache ({pc['urls']} urls, max cache count {pc['max_cache_count']})\n")
        p.append(table(pc["top"], [("url", "url"), ("loads", "loads"), ("errors", "errors"), ("size", "size"),
                                    ("load avg ms", "load_ms_avg"), ("load max ms", "load_ms_max")]))
    if "Memory" in o:
        p.append("## Memory (QV4 allocator, bytes)\n")
        p.append(table([dict(kind=k, **v) for k, v in o["Memory"].items()],
                       [("kind", "kind"), ("allocs", "allocs"), ("frees", "frees"), ("allocated", "alloc_bytes"),
                        ("freed", "freed_bytes"), ("net", "net_bytes")]))
    if "InputEvents" in o:
        p.append("## Input events\n\n" + ", ".join(f"{k}: {v}" for k, v in o["InputEvents"].items()) + "\n")
    return "\n".join(p)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("trace")
    ap.add_argument("--top", type=int, default=15)
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--root", default=os.path.expanduser("~/.config/quickshell"),
                    help="config dir, stripped from file paths (default ~/.config/quickshell)")
    a = ap.parse_args()
    trace, events, ranges = parse(a.trace)
    o = analyze(trace, events, ranges, a.root, a.top)
    print(json.dumps(o, indent=1) if a.json else render(o, a.top))


if __name__ == "__main__":
    sys.exit(main())
