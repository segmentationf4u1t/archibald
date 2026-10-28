import QtQuick
import QtQuick.Shapes
import qs

// Small busy indicator: a rotating arc.
Item {
    id: root

    property bool running: true
    property color color: Theme.magma
    property real size: 16

    implicitWidth: size
    implicitHeight: size

    Shape {
        id: arc
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.color
            strokeWidth: 2
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.size / 2
                centerY: root.size / 2
                radiusX: root.size / 2 - 1
                radiusY: root.size / 2 - 1
                startAngle: 0
                sweepAngle: 270
            }
        }

        RotationAnimator on rotation {
            running: root.running && root.visible
            from: 0
            to: 360
            duration: 900
            loops: Animation.Infinite
        }
    }
}
