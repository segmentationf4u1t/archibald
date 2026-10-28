import QtQuick
import QtQuick.Shapes
import qs

// History chart: filled area + line, drawn by the Qt Quick scene graph (Shape -> GPU geometry).
// `values` is a plain JS array; the newest sample is last. Up to `capacity` samples fill the width.
Item {
    id: root

    property var values: []
    property int capacity: 60
    property real maxValue: 100      // <= 0: scale to the data
    property color color: Theme.magma
    property real lineWidth: 1.5
    property real fillOpacity: 0.32
    property int gridLines: 3

    readonly property real scaleMax: {
        if (maxValue > 0) return maxValue;
        let m = 0;
        for (const v of values) m = Math.max(m, v);
        return m > 0 ? m * 1.15 : 1;
    }

    readonly property var linePoints: {
        const n = values.length;
        const pts = [];
        if (n === 0 || width <= 0 || height <= 0) return pts;
        const step = width / Math.max(1, capacity - 1);
        const x0 = width - (n - 1) * step;
        const h = height - lineWidth;
        for (let i = 0; i < n; i++) {
            const v = Math.max(0, Math.min(values[i] / scaleMax, 1));
            pts.push(Qt.point(x0 + i * step, lineWidth / 2 + h * (1 - v)));
        }
        return pts;
    }

    readonly property var areaPoints: {
        const pts = linePoints;
        if (pts.length === 0) return pts;
        return [Qt.point(pts[0].x, height)].concat(pts, [Qt.point(pts[pts.length - 1].x, height)]);
    }

    implicitHeight: 72

    Repeater {
        model: root.gridLines
        delegate: Rectangle {
            required property int index
            width: root.width
            height: 1
            y: Math.round(root.height * (index + 1) / (root.gridLines + 1))
            color: Theme.alpha(Theme.obsidian, 0.6)
        }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        visible: root.linePoints.length > 1

        ShapePath {
            strokeColor: "transparent"
            fillGradient: LinearGradient {
                x1: 0; y1: 0
                x2: 0; y2: root.height
                GradientStop { position: 0; color: Theme.alpha(root.color, root.fillOpacity) }
                GradientStop { position: 1; color: Theme.alpha(root.color, 0) }
            }
            PathPolyline { path: root.areaPoints }
        }

        ShapePath {
            strokeColor: root.color
            strokeWidth: root.lineWidth
            fillColor: "transparent"
            joinStyle: ShapePath.RoundJoin
            capStyle: ShapePath.RoundCap
            PathPolyline { path: root.linePoints }
        }
    }
}
