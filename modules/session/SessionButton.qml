import QtQuick
import QtQuick.Shapes
import qs.config
import qs.widgets

// Кнопка меню сеанса: значок в круге и подпись. Выбранная (мышью или стрелками)
// подсвечена; ждущая отсчёта — залита цветом ошибки, вокруг значка убывает кольцо.
Item {
    id: root

    required property var action
    property bool selected: false
    property bool pending: false
    property bool dimmed: false
    // 1 → 0 за время отсчёта.
    property real progress: 0

    signal hovered
    signal activated

    implicitWidth: 104
    implicitHeight: 112
    opacity: dimmed ? 0.4 : 1

    Behavior on opacity {
        NumberAnimation { duration: Theme.anim.normal }
    }

    // Подложка выбранной кнопки.
    Rectangle {
        anchors.fill: parent
        radius: Theme.radius.panel
        color: root.selected ? Theme.color.hover : "transparent"
        border.width: root.selected ? 1 : 0
        border.color: Theme.color.border

        Behavior on color {
            ColorAnimation { duration: Theme.anim.fast }
        }
    }

    Rectangle {
        id: circle

        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.spacing.md
        width: 60
        height: 60
        radius: width / 2
        color: root.pending ? Theme.color.error
            : area.pressed ? Theme.color.pressed
            : root.selected ? Theme.color.primary
            : Theme.color.surfaceVariant
        scale: area.pressed ? 0.94 : root.selected ? 1.06 : 1

        Behavior on color {
            ColorAnimation { duration: Theme.anim.normal }
        }
        Behavior on scale {
            NumberAnimation { duration: Theme.anim.normal; easing.type: Easing.OutBack }
        }

        SymbolIcon {
            anchors.centerIn: parent
            implicitSize: 24
            name: root.action.icon
            color: root.pending ? Theme.color.errorText
                : root.selected ? Theme.color.primaryText
                : Theme.color.text
        }

        // Кольцо отсчёта.
        Shape {
            anchors.centerIn: parent
            width: parent.width + 10
            height: parent.height + 10
            visible: root.pending
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: Theme.color.error
                strokeWidth: 3
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    centerX: (circle.width + 10) / 2
                    centerY: (circle.height + 10) / 2
                    radiusX: (circle.width + 10) / 2 - 2
                    radiusY: radiusX
                    startAngle: -90
                    sweepAngle: 360 * root.progress
                }
            }
        }
    }

    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: circle.bottom
        anchors.topMargin: Theme.spacing.md
        width: parent.width - Theme.spacing.xs * 2
        horizontalAlignment: Text.AlignHCenter
        text: root.action.name
        color: root.selected || root.pending ? Theme.color.text : Theme.color.textMuted
        font.weight: root.selected || root.pending ? Theme.font.medium : Theme.font.regular
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.hovered()
        onClicked: root.activated()
    }
}
