import QtQuick
import qs.config

// Горизонтальный ползунок 0..1. Значение задаётся снаружи; перетаскивание,
// клик, колесо и стрелки сообщают новое через moved().
Item {
    id: root

    property real value: 0
    property real step: 0.05

    signal moved(real value)

    readonly property real handleSize: 14
    readonly property real visualValue: Math.max(0, Math.min(1, value))

    function clamp(v) {
        return Math.max(0, Math.min(1, v));
    }

    function valueAt(x) {
        return clamp((x - handleSize / 2) / (width - handleSize));
    }

    implicitHeight: 20
    implicitWidth: 200

    activeFocusOnTab: true
    Keys.onLeftPressed: moved(clamp(value - step))
    Keys.onDownPressed: moved(clamp(value - step))
    Keys.onRightPressed: moved(clamp(value + step))
    Keys.onUpPressed: moved(clamp(value + step))

    // Дорожка тонкая: в минималистичном стиле главное — положение, а не сама полоса.
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 4
        radius: Theme.radius.full
        color: Theme.color.surfaceVariant

        Rectangle {
            width: handle.x + root.handleSize / 2
            height: parent.height
            radius: parent.radius
            color: Theme.color.primary
        }
    }

    Rectangle {
        id: handle

        anchors.verticalCenter: parent.verticalCenter
        x: root.visualValue * (root.width - root.handleSize)
        width: root.handleSize
        height: root.handleSize
        radius: Theme.radius.full
        color: Theme.color.primary
        scale: area.pressed ? 1.15 : 1

        Behavior on scale {
            NumberAnimation { duration: Theme.anim.fast; easing.type: Theme.anim.enter }
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        onPressed: mouse => root.moved(root.valueAt(mouse.x))
        onPositionChanged: mouse => {
            if (pressed)
                root.moved(root.valueAt(mouse.x));
        }
        onWheel: wheel => root.moved(root.clamp(root.value + (wheel.angleDelta.y > 0 ? root.step : -root.step)))
    }

    FocusRing {
        radius: Theme.radius.full
    }
}
