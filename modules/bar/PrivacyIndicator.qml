import QtQuick
import qs.config
import qs.services
import qs.widgets

Rectangle {
    property bool showWhenIdle: false
    implicitWidth: icons.implicitWidth + 16
    implicitHeight: 26
    radius: 13
    color: Theme.alpha(Theme.color.primary, 0.16)
    visible: Privacy.active || showWhenIdle
    Accessible.role: Accessible.Button
    Accessible.name: Privacy.active ? Privacy.summary : "Приватность: доступ к устройствам"
    Row {
        id: icons
        anchors.centerIn: parent
        spacing: 5
        SymbolIcon { name: "security-high-symbolic"; color: Theme.color.textMuted; visible: !Privacy.active }
        SymbolIcon { name: "microphone-sensitivity-high-symbolic"; color: Theme.color.primary; visible: Privacy.microphone }
        SymbolIcon { name: "camera-web-symbolic"; color: Theme.color.primary; visible: Privacy.camera }
        SymbolIcon { name: "video-display-symbolic"; color: Theme.color.primary; visible: Privacy.sharing }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Ui.openPrivacy()
    }
}
