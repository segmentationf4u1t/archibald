//@ pragma IconTheme Papirus-Dark-Volcanic
// Software scene graph instead of GL: no GL context and render thread per window, so less memory
// and cheaper redraws of the bar's small updates. DefaultEnv, so an explicit QT_QUICK_BACKEND
// (empty = GL) still wins; programs started from the bar go through Launch.exec, which removes it.
//@ pragma DefaultEnv QT_QUICK_BACKEND=software
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.bar
import qs
import qs.screenshot
import qs.services

ShellRoot {
    Variants {
        id: bars
        model: Quickshell.screens
        delegate: Bar {}
    }

    // qs ipc call bar toggle <calendar|audio|bluetooth|network|cpu|memory|disk|gpu>
    // acts on the bar of the focused monitor
    IpcHandler {
        target: "bar"

        function toggle(name: string): void {
            const bar = bars.instances.find(b => b.monitor === Hyprland.focusedMonitor) ?? bars.instances[0];
            if (bar)
                bar.togglePopup(name);
        }

        function close(): void {
            for (const bar of bars.instances)
                bar.openPopup = "";
        }
    }

    // qs ipc call perf <enable|disable|report|warm|cold>   (bench instrumentation, see Perf.qml)
    IpcHandler {
        target: "perf"

        function enable(): void {
            Perf.setEnabled(true);
        }

        function disable(): void {
            Perf.setEnabled(false);
        }

        // log the frame counters collected since the last report
        function report(): void {
            Perf.report();
        }

        // what hovering the CPU/memory bar module does
        function warm(): void {
            SysStats.warmProcs();
        }

        // forget the previous process sample
        function cold(): void {
            SysStats.resetProcs();
        }
    }

    Freeze {
        id: freezer
    }

    // qs ipc call screenshot freeze <dir> | thaw   (used by ~/.local/bin/screenshot)
    IpcHandler {
        target: "screenshot"

        function freeze(dir: string): void {
            freezer.dir = dir;
        }

        function thaw(): void {
            freezer.dir = "";
        }
    }
}
