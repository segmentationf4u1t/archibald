import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs
import qs.components

// Audio dropdown: default output / input (mute, volume, live level, device switch) and per-app playback volumes.
Item {
    id: root

    property var dropdown

    readonly property var allNodes: Pipewire.nodes.values

    // Only the nodes listed below are bound, and only they are read: binding a node fetches its
    // properties and params and binds its device (whose routes and props cost more still).
    // The class comes from the node's type, which is known before the node is bound; reading
    // `properties` for it would re-run the filters whenever any node's properties change.
    readonly property var audioNodes: {
        const nodes = [];
        for (const n of root.allNodes) {
            if (n.type === PwNodeType.AudioSink || n.type === PwNodeType.AudioSource || n.type === PwNodeType.AudioOutStream)
                nodes.push(n);
        }
        return nodes;
    }
    readonly property var sinks: audioNodes.filter(n => n.type === PwNodeType.AudioSink)
    readonly property var sources: audioNodes.filter(n => n.type === PwNodeType.AudioSource && !n.name.endsWith(".monitor"))
    readonly property var streams: audioNodes.filter(n => n.type === PwNodeType.AudioOutStream)

    implicitWidth: 380
    implicitHeight: col.implicitHeight

    PwObjectTracker {
        objects: root.audioNodes
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
        // linear peak -> 0..1 on a -60..0 dB scale, sampled at 30 Hz (levelTimer): PwNodePeakMonitor
        // updates its peak for every audio buffer, more often than a meter needs, and each update repainted it
        property real level: 0

        function volumeIcon() {
            if (input)
                return Icons.glyph(muted ? "microphone-off" : "microphone");
            return Icons.volume(volume, muted || volume <= 0);
        }

        function deviceIcon(n) {
            const p = n.properties;
            const api = p["device.api"] ?? "";
            const form = p["device.form-factor"] ?? "";
            const text = ((n.description ?? "") + " " + (n.name ?? "")).toLowerCase();
            if (input)
                return Icons.glyph("microphone");
            if (api === "bluez5" || n.name.startsWith("bluez_") || form === "headphone" || form === "headset" || form === "hands-free")
                return Icons.glyph("headphones");
            if (text.includes("hdmi") || text.includes("displayport") || text.includes("display port") || form === "hdmi" || form === "tv")
                return Icons.glyph("device-desktop");
            return Icons.glyph("device-speaker");
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

        Timer {
            id: levelTimer
            interval: 33
            repeat: true
            running: monitor.enabled
            onTriggered: {
                const p = monitor.peak;
                const next = p > 0.001 ? Math.max(0, Math.min(1, 1 + 20 * Math.log(p) / Math.LN10 / 60)) : 0;
                // The meter is levelMeter.width pixels wide: a change within the same pixel is invisible.
                if (levelMeter.width > 0 && Math.round(next * levelMeter.width) === Math.round(ch.level * levelMeter.width))
                    return;
                ch.level = next;
            }
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
                id: levelMeter

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
        // Tabler icon of the app (by desktop icon name, binary, name); unknown apps get a note
        readonly property string icon: node ? Icons.app([node.properties["application.icon-name"], node.properties["application.process.binary"], node.properties["application.name"]], "music") : ""

        spacing: 10

        Glyph {
            Layout.preferredWidth: 24
            Layout.preferredHeight: 24
            Layout.alignment: Qt.AlignVCenter
            text: row.icon
            size: 20
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
            icon: Icons.glyph(row.muted ? "volume-3" : "volume")
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
