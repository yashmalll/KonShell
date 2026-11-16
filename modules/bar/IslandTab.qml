import QtQuick
import QtQuick.Layouts
import qs.config
import qs.widgets

Rectangle {
    id: root
    property string text
    property string icon
    property bool selected: false
    signal clicked
    Layout.fillWidth: true
    Layout.preferredWidth: 1
    Layout.minimumWidth: 0
    implicitHeight: 36
    radius: 12
    color: selected ? Theme.alpha(Theme.color.primary, 0.16)
        : hover.hovered ? Theme.color.hover : "transparent"
    Behavior on color { ColorAnimation { duration: Settings.theme.reduceMotion ? 0 : 240 / Math.max(0.25, Settings.theme.animationSpeed); easing.type: Easing.InOutSine } }
    activeFocusOnTab: true
    Accessible.role: Accessible.PageTab
    Accessible.name: text
    Keys.onReturnPressed: clicked()
    Keys.onEnterPressed: clicked()
    Keys.onSpacePressed: clicked()
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 7
        SymbolIcon {
            name: root.icon
            implicitSize: 16
            visible: root.width >= 125
            color: root.selected ? Theme.color.primary : Theme.color.textMuted
        }
        StyledText {
            text: root.text
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Theme.font.body
            font.weight: root.selected ? Font.DemiBold : Font.Normal
            color: root.selected ? Theme.color.primary : Theme.color.textMuted
        }
    }
    HoverHandler { id: hover }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
    FocusRing {}
}
