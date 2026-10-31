# Profiling Quickshell with qmlprofiler (non-interactive)

Verified with Quickshell 0.3.2, Qt 6.12, `/usr/bin/qmlprofiler`.

## Recipe

1. Start a *separate* Quickshell instance with the QML debugger port open
   (the already-running `qs` cannot be attached to: it was not started with `--debug`).
   ```sh
   quickshell --debug 3799 --waitfordebug -p ~/.config/quickshell
   ```
   - `--debug PORT` alone does NOT block: the config loads immediately and the port listens
     ("QML Debugger: Waiting for connection on port ..." is only a log line).
   - `--waitfordebug` blocks *before the config executes* until a debugger attaches. Use it if you
     want startup cost: it is the only way to record **Compiling** and the initial **Creating** /
     **PixmapCache** / first-binding data. Without it, those are gone by the time you attach.
   - The port stays open after the profiler disconnects; you can attach again repeatedly
     (each attach starts a fresh trace).
2. Attach the profiler in `--interactive` mode and drive it over stdin:
   ```sh
   (sleep 10; echo flush; sleep 1; echo quit) | /usr/bin/qmlprofiler --attach localhost --port 3799 --interactive -o out.qtd
   ```
   - Recording starts automatically at attach ("Recording Status: on"). Attach takes ~1 s
     wall (connect + "recording" message, measured from process start).
   - `flush` = stop recording, write `-o` file, clear memory. 3-11 s traces are written in <0.1 s.
   - **`quit` is required**: on stdin EOF qmlprofiler hangs forever. `quit` does not kill an
     attached target.
   - The qmlprofiler status messages go to **stderr**, not stdout (capture with `2>&1`).
3. Summarize: `python3 bench/qtd_summary.py out.qtd [--top 20] [--json] [--root ~/.config/quickshell]`.
4. Stop the profiled instance yourself (`pkill -f 'quickshell --debug 3799'`).

Python driver equivalent (what to automate):
```python
p = subprocess.Popen(["/usr/bin/qmlprofiler","--attach","localhost","--port","3799",
        "--interactive","-o",out], stdin=PIPE, stdout=PIPE, stderr=STDOUT)
wait for b"Recording Status" on stdout (≈1 s); sleep(N); write b"flush\n"; wait for b"Data written";
write b"quit\n"; p.wait()
```
Wait for the debug port (`ss -ltn | grep :3799`, ≈0.3 s after launch without --waitfordebug) before attaching.

## What does NOT work

- `timeout -s INT N qmlprofiler --attach ... -o f.qtd` (non-interactive): SIGINT is ignored/does
  not write the file; no `.qtd` is produced. (Without `-o` the XML would go to stdout.)
- Killing the target while a non-interactive attach is recording: "Connection dropped while recording,
  last trace is damaged!", no file.
- `interactive` + `output FILE` command then `flush`: no file was written, the whole XML was dumped to stdout.
  Pass `-o FILE` on the command line and just `flush`.

## What a trace contains (checked against a throwaway config)

| Feature | In .qtd? | Notes |
|---|---|---|
| Javascript | yes | per binding/handler expression and named functions; nested ranges |
| Binding | yes | only *interpreted* QML bindings; qmlcachegen-compiled bindings may not emit JS ranges |
| HandlingSignal | yes | wraps its Javascript range (same location) |
| Creating | yes | per object type per `file:line`; nested (parent includes children) so use *self* ms |
| Compiling | only with `--waitfordebug` (or runtime `Qt.createQmlObject`/new components) | file-level |
| SceneGraph | yes | see below |
| Animations | yes | `AnimationFrame` events: `framerate`, `animationcount`, thread |
| PixmapCache | yes | per url: loading started/finished, size known, ref/cache counts |
| MemoryAllocation | yes | QV4 heap only (HeapPage/LargeItem/SmallItem), signed byte deltas |
| DebugMessage | yes | log lines |
| InputEvents | only if input happened | |

Filenames: config files appear as `qs:@/qs/<relative path>`; dynamic `createQmlObject` sources by
their given url. The summary strips `qs:@/qs/` and `file://<--root>/`.

### SceneGraph details
- Per frame ranges, durations in ns in attributes `timing1..N`:
  - RenderLoopFrame (render thread): sync, render, swap. `swap` ≈ vsync wait (≈16 ms @60 Hz) when something animates; ignore as "cost".
  - PolishAndSync (GUI thread): polish, wait, sync, animations.
  - RendererFrame: preprocess, update, bind, render (`bind` is often negative = profiler glitch; the script drops negatives).
  - AdaptationLayer (glyph), TexturePrepare/Deletion appear when text/textures change.
- **No window id**: frames of all windows (bar + popups, all screens) are merged; per-window
  attribution is not possible from the .qtd. Frame rate is only counted while something repaints.
- Outliers: first frame of a window can be huge (e.g. `sync` 100 ms, `swap` seconds while waiting for the
  first compositor frame callback). Compare p50/p95, not just max.
- Layer-shell windows: **not verified here** (the headless compositor I could use lacks
  wlr-layer-shell, see below). FloatingWindow frames are recorded as above; PanelWindow frames use the same
  Qt render loop, so expect the same event types.

## Headless compositor findings (invisible, no effect on the user's session)

- This Hyprland build has no headless-only env var; a bare Hyprland fails with `CBackend::create() failed!`.
- `cage` works headless and renders on the GPU render node:
  ```sh
  env -u WAYLAND_DISPLAY -u DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE XDG_RUNTIME_DIR=/tmp/qsprof-xdg \
    WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 WLR_RENDERER=gles2 WLR_RENDER_DRM_DEVICE=/dev/dri/renderD128 \
    dbus-run-session -- cage -- ./run-inner.sh     # run-inner.sh: exec quickshell --debug 3799 --waitfordebug -p DIR
  ```
  (`/tmp/qsprof-xdg` = private `mkdir -m700` runtime dir; cage then creates `wayland-0` there; the Qt debug port
  is TCP so the profiler attaches from outside.) Kill with `pkill -f 'quickshell --debug 3799'` and the cage/dbus
  parents (match on the private XDG_RUNTIME_DIR in `/proc/*/environ`).
- cage has **no wlr-layer-shell**: Quickshell logs `Failed to initialize layershell integration`, `PanelWindow`
  never maps (no frames). Use a `FloatingWindow` for mechanics tests, or nest Hyprland as a client of cage for layer-shell.
- The private dbus session auto-starts xdg-desktop-portal(+gtk/hyprland), at-spi etc.; they die with the session
  but check for leftovers.

## Caveats
- Profiling slows the app (hooks on every binding/JS call); compare traces only against traces made the same way.
- A second instance of the real config duplicates services and bars; do it in the isolated env.
- Memory section is JS-heap allocation deltas, not RSS.
