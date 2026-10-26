import QtQuick
import qs.config
import qs.services
import qs.widgets

// "English (US)" -> "EN", "Russian" -> "RU". Клик переключает раскладку.
StyledText {
    text: Niri.currentLayoutLabel
    color: Theme.color.textMuted
    font.pixelSize: Theme.font.caption
    font.weight: Theme.font.medium
    visible: Niri.keyboardLayouts.length > 1

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => Niri.switchLayout(mouse.button === Qt.LeftButton)
    }
}
