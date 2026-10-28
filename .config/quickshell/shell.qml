//@ pragma IconTheme Papirus-Dark
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.bar
import qs.screenshot

ShellRoot {
    Variants {
        id: bars
        model: Quickshell.screens
        delegate: Bar {}
    }

    // qs ipc call bar toggle <calendar|audio|bluetooth|network|cpu|memory|gpu>
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
