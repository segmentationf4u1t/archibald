import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import qs
import qs.components

// Bluetooth dropdown: adapter switch, paired devices (connect / disconnect / forget),
// discovery of new devices (pair + trust + connect). Discovery runs only on request (the refresh
// button): an inquiry scan shares the radio with connected audio and makes headphones stutter/hang.
Item {
    id: root

    property var dropdown

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool adapterOn: adapter !== null && adapter.enabled
    readonly property bool blocked: adapter !== null && adapter.state === BluetoothAdapterState.Blocked
    readonly property bool transitional: adapter !== null
        && (adapter.state === BluetoothAdapterState.Enabling || adapter.state === BluetoothAdapterState.Disabling)

    // true while discovery was switched on by this popup (and has to be switched off on close)
    property bool startedDiscovery: false
    // addresses of devices the user asked to pair; they are connected as soon as pairing succeeds
    property var pendingConnect: ({})

    readonly property var pairedDevices: {
        if (!root.adapter)
            return [];
        return root.adapter.devices.values.filter(d => d.paired || d.bonded).sort((a, b) => {
            if (a.connected !== b.connected)
                return a.connected ? -1 : 1;
            return root.deviceName(a).localeCompare(root.deviceName(b));
        });
    }

    readonly property var availableDevices: {
        if (!root.adapter)
            return [];
        return root.adapter.devices.values.filter(d => !d.paired && !d.bonded && d.deviceName !== "").sort((a, b) => {
            if (a.pairing !== b.pairing)
                return a.pairing ? -1 : 1;
            return root.deviceName(a).localeCompare(root.deviceName(b));
        });
    }

    implicitWidth: 380
    implicitHeight: col.implicitHeight

    function deviceName(d) {
        return d.name || d.deviceName || d.address;
    }

    function deviceGlyph(icon) {
        const i = (icon || "").toLowerCase();
        if (i.indexOf("headset") >= 0)
            return "󰋎";
        if (i.indexOf("headphone") >= 0 || i.indexOf("audio-card") >= 0)
            return "󰋋";
        if (i.indexOf("speaker") >= 0)
            return "󰓃";
        if (i.indexOf("mouse") >= 0)
            return "󰍽";
        if (i.indexOf("keyboard") >= 0)
            return "󰌌";
        if (i.indexOf("gaming") >= 0 || i.indexOf("joystick") >= 0 || i.indexOf("gamepad") >= 0)
            return "󰊗";
        if (i.indexOf("phone") >= 0)
            return "󰄜";
        if (i.indexOf("computer") >= 0 || i.indexOf("laptop") >= 0)
            return "󰌢";
        if (i.indexOf("display") >= 0 || i.indexOf("monitor") >= 0 || i.indexOf("video") >= 0)
            return "󰍹";
        if (i.indexOf("printer") >= 0)
            return "󰐪";
        if (i.indexOf("camera") >= 0)
            return "󰄀";
        return "󰂯";
    }

    function deviceSubtitle(d) {
        let s;
        switch (d.state) {
        case BluetoothDeviceState.Connected:
            s = I18n.tr("Connected");
            break;
        case BluetoothDeviceState.Connecting:
            s = I18n.tr("Connecting…");
            break;
        case BluetoothDeviceState.Disconnecting:
            s = I18n.tr("Disconnecting…");
            break;
        default:
            s = I18n.tr("Disconnected");
        }
        // `battery` is a 0..1 fraction
        if (d.batteryAvailable)
            s += " · " + Math.round(d.battery * 100) + "%";
        return s;
    }

    function toggleConnection(d) {
        if (d.state === BluetoothDeviceState.Connecting || d.state === BluetoothDeviceState.Disconnecting)
            return;
        if (d.connected)
            d.disconnect();
        else
            d.connect();
    }

    function pairDevice(d) {
        if (d.pairing)
            return;
        root.pendingConnect[d.address] = true;
        d.trusted = true;
        d.pair();
    }

    function toggleDiscovery() {
        if (!root.adapterOn)
            return;
        const on = !root.adapter.discovering;
        root.adapter.discovering = on;
        root.startedDiscovery = on;
    }

    Component.onDestruction: {
        if (root.startedDiscovery && root.adapter)
            root.adapter.discovering = false;
    }

    // adapter switched off while scanning -> nothing left to stop on close
    Connections {
        target: root.adapter
        function onEnabledChanged() {
            if (!root.adapter.enabled)
                root.startedDiscovery = false;
        }
    }

    // finish what a click on an available device started: trust + connect once pairing succeeded
    Instantiator {
        model: root.adapter ? root.adapter.devices : null
        delegate: Connections {
            id: pairWatch
            required property var modelData
            target: modelData
            function onPairedChanged() {
                const d = pairWatch.modelData;
                if (d.paired && root.pendingConnect[d.address]) {
                    delete root.pendingConnect[d.address];
                    d.trusted = true;
                    d.connect();
                }
            }
            function onPairingChanged() {
                const d = pairWatch.modelData;
                // pairing ended without success: forget the request
                if (!d.pairing && !d.paired)
                    delete root.pendingConnect[d.address];
            }
        }
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 14

        // ── header ────────────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 2
            spacing: 10

            Glyph {
                text: !root.adapter || !root.adapterOn ? "󰂲" : "󰂯"
                color: root.adapterOn ? Theme.magma : Theme.ashDim
                size: 20
            }

            Label {
                text: "Bluetooth"
                font.weight: Font.DemiBold
            }

            Label {
                Layout.fillWidth: true
                visible: root.adapter !== null
                text: root.adapter ? root.adapter.name : ""
                muted: true
                small: true
            }

            Item {
                Layout.fillWidth: true
                visible: root.adapter === null
            }

            Toggle {
                visible: root.adapter !== null
                enabled: !root.blocked && !root.transitional
                checked: root.adapterOn
                onToggled: v => root.adapter.enabled = v
            }
        }

        // ── no adapter / off / blocked ────────────────────────────────────────────
        Label {
            Layout.fillWidth: true
            Layout.leftMargin: 2
            Layout.topMargin: 4
            Layout.bottomMargin: 4
            visible: !root.adapterOn
            wrapMode: Text.WordWrap
            muted: true
            text: !root.adapter ? I18n.tr("No Bluetooth adapter")
                : root.blocked ? I18n.tr("Bluetooth is blocked (rfkill). Unblock it to use devices.")
                : root.transitional ? (root.adapter.state === BluetoothAdapterState.Enabling ? I18n.tr("Turning on…") : I18n.tr("Turning off…"))
                : I18n.tr("Bluetooth is off. Turn it on to connect devices.")
        }

        // ── paired devices ────────────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            visible: root.adapterOn
            spacing: 6

            SectionHeader {
                Layout.fillWidth: true
                Layout.leftMargin: 2
                text: I18n.tr("Devices")
            }

            Label {
                Layout.fillWidth: true
                Layout.leftMargin: 2
                visible: root.pairedDevices.length === 0
                text: I18n.tr("No paired devices")
                muted: true
                small: true
            }

            ListView {
                id: pairedList
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, 5 * 50)
                visible: root.pairedDevices.length > 0
                clip: true
                spacing: 2
                interactive: contentHeight > height
                boundsBehavior: Flickable.StopAtBounds
                model: ScriptModel {
                    values: root.pairedDevices
                }

                delegate: Item {
                    id: pairedRow

                    required property var modelData

                    width: pairedList.width
                    height: 48

                    HoverHandler {
                        id: rowHover
                    }

                    ListItem {
                        anchors.fill: parent
                        icon: root.deviceGlyph(pairedRow.modelData.icon)
                        iconColor: pairedRow.modelData.connected ? Theme.magma : Theme.ash
                        title: root.deviceName(pairedRow.modelData)
                        subtitle: root.deviceSubtitle(pairedRow.modelData)
                        highlighted: pairedRow.modelData.connected
                        busy: pairedRow.modelData.state === BluetoothDeviceState.Connecting
                            || pairedRow.modelData.state === BluetoothDeviceState.Disconnecting
                        onClicked: root.toggleConnection(pairedRow.modelData)

                        IconButton {
                            visible: rowHover.hovered
                            icon: "󰆴"
                            iconColor: Theme.ash
                            implicitWidth: 28
                            implicitHeight: 28
                            onClicked: pairedRow.modelData.forget()
                        }
                    }
                }
            }
        }

        // ── available devices ─────────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            visible: root.adapterOn
            spacing: 6

            SectionHeader {
                Layout.fillWidth: true
                Layout.leftMargin: 2
                text: I18n.tr("Available")

                Item {
                    visible: root.adapter !== null && root.adapter.discovering
                    width: 16
                    height: 28

                    Spinner {
                        anchors.centerIn: parent
                        running: parent.visible
                    }
                }

                IconButton {
                    icon: "󰑐"
                    checked: root.adapter !== null && root.adapter.discovering
                    implicitWidth: 28
                    implicitHeight: 28
                    onClicked: root.toggleDiscovery()
                }
            }

            Label {
                Layout.fillWidth: true
                Layout.leftMargin: 2
                visible: root.availableDevices.length === 0
                text: root.adapter && root.adapter.discovering ? I18n.tr("Searching for devices…") : I18n.tr("Search to find new devices")
                muted: true
                small: true
            }

            ListView {
                id: availableList
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, 5 * 50)
                visible: root.availableDevices.length > 0
                clip: true
                spacing: 2
                interactive: contentHeight > height
                boundsBehavior: Flickable.StopAtBounds
                model: ScriptModel {
                    values: root.availableDevices
                }

                delegate: ListItem {
                    id: availRow

                    required property var modelData

                    width: availableList.width
                    height: 48
                    icon: root.deviceGlyph(modelData.icon)
                    iconColor: Theme.ash
                    title: root.deviceName(modelData)
                    subtitle: modelData.pairing ? I18n.tr("Pairing…") : I18n.tr("Click to pair · %1", modelData.address)
                    busy: modelData.pairing
                    onClicked: root.pairDevice(modelData)
                }
            }
        }

        // ── footer ────────────────────────────────────────────────────────────────
        FooterLink {
            Layout.alignment: Qt.AlignHCenter
            text: I18n.tr("Advanced… (%1)", "blueman-manager")
            command: ["blueman-manager"]
            dropdown: root.dropdown
        }
    }
}
