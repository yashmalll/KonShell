import QtQuick
import qs.config

// Кнопка-иконка без фона: подложка появляется при наведении и нажатии.
// Работает с клавиатуры: Tab, Enter или пробел.
Rectangle {
    id: root

    property string icon
    property int iconSize: 16
    property color iconColor: Theme.color.text
    // Для кнопок поверх акцентной заливки: слой берётся от цвета иконки.
    property color stateColor: Theme.color.text

    signal clicked

    implicitWidth: 28
    implicitHeight: 28
    radius: Theme.radius.full
    opacity: enabled ? 1 : 0.38
    color: area.pressed ? Theme.alpha(stateColor, 0.12)
        : area.containsMouse && enabled ? Theme.alpha(stateColor, 0.08)
        : "transparent"

    activeFocusOnTab: enabled
    Keys.onReturnPressed: clicked()
    Keys.onEnterPressed: clicked()
    Keys.onSpacePressed: clicked()

    SymbolIcon {
        anchors.centerIn: parent
        implicitSize: root.iconSize
        name: root.icon
        color: root.iconColor
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    FocusRing {}
}
