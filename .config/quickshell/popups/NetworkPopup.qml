import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import qs
import qs.components
import qs.services

// Wi-Fi / network dropdown: radio toggle, live connection card with throughput charts,
// scanned network list (inline password entry for unknown secured networks).
Item {
    id: root

    property var dropdown

    // ---- state ---------------------------------------------------------------------------
    readonly property var wifiDev: {
        const devs = Networking.devices.values.filter(d => d.type === DeviceType.Wifi);
        return devs.find(d => d.connected) ?? devs[0] ?? null;
    }
    readonly property var wiredDev: Networking.devices.values.find(d => d.type === DeviceType.Wired && d.connected) ?? null

    // connected -> known -> signal (10 % buckets, so the list does not jitter) -> name.
    // Kept as a plain property rebuilt by rebuildList(): the sort reads signalStrength of every network,
    // so as a binding it would re-sort and re-diff the list on every scan update. Instead the cheap keys
    // below trigger it: structure (names / connected / known) at once, signal buckets debounced.
    property var networkList: []

    function rebuildList() {
        let next = [];
        if (wifiDev && Networking.wifiEnabled) {
            next = wifiDev.networks.values.filter(n => n.name !== "").sort((a, b) => {
                if (a.connected !== b.connected)
                    return a.connected ? -1 : 1;
                if (a.known !== b.known)
                    return a.known ? -1 : 1;
                const sa = Math.round(a.signalStrength * 10);
                const sb = Math.round(b.signalStrength * 10);
                if (sa !== sb)
                    return sb - sa;
                return a.name.localeCompare(b.name);
            });
        }
        resortTimer.stop();
        const cur = networkList;
        if (next.length !== cur.length || next.some((n, i) => n !== cur[i]))
            networkList = next;
    }

    // set of networks and their connected / known state: a change updates the list immediately
    readonly property string listKey: wifiDev && Networking.wifiEnabled
        ? wifiDev.networks.values.map(n => n.name + "|" + (n.connected ? 1 : 0) + (n.known ? 1 : 0)).join("\n")
        : ""
    // signal buckets only: a change re-sorts after resortTimer (a scan reports a stream of small updates)
    readonly property string signalKey: wifiDev && Networking.wifiEnabled
        ? wifiDev.networks.values.map(n => Math.round(n.signalStrength * 10)).join()
        : ""

    onListKeyChanged: rebuildList()
    onSignalKeyChanged: resortTimer.restart()

    Timer {
        id: resortTimer
        interval: 1500
        onTriggered: root.rebuildList()
    }
    readonly property var activeNet: networkList.find(n => n.connected) ?? null
    readonly property bool anyConnection: activeNet !== null || wiredDev !== null

    property string pskTarget: ""        // name of the network whose password field is open

    readonly property bool badConnectivity: anyConnection
        && (Networking.connectivity === NetworkConnectivity.None
            || Networking.connectivity === NetworkConnectivity.Portal
            || Networking.connectivity === NetworkConnectivity.Limited)

    function connectivityText() {
        switch (Networking.connectivity) {
        case NetworkConnectivity.Portal:
            return I18n.tr("Network portal login required");
        case NetworkConnectivity.Limited:
            return I18n.tr("Limited connectivity – no internet access");
        default:
            return I18n.tr("No internet connection");
        }
    }

    // ---- network helpers -------------------------------------------------------------------
    function signalGlyph(s) {
        return Icons.wifi(s);
    }

    function isOpen(sec) {
        return sec === WifiSecurityType.Open || sec === WifiSecurityType.Owe;
    }

    function usesPsk(sec) {
        return sec === WifiSecurityType.Sae || sec === WifiSecurityType.Wpa2Psk
            || sec === WifiSecurityType.WpaPsk || sec === WifiSecurityType.StaticWep;
    }

    function failReasonText(reason) {
        switch (reason) {
        case ConnectionFailReason.NoSecrets:
            return I18n.tr("Password missing or incorrect");
        case ConnectionFailReason.WifiClientDisconnected:
            return I18n.tr("Disconnected");
        case ConnectionFailReason.WifiClientFailed:
            return I18n.tr("Wi‑Fi connection error");
        case ConnectionFailReason.WifiAuthTimeout:
            return I18n.tr("Authentication timed out");
        case ConnectionFailReason.WifiNetworkLost:
            return I18n.tr("Network is out of range");
        default:
            return I18n.tr("Could not connect");
        }
    }

    function formatSpeed(mbps) {
        return mbps >= 1000 ? (mbps / 1000) + " Gb/s" : mbps + " Mb/s";
    }

    function ensureVisible(item) {
        const y = item.mapToItem(netCol, 0, 0).y;
        const bottom = y + item.height;
        const maxY = Math.max(0, flick.contentHeight - flick.height);
        if (bottom > flick.contentY + flick.height)
            flick.contentY = Math.min(bottom - flick.height, maxY);
        if (y < flick.contentY)
            flick.contentY = y;
    }

    // ---- Wi-Fi scanner: on while the popup is open, previous value restored on close ------------
    property var scanDev: null
    property bool scanPrev: false

    function acquireScanner() {
        if (!wifiDev || scanDev)
            return;
        scanDev = wifiDev;
        scanPrev = wifiDev.scannerEnabled;
        wifiDev.scannerEnabled = true;
    }

    function releaseScanner() {
        if (scanDev)
            scanDev.scannerEnabled = scanPrev;
        scanDev = null;
    }

    onWifiDevChanged: {
        releaseScanner();
        acquireScanner();
        rebuildList();
    }
    Component.onCompleted: {
        rebuildList();
        acquireScanner();
    }
    Component.onDestruction: releaseScanner()

    // ---- IPv4 lookup (NetworkDevice.address holds the MAC, not the IP) -----------------------
    component IpProbe: Process {
        id: probe

        property string iface: ""
        property string ip: ""

        // `command` is assigned in refresh(): onIfaceChanged runs before a binding on `iface` would re-evaluate
        stdout: StdioCollector {
            onStreamFinished: {
                const m = /inet (\d+\.\d+\.\d+\.\d+\/\d+)/.exec(text);
                probe.ip = m ? m[1] : "";
            }
        }

        function refresh() {
            if (iface === "") {
                ip = "";
            } else if (!running) {
                command = ["ip", "-4", "-o", "addr", "show", "dev", iface];
                running = true;
            }
        }

        onIfaceChanged: refresh()
        Component.onCompleted: refresh()
    }

    IpProbe {
        id: wifiIp
        iface: root.activeNet && root.wifiDev ? root.wifiDev.name : ""
    }

    IpProbe {
        id: wiredIp
        iface: root.wiredDev ? root.wiredDev.name : ""
    }

    Timer {
        interval: 10000
        repeat: true
        running: true
        onTriggered: {
            wifiIp.refresh();
            wiredIp.refresh();
        }
    }

    // ---- UI pieces -------------------------------------------------------------------------
    component ConnBlock: RowLayout {
        id: block
        property string icon: ""
        property string title: ""
        property string line1: ""
        property string line2: ""

        Layout.fillWidth: true
        spacing: 12

        Glyph {
            text: block.icon
            color: Theme.moss
            size: 22
            Layout.preferredWidth: 26
            Layout.alignment: Qt.AlignTop
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Label {
                    Layout.fillWidth: true
                    text: block.title
                    font.weight: Font.Bold
                }

                Label {
                    text: I18n.tr("Connected")
                    small: true
                    color: Theme.moss
                }
            }

            Label {
                Layout.fillWidth: true
                visible: text !== ""
                text: block.line1
                small: true
                muted: true
            }

            Label {
                Layout.fillWidth: true
                visible: text !== ""
                text: block.line2
                small: true
                muted: true
            }
        }
    }

    implicitWidth: 400
    implicitHeight: col.implicitHeight

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 14

        // ---- header ------------------------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Glyph {
                text: Icons.glyph("wifi")
                size: 20
                color: Networking.wifiEnabled ? Theme.magma : Theme.ashDim
            }

            Label {
                Layout.fillWidth: true
                text: "Wi‑Fi"
                font.weight: Font.Bold
            }

            Toggle {
                checked: Networking.wifiEnabled
                enabled: Networking.wifiHardwareEnabled
                onToggled: value => Networking.wifiEnabled = value
            }
        }

        // ---- connection card ---------------------------------------------------------------
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: card.implicitHeight + 24
            radius: Theme.radius
            color: Theme.crater
            border.width: 1
            border.color: Theme.obsidian

            ColumnLayout {
                id: card
                x: 12
                y: 12
                width: parent.width - 24
                spacing: 12

                ConnBlock {
                    visible: root.wiredDev !== null
                    icon: Icons.glyph("network")
                    title: I18n.tr("Wired")
                    line1: root.wiredDev ? root.wiredDev.name + (root.wiredDev.linkSpeed > 0 ? " · " + root.formatSpeed(root.wiredDev.linkSpeed) : "") : ""
                    line2: wiredIp.ip
                }

                ConnBlock {
                    visible: root.activeNet !== null
                    icon: root.activeNet ? root.signalGlyph(root.activeNet.signalStrength) : ""
                    title: root.activeNet ? root.activeNet.name : ""
                    line1: root.activeNet ? Math.round(root.activeNet.signalStrength * 100) + "% · " + WifiSecurityType.toString(root.activeNet.security) : ""
                    line2: root.wifiDev ? (wifiIp.ip !== "" ? wifiIp.ip + " · " : "") + root.wifiDev.name : ""
                }

                Label {
                    Layout.fillWidth: true
                    visible: !root.anyConnection
                    text: !Networking.wifiHardwareEnabled ? I18n.tr("Wi‑Fi is disabled by a hardware switch")
                        : !Networking.wifiEnabled ? I18n.tr("Wi‑Fi is off")
                        : I18n.tr("Not connected")
                    muted: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: root.anyConnection
                    spacing: 12

                    RateChart {
                        caption: "↓"
                        tint: Theme.magma
                        rate: SysStats.netRx
                        history: SysStats.netRxHistory
                    }

                    RateChart {
                        caption: "↑"
                        tint: Theme.sulfur
                        rate: SysStats.netTx
                        history: SysStats.netTxHistory
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: root.badConnectivity
                    spacing: 8

                    Glyph {
                        text: Icons.glyph("alert-triangle")
                        color: Theme.sulfur
                    }

                    Label {
                        Layout.fillWidth: true
                        text: root.connectivityText()
                        small: true
                        color: Theme.sulfur
                        elide: Text.ElideNone
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }

        // ---- networks ----------------------------------------------------------------------
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            visible: Networking.wifiEnabled

            SectionHeader {
                Layout.fillWidth: true
                text: I18n.tr("Networks")

                Label {
                    visible: root.networkList.length > 0
                    text: root.networkList.length
                    small: true
                    muted: true
                }
            }

            Label {
                Layout.fillWidth: true
                Layout.leftMargin: 10
                visible: root.networkList.length === 0
                text: root.wifiDev ? I18n.tr("Scanning for networks…") : I18n.tr("No Wi‑Fi adapter")
                muted: true
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(netCol.implicitHeight, 300)
                visible: root.networkList.length > 0

                Flickable {
                    id: flick
                    anchors.fill: parent
                    contentWidth: width
                    contentHeight: netCol.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: netCol
                        width: flick.width
                        spacing: 2

                        Repeater {
                            model: ScriptModel {
                                values: root.networkList
                            }

                            delegate: ColumnLayout {
                                id: row

                                required property var modelData
                                readonly property var net: modelData
                                readonly property bool open: root.isOpen(net.security)
                                readonly property bool showPsk: root.pskTarget === net.name
                                property string failText: ""
                                property bool pskVisible: false
                                property real revealH: showPsk ? 46 : 0

                                Layout.fillWidth: true
                                spacing: 0

                                Behavior on revealH {
                                    NumberAnimation {
                                        duration: Theme.animFast
                                        easing.type: Easing.OutCubic
                                    }
                                }

                                onRevealHChanged: if (showPsk) root.ensureVisible(row)

                                onShowPskChanged: {
                                    if (showPsk)
                                        input.forceActiveFocus();
                                    else {
                                        input.text = "";
                                        pskVisible = false;
                                    }
                                }

                                readonly property bool pskValid: net.security === WifiSecurityType.StaticWep ? input.text.length >= 5 : input.text.length >= 8

                                function submit() {
                                    if (!pskValid)
                                        return;
                                    failText = "";
                                    net.connectWithPsk(input.text);
                                    root.pskTarget = "";
                                }

                                function activate() {
                                    if (net.connected)
                                        return;
                                    failText = "";
                                    if (net.known || open) {
                                        root.pskTarget = "";
                                        net.connect();
                                    } else if (root.usesPsk(net.security)) {
                                        root.pskTarget = showPsk ? "" : net.name;
                                    } else {
                                        failText = I18n.tr("Enterprise network – set it up in nmtui");
                                    }
                                }

                                Connections {
                                    target: row.net

                                    function onConnectionFailed(reason) {
                                        row.failText = root.failReasonText(reason);
                                        if (reason === ConnectionFailReason.NoSecrets && root.usesPsk(row.net.security))
                                            root.pskTarget = row.net.name;
                                    }

                                    function onConnectedChanged() {
                                        if (row.net.connected)
                                            row.failText = "";
                                    }
                                }

                                ListItem {
                                    Layout.fillWidth: true
                                    icon: root.signalGlyph(row.net.signalStrength)
                                    iconColor: row.net.connected ? Theme.moss : Theme.text
                                    title: row.net.name
                                    subtitle: row.net.connected ? I18n.tr("Connected") : row.net.known ? I18n.tr("Saved") : WifiSecurityType.toString(row.net.security)
                                    highlighted: row.net.connected
                                    busy: row.net.stateChanging
                                    clickable: !row.net.connected
                                    onClicked: row.activate()

                                    Label {
                                        height: 26
                                        text: Math.round(row.net.signalStrength * 100) + "%"
                                        small: true
                                        muted: true
                                    }

                                    Glyph {
                                        visible: !row.open
                                        height: 26
                                        text: Icons.glyph("lock")
                                        size: 14
                                        color: Theme.ash
                                    }

                                    IconButton {
                                        visible: row.net.connected
                                        width: 26
                                        height: 26
                                        icon: Icons.glyph("link-off")
                                        iconColor: Theme.ash
                                        onClicked: row.net.disconnect()
                                    }
                                }

                                Label {
                                    Layout.fillWidth: true
                                    Layout.leftMargin: 40
                                    Layout.rightMargin: 10
                                    Layout.bottomMargin: 4
                                    visible: row.failText !== ""
                                    text: row.failText
                                    small: true
                                    color: Theme.fire
                                    elide: Text.ElideNone
                                    wrapMode: Text.WordWrap
                                }

                                Item {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: row.revealH
                                    visible: row.revealH > 0.5
                                    clip: true

                                    RowLayout {
                                        x: 10
                                        y: 4
                                        width: parent.width - 20
                                        height: 36
                                        spacing: 8

                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            radius: 10
                                            color: Theme.lava
                                            border.width: 1
                                            border.color: input.activeFocus ? Theme.magma : Theme.obsidian

                                            Behavior on border.color {
                                                ColorAnimation { duration: Theme.animFast }
                                            }

                                            TextInput {
                                                id: input
                                                anchors.fill: parent
                                                anchors.leftMargin: 12
                                                anchors.rightMargin: 36
                                                verticalAlignment: TextInput.AlignVCenter
                                                clip: true
                                                echoMode: row.pskVisible ? TextInput.Normal : TextInput.Password
                                                passwordCharacter: "•"
                                                color: Theme.text
                                                selectionColor: Theme.magma
                                                selectedTextColor: Theme.basalt
                                                font.family: Theme.font
                                                font.pixelSize: Theme.fontSize
                                                font.weight: Font.Medium
                                                onAccepted: row.submit()
                                                Keys.onEscapePressed: root.pskTarget = ""

                                                Label {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    visible: input.text === ""
                                                    text: I18n.tr("Password")
                                                    muted: true
                                                }
                                            }

                                            IconButton {
                                                anchors.right: parent.right
                                                anchors.rightMargin: 4
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 26
                                                height: 26
                                                icon: Icons.glyph(row.pskVisible ? "eye-off" : "eye")
                                                iconColor: Theme.ash
                                                onClicked: row.pskVisible = !row.pskVisible
                                            }
                                        }

                                        Rectangle {
                                            Layout.fillHeight: true
                                            implicitWidth: connectLabel.implicitWidth + 28
                                            radius: 10
                                            color: !row.pskValid ? Theme.obsidian : connectArea.containsMouse ? Theme.ember : Theme.magma

                                            Behavior on color {
                                                ColorAnimation { duration: Theme.animFast }
                                            }

                                            Label {
                                                id: connectLabel
                                                anchors.centerIn: parent
                                                text: I18n.tr("Connect")
                                                color: row.pskValid ? Theme.basalt : Theme.ashDim
                                                font.weight: Font.Bold
                                            }

                                            MouseArea {
                                                id: connectArea
                                                anchors.fill: parent
                                                enabled: row.pskValid
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: row.submit()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    visible: flick.visibleArea.heightRatio < 1
                    x: parent.width - 3
                    y: flick.visibleArea.yPosition * parent.height
                    width: 3
                    height: flick.visibleArea.heightRatio * parent.height
                    radius: 1.5
                    color: Theme.obsidian
                }
            }
        }

        // ---- footer ------------------------------------------------------------------------
        FooterLink {
            text: I18n.tr("Advanced… (%1)", "nmtui")
            command: ["kitty", "-e", "nmtui"]
            dropdown: root.dropdown
        }
    }
}
