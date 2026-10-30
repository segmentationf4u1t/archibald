import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Bluetooth
import Quickshell.Networking
import qs
import qs.components
import qs.services

// One full-width bar per monitor (capsule ends), dropdowns hang off its modules.
PanelWindow {
    id: bar

    required property ShellScreen modelData
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(modelData)

    // ---- dropdown state: at most one open per bar ----
    property string openPopup: ""
    property var trayMenuItem: null
    property Item trayMenuAnchor: tray

    function togglePopup(name) {
        openPopup = openPopup === name ? "" : name;
    }

    function closePopup(name) {
        if (openPopup === name)
            openPopup = "";
    }

    function openTrayMenu(item, anchorItem) {
        if (openPopup === "traymenu" && trayMenuItem === item) {
            openPopup = "";
            return;
        }
        trayMenuItem = item;
        trayMenuAnchor = anchorItem;
        openPopup = "traymenu";
    }

    // ---- live audio / bluetooth / network state for the status modules ----
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property bool sinkMuted: sink?.audio?.muted ?? false
    readonly property real sinkVolume: sink?.audio?.volume ?? 0

    readonly property BluetoothAdapter btAdapter: Bluetooth.defaultAdapter
    readonly property int btConnected: btAdapter ? btAdapter.devices.values.filter(d => d.connected).length : 0

    readonly property var netDevices: Networking.devices.values
    readonly property var wiredUp: netDevices.find(d => d.type === DeviceType.Wired && d.connected) ?? null
    readonly property var wifiDevice: netDevices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wifiNetwork: wifiDevice ? wifiDevice.networks.values.find(n => n.connected) ?? null : null

    screen: modelData
    anchors {
        top: true
        left: true
        right: true
    }
    margins {
        top: Theme.barGapTop
        left: Theme.barGapSide
        right: Theme.barGapSide
    }
    implicitHeight: Theme.barHeight
    color: "transparent"
    WlrLayershell.namespace: "qs-bar"
    WlrLayershell.layer: WlrLayer.Top
    // While a dropdown is open its focus grab hands the keyboard to the surface under the pointer,
    // usually this bar (the click that opened it): Escape closes the dropdown from here too.
    WlrLayershell.keyboardFocus: openPopup !== "" ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    Item {
        focus: true
        Keys.onEscapePressed: bar.openPopup = ""
    }

    PwObjectTracker {
        objects: [bar.sink]
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.barBg
        border.width: 1
        border.color: Theme.obsidian
    }

    // ---------------------------------------------------------------- left
    RowLayout {
        id: left
        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        BarButton {
            icon: Icons.glyph("flame")
            iconSize: 18
            iconColor: Theme.magma
            onClicked: Quickshell.execDetached(["sh", "-c", "pkill -x rofi || rofi -show drun"])
        }

        Workspaces {
            bar: bar
        }

        Label {
            id: title
            readonly property var toplevel: Hyprland.activeToplevel
            // stop 16 px before the centered clock
            Layout.maximumWidth: Math.max(0, clock.x - 16 - left.x - x)
            Layout.leftMargin: 8
            muted: true
            text: toplevel && toplevel.monitor === bar.monitor ? toplevel.title
                : bar.monitor?.activeWorkspace?.lastIpcObject?.lastwindowtitle ?? ""
        }
    }

    // ---------------------------------------------------------------- center
    BarButton {
        id: clock
        anchors.centerIn: parent
        padding: 16
        active: bar.openPopup === "calendar"
        bold: true
        label: Qt.formatDateTime(sysClock.date, "HH:mm")
        onClicked: bar.togglePopup("calendar")

        Label {
            anchors.verticalCenter: parent.verticalCenter
            small: true
            muted: true
            text: sysClock.date.toLocaleString(I18n.locale, "ddd dd.MM")
        }

        SystemClock {
            id: sysClock
            precision: SystemClock.Minutes
        }
    }

    // ---------------------------------------------------------------- right
    RowLayout {
        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Tray {
            id: tray
            bar: bar
        }

        BarButton {
            id: audioButton
            active: bar.openPopup === "audio"
            icon: Icons.volume(bar.sinkVolume, bar.sinkMuted)
            label: bar.sinkMuted ? "mute" : Math.round(bar.sinkVolume * 100) + "%"
            iconColor: bar.sinkMuted ? Theme.fire : Theme.magma
            onClicked: mouse => {
                if (mouse.button === Qt.MiddleButton && bar.sink?.audio)
                    bar.sink.audio.muted = !bar.sink.audio.muted;
                else
                    bar.togglePopup("audio");
            }
            onWheel: wheel => {
                if (bar.sink?.audio)
                    bar.sink.audio.volume = Math.max(0, Math.min(1, bar.sinkVolume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05)));
            }
        }

        BarButton {
            id: bluetoothButton
            active: bar.openPopup === "bluetooth"
            icon: Icons.glyph(!bar.btAdapter?.enabled ? "bluetooth-off" : bar.btConnected > 0 ? "bluetooth-connected" : "bluetooth")
            label: bar.btConnected > 0 ? String(bar.btConnected) : ""
            iconColor: bar.btAdapter?.enabled ? Theme.magma : Theme.ashDim
            onClicked: bar.togglePopup("bluetooth")
        }

        BarButton {
            id: networkButton
            readonly property real signal: bar.wifiNetwork?.signalStrength ?? 0
            active: bar.openPopup === "network"
            icon: bar.wiredUp ? Icons.glyph("network")
                : !bar.wifiNetwork ? Icons.glyph("wifi-off")
                : Icons.wifi(signal)
            iconColor: bar.wiredUp || bar.wifiNetwork ? Theme.magma : Theme.fire
            onClicked: bar.togglePopup("network")
        }

        BarButton {
            id: cpuButton
            active: bar.openPopup === "cpu"
            icon: Icons.glyph("cpu")
            label: Math.round(SysStats.cpu) + "%"
            iconColor: SysStats.cpu >= 85 ? Theme.fire : Theme.magma
            onClicked: bar.togglePopup("cpu")
        }

        BarButton {
            id: memoryButton
            active: bar.openPopup === "memory"
            icon: Icons.glyph("device-sd-card")
            label: Math.round(SysStats.mem) + "%"
            iconColor: SysStats.mem >= 85 ? Theme.fire : Theme.magma
            onClicked: bar.togglePopup("memory")
        }

        BarButton {
            id: diskButton
            active: bar.openPopup === "disk"
            icon: Icons.glyph("server")
            label: Math.round(SysStats.diskUtil) + "%"   // busiest disk, % of time busy
            iconColor: SysStats.diskUtil >= 85 ? Theme.fire : Theme.magma
            onClicked: bar.togglePopup("disk")
        }

        BarButton {
            id: gpuButton
            visible: SysStats.gpus.length > 0
            active: bar.openPopup === "gpu"
            icon: Icons.glyph("gpu")
            label: Math.round(SysStats.gpu) + "%"
            iconColor: SysStats.gpu >= 85 ? Theme.fire : Theme.magma
            onClicked: bar.togglePopup("gpu")
        }

        BarButton {
            icon: Icons.glyph("power")
            iconColor: Theme.magma
            padding: 12
            onClicked: Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/rofi-power"])
        }
    }

    // ---------------------------------------------------------------- dropdowns
    Dropdown { bar: bar; name: "calendar"; anchorItem: clock; source: Qt.resolvedUrl("../popups/CalendarPopup.qml") }
    Dropdown { bar: bar; name: "traymenu"; anchorItem: bar.trayMenuAnchor; source: Qt.resolvedUrl("../popups/TrayMenuPopup.qml") }
    Dropdown { bar: bar; name: "audio"; anchorItem: audioButton; source: Qt.resolvedUrl("../popups/AudioPopup.qml") }
    Dropdown { bar: bar; name: "bluetooth"; anchorItem: bluetoothButton; source: Qt.resolvedUrl("../popups/BluetoothPopup.qml") }
    Dropdown { bar: bar; name: "network"; anchorItem: networkButton; source: Qt.resolvedUrl("../popups/NetworkPopup.qml") }
    Dropdown { bar: bar; name: "cpu"; anchorItem: cpuButton; source: Qt.resolvedUrl("../popups/CpuPopup.qml") }
    Dropdown { bar: bar; name: "memory"; anchorItem: memoryButton; source: Qt.resolvedUrl("../popups/MemoryPopup.qml") }
    Dropdown { bar: bar; name: "disk"; anchorItem: diskButton; source: Qt.resolvedUrl("../popups/DiskPopup.qml") }
    Dropdown { bar: bar; name: "gpu"; anchorItem: gpuButton; source: Qt.resolvedUrl("../popups/GpuPopup.qml") }
}
