import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import qs
import qs.components

// Audio dropdown: default output / input (mute, volume, live level, device switch) and per-app playback volumes.
Item {
    id: root

    property var dropdown

    // Every node we read `audio` / `properties` from must be bound.
    readonly property var allNodes: Pipewire.nodes.values

    function mediaClass(n) {
        return n.properties["media.class"] ?? "";
    }

    readonly property var sinks: allNodes.filter(n => n.audio && n.isSink && !n.isStream && mediaClass(n).startsWith("Audio/Sink"))
    readonly property var sources: allNodes.filter(n => n.audio && !n.isSink && !n.isStream && mediaClass(n).startsWith("Audio/Source") && !n.name.endsWith(".monitor"))
    readonly property var streams: allNodes.filter(n => n.audio && n.isStream && mediaClass(n) === "Stream/Output/Audio")

    implicitWidth: 380
    implicitHeight: col.implicitHeight

    PwObjectTracker {
        objects: root.allNodes
    }

    ScriptModel {
        id: streamModel
        values: root.streams
    }

    // ---- inline components -------------------------------------------------------------------

    component Channel: ColumnLayout {
        id: ch

        property string title: ""
        property bool input: false
        property var node: null              // the default device
        property var devices: []
        property string emptyText: ""
        signal pick(var device)

        readonly property var audio: node ? node.audio : null
        readonly property bool muted: audio ? audio.muted : false
        readonly property real volume: audio ? audio.volume : 0
        readonly property real level: {
            // linear peak -> 0..1 on a -60..0 dB scale
            const p = monitor.peak;
            return p > 0.001 ? Math.max(0, Math.min(1, 1 + 20 * Math.log(p) / Math.LN10 / 60)) : 0;
        }

        function volumeIcon() {
            if (input)
                return muted ? "󰍭" : "󰍬";
            if (muted || volume <= 0)
                return "󰖁";
            return volume < 0.34 ? "󰕿" : volume < 0.67 ? "󰖀" : "󰕾";
        }

        function deviceIcon(n) {
            const p = n.properties;
            const api = p["device.api"] ?? "";
            const form = p["device.form-factor"] ?? "";
            const text = ((n.description ?? "") + " " + (n.name ?? "")).toLowerCase();
            if (input)
                return "󰍬";
            if (api === "bluez5" || n.name.startsWith("bluez_") || form === "headphone" || form === "headset" || form === "hands-free")
                return "󰋋";
            if (text.includes("hdmi") || text.includes("displayport") || text.includes("display port") || form === "hdmi" || form === "tv")
                return "󰍹";
            return "󰓃";
        }

        function fullName(n) {
            return n.description || n.nickname || n.name;
        }

        // "... Digital Stereo (HDMI) [BenQ GW2470]" -> "HDMI · BenQ GW2470"; drops the "Analog/Digital Stereo" noise.
        function shortName(n) {
            const d = fullName(n);
            const hdmi = /\((HDMI|DisplayPort)[^)]*\)\s*\[(.+)\]\s*$/.exec(d);
            if (hdmi)
                return hdmi[1] + " · " + hdmi[2];
            return d.replace(/ (Analog|Digital) Stereo/, "").replace(/ Mono$/, "");
        }

        // secondary line: the sound card behind an HDMI output
        function detail(n) {
            const d = fullName(n);
            return /\((HDMI|DisplayPort)[^)]*\)\s*\[.+\]\s*$/.test(d) ? d.replace(/ (Analog|Digital) Stereo.*$/, "") : "";
        }

        spacing: 8

        PwNodePeakMonitor {
            id: monitor
            node: ch.node
            enabled: ch.node ? true : false
        }

        SectionHeader {
            Layout.fillWidth: true
            text: ch.title

            IconButton {
                icon: ch.volumeIcon()
                checked: ch.muted
                enabled: ch.audio !== null
                implicitWidth: 28
                implicitHeight: 28
                onClicked: ch.audio.muted = !ch.audio.muted
            }
        }

        Label {
            Layout.fillWidth: true
            visible: !ch.node
            text: ch.emptyText
            muted: true
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: ch.node ? true : false
            spacing: 6

            Label {
                Layout.fillWidth: true
                text: ch.node ? ch.shortName(ch.node) : ""
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Slider {
                    Layout.fillWidth: true
                    value: ch.volume
                    color: ch.muted ? Theme.fire : Theme.magma
                    enabled: ch.audio !== null
                    onMoved: v => ch.audio.volume = v
                }

                Label {
                    Layout.preferredWidth: 38
                    horizontalAlignment: Text.AlignRight
                    text: Math.round(ch.volume * 100) + "%"
                    color: ch.muted ? Theme.fire : Theme.text
                }
            }

            Meter {
                Layout.fillWidth: true
                Layout.preferredHeight: 4
                implicitHeight: 4
                value: ch.muted ? 0 : ch.level
                fillColor: ch.level > 0.95 ? Theme.fire : ch.level > 0.85 ? Theme.sulfur : Theme.moss
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: ch.devices.length > 1
            spacing: 2

            Repeater {
                model: ScriptModel {
                    values: ch.devices
                }

                ListItem {
                    required property var modelData

                    Layout.fillWidth: true
                    icon: ch.deviceIcon(modelData)
                    title: ch.shortName(modelData)
                    subtitle: ch.detail(modelData)
                    highlighted: ch.node ? modelData.id === ch.node.id : false
                    onClicked: ch.pick(modelData)
                }
            }
        }
    }

    component StreamRow: RowLayout {
        id: row

        property var node: null

        readonly property var audio: node ? node.audio : null
        readonly property bool muted: audio ? audio.muted : false
        readonly property real volume: audio ? audio.volume : 0
        readonly property string appName: node ? (node.properties["application.name"] || node.nickname || node.description || node.name) : ""
        readonly property string mediaName: {
            const m = node ? (node.properties["media.name"] ?? "") : "";
            return m === appName || m === "Playback" || m === "playback" || m === "Audio Stream" ? "" : m;
        }
        readonly property string iconName: node ? (node.properties["application.icon-name"] ?? "") : ""
        readonly property string iconSource: iconName !== "" ? Quickshell.iconPath(iconName, true) : ""

        spacing: 10

        Item {
            Layout.preferredWidth: 24
            Layout.preferredHeight: 24
            Layout.alignment: Qt.AlignVCenter

            IconImage {
                anchors.fill: parent
                visible: row.iconSource !== ""
                source: row.iconSource
            }

            Glyph {
                anchors.centerIn: parent
                visible: row.iconSource === ""
                text: "󰎆"
                color: Theme.ash
                size: 20
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Label {
                    text: row.appName
                    elide: Text.ElideRight
                    Layout.maximumWidth: 150
                }

                Label {
                    Layout.fillWidth: true
                    visible: row.mediaName !== ""
                    text: row.mediaName
                    small: true
                    muted: true
                }

                Item {
                    Layout.fillWidth: true
                    visible: row.mediaName === ""
                }

                Label {
                    text: Math.round(row.volume * 100) + "%"
                    small: true
                    color: row.muted ? Theme.fire : Theme.ash
                }
            }

            Slider {
                Layout.fillWidth: true
                value: row.volume
                color: row.muted ? Theme.fire : Theme.magma
                enabled: row.audio !== null
                onMoved: v => row.audio.volume = v
            }
        }

        IconButton {
            icon: row.muted ? "󰖁" : "󰕾"
            checked: row.muted
            enabled: row.audio !== null
            implicitWidth: 28
            implicitHeight: 28
            Layout.alignment: Qt.AlignVCenter
            onClicked: row.audio.muted = !row.audio.muted
        }
    }

    // ---- content -----------------------------------------------------------------------------

    ColumnLayout {
        id: col

        width: parent.width
        spacing: 14

        Channel {
            Layout.fillWidth: true
            title: I18n.tr("Output")
            node: Pipewire.defaultAudioSink
            devices: root.sinks
            emptyText: I18n.tr("No output device")
            onPick: d => Pipewire.preferredDefaultAudioSink = d
        }

        Channel {
            Layout.fillWidth: true
            title: I18n.tr("Input")
            input: true
            node: Pipewire.defaultAudioSource
            devices: root.sources
            emptyText: I18n.tr("No input device")
            onPick: d => Pipewire.preferredDefaultAudioSource = d
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            SectionHeader {
                Layout.fillWidth: true
                text: I18n.tr("Applications")
            }

            Label {
                Layout.fillWidth: true
                visible: root.streams.length === 0
                text: I18n.tr("Nothing is playing")
                muted: true
            }

            Repeater {
                model: streamModel

                StreamRow {
                    required property var modelData

                    Layout.fillWidth: true
                    node: modelData
                }
            }
        }

        FooterLink {
            text: I18n.tr("Advanced… (%1)", "pavucontrol")
            command: ["pavucontrol"]
            dropdown: root.dropdown
        }
    }
}
