pragma Singleton

import QtQuick
import Quickshell

// Tabler Icons: outline webfont 3.49.0 (MIT) installed in ~/.local/share/fonts/tabler-icons.
// glyph("wifi") returns the character for a Glyph; names are the ones on https://tabler.io/icons.
// Only the icons the shell uses are listed. To add one, take its codepoint from ".ti-<name>:before" in
// https://unpkg.com/@tabler/icons-webfont@3.49.0/dist/tabler-icons.css
Singleton {
    readonly property string font: "tabler-icons"

    readonly property var codepoints: ({
        "adjustments": 0xea03,
        "alert-triangle": 0xea06,
        "app-window": 0xefe6,
        "bluetooth": 0xea37,
        "bluetooth-connected": 0xecea,
        "bluetooth-off": 0xeceb,
        "brand-blender": 0xf326,
        "brand-chrome": 0xec18,
        "brand-discord": 0xece3,
        "brand-firefox": 0xecfd,
        "brand-nextcloud": 0xf4d8,
        "brand-signal": 0x10275,
        "brand-slack": 0xec72,
        "brand-spotify": 0xed03,
        "brand-steam": 0xed6f,
        "brand-telegram": 0xec26,
        "brand-vlc": 0xfa78,
        "brand-vscode": 0xf3a0,
        "brand-zoom": 0xf215,
        "brush": 0xebb8,
        "camera": 0xea54,
        "chevron-left": 0xea60,
        "chevron-right": 0xea61,
        "circle": 0xea6b,
        "circle-dot": 0xefb1,
        "cpu": 0xef8e,
        "device-desktop": 0xea89,
        "device-gamepad-2": 0xf1d2,
        "device-laptop": 0xeb64,
        "device-mobile": 0xea8a,
        "device-sd-card": 0xf384,
        "device-speaker": 0xea8b,
        "download": 0xea96,
        "eye": 0xea9a,
        "eye-off": 0xecf0,
        "file-text": 0xeaa2,
        "file-type-pdf": 0xfb10,
        "flame": 0xec2c,
        "folder": 0xeaad,
        "gpu": 0x10299,
        "headphones": 0xeabd,
        "headset": 0xeb90,
        "key": 0xeac7,
        "keyboard": 0xebd6,
        "link-off": 0xf402,
        "lock": 0xeae2,
        "mail": 0xeae5,
        "microphone": 0xeaf0,
        "microphone-off": 0xed16,
        "mouse": 0xeaf9,
        "movie": 0xeafa,
        "music": 0xeafc,
        "network": 0xf09f,
        "notebook": 0xeb96,
        "photo": 0xeb0a,
        "power": 0xeb0d,
        "printer": 0xeb0e,
        "refresh": 0xeb13,
        "server": 0xeb1f,
        "square": 0xeb2c,
        "square-check": 0xeb28,
        "terminal-2": 0xebef,
        "trash": 0xeb41,
        "video": 0xed22,
        "volume": 0xeb51,
        "volume-2": 0xeb4f,
        "volume-3": 0xeb50,
        "wifi": 0xeb52,
        "wifi-0": 0xeba3,
        "wifi-1": 0xeba4,
        "wifi-2": 0xeba5,
        "wifi-off": 0xecfa
    })

    function glyph(name) {
        const cp = codepoints[name];
        return cp === undefined ? "" : String.fromCodePoint(cp);
    }

    // speaker for a 0..1 volume
    function volume(level, muted) {
        return glyph(muted ? "volume-3" : level < 0.5 ? "volume-2" : "volume");
    }

    // wifi bars for a 0..1 signal strength
    function wifi(signal) {
        return glyph(signal < 0.25 ? "wifi-0" : signal < 0.5 ? "wifi-1" : signal < 0.75 ? "wifi-2" : "wifi");
    }

    // ---- application icons (workspaces) ----
    // window class / app id (lowercase) -> icon; prefixes for families of ids; anything else "app-window"
    readonly property var apps: ({
        "chromium": "brand-chrome",
        "google-chrome": "brand-chrome",
        "firefox": "brand-firefox",
        "librewolf": "brand-firefox",
        "discord": "brand-discord",
        "vesktop": "brand-discord",
        "kitty": "terminal-2",
        "foot": "terminal-2",
        "alacritty": "terminal-2",
        "org.wezfurlong.wezterm": "terminal-2",
        "com.mitchellh.ghostty": "terminal-2",
        "nemo": "folder",
        "thunar": "folder",
        "org.gnome.nautilus": "folder",
        "code": "brand-vscode",
        "code-oss": "brand-vscode",
        "codium": "brand-vscode",
        "steam": "brand-steam",
        "spotify": "brand-spotify",
        "org.telegram.desktop": "brand-telegram",
        "signal": "brand-signal",
        "slack": "brand-slack",
        "zoom": "brand-zoom",
        "vlc": "brand-vlc",
        "org.videolan.vlc": "brand-vlc",
        "mpv": "movie",
        "io.mpv.mpv": "movie",
        "io.github.celluloid_player.celluloid": "movie",
        "imv": "photo",
        "org.gnome.loupe": "photo",
        "org.pwmt.zathura": "file-type-pdf",
        "org.gnome.papers": "file-type-pdf",
        "obsidian": "notebook",
        "blender": "brand-blender",
        "thunderbird": "mail",
        "org.qbittorrent.qbittorrent": "download",
        "virt-manager": "device-desktop",
        "looking-glass-client": "device-desktop",
        "org.pulseaudio.pavucontrol": "adjustments",
        "org.keepassxc.keepassxc": "key",
        "obs": "video",
        "com.obsproject.studio": "video"
    })
    readonly property var appPrefixes: [
        ["libreoffice", "file-text"],
        ["gimp", "brush"],
        ["steam_app_", "device-gamepad-2"]   // Steam games
    ]

    // icon for the first id that is known (window class, binary, desktop icon name, ...), else fallback
    function app(ids, fallback) {
        for (const appId of Array.isArray(ids) ? ids : [ids]) {
            const id = (appId || "").toLowerCase();
            const name = apps[id] ?? appPrefixes.find(p => id.startsWith(p[0]))?.[1];
            if (name)
                return glyph(name);
        }
        return glyph(fallback ?? "app-window");
    }

    // ---- tray ----
    // StatusNotifierItem id prefix (lowercase) -> icon; other items show their own icon as a silhouette
    readonly property var trayPrefixes: [
        ["discord", "brand-discord"],
        ["vesktop", "brand-discord"],
        ["steam", "brand-steam"],
        ["spotify", "brand-spotify"],
        ["telegram", "brand-telegram"],
        ["signal", "brand-signal"],
        ["nextcloud", "brand-nextcloud"],
        ["qbittorrent", "download"],
        ["keepassxc", "key"],
        ["obs", "video"]
    ]
    // items whose job is done by a bar module; blueman-applet keeps running as the Bluetooth pairing agent
    readonly property var hiddenTray: ["nm-applet", "blueman"]

    function tray(itemId) {
        const id = (itemId || "").toLowerCase();
        const entry = trayPrefixes.find(p => id.startsWith(p[0]));
        return entry ? glyph(entry[1]) : "";
    }
}
