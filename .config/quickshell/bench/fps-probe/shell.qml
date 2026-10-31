// Frame-pacing probe for the isolated bench environment (not part of the bar): a small layer-shell
// panel with an endless animation that logs how many frames it swapped every second.
//   bench/env exec -- timeout 25 quickshell -p ~/.config/quickshell/bench/fps-probe
// A healthy nested output prints "FPS ~60" lines (the headless host's refresh rate).
import QtQuick
import Quickshell

ShellRoot {
    PanelWindow {
        id: w

        property int frames: 0

        anchors {
            top: true
            left: true
        }
        implicitWidth: 300
        implicitHeight: 200
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"

        Rectangle {
            x: 50
            y: 50
            width: 80
            height: 80
            color: "red"

            RotationAnimation on rotation {
                from: 0
                to: 360
                duration: 2000
                loops: Animation.Infinite
            }
        }

        Connections {
            target: w.contentItem.Window.window

            function onFrameSwapped() {
                w.frames++;
            }
        }

        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: {
                console.info("FPS " + w.frames);
                w.frames = 0;
            }
        }
    }
}
