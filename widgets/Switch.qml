import QtQuick
import qs.config

// Переключатель вкл/выкл. Состояние задаётся снаружи, клик, Enter или пробел вызывают toggled().
// Выключенный — контур без заливки, чтобы состояние читалось не только по цвету.
Rectangle {
    id: root

    property bool checked: false

    signal toggled

    implicitWidth: 36
    implicitHeight: 20
    radius: Theme.radius.full
    color: checked ? Theme.color.primary : "transparent"
    border.width: checked ? 0 : 1.5
    border.color: Theme.color.outline

    Behavior on color {
        ColorAnimation { duration: Theme.anim.fast }
    }

    activeFocusOnTab: true
    Keys.onReturnPressed: toggled()
    Keys.onEnterPressed: toggled()
    Keys.onSpacePressed: toggled()

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? parent.width - width - 4 : 4
        width: root.checked ? 12 : 10
        height: width
        radius: Theme.radius.full
        color: root.checked ? Theme.color.primaryText : Theme.color.outline

        Behavior on x {
            NumberAnimation { duration: Theme.anim.fast; easing.type: Theme.anim.enter }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }

    FocusRing {}
}
