import QtQuick
import qs.config

Rectangle {
    id: root
    property alias text: input.text
    property string placeholder: "Поиск"
    property bool secret: false
    signal accepted
    implicitHeight: 38
    radius: Theme.radius.control
    color: Theme.color.surface
    border.width: input.activeFocus ? 1 : 0
    border.color: Theme.color.focus
    TextInput {
        id: input
        anchors.fill: parent
        anchors.margins: 10
        verticalAlignment: TextInput.AlignVCenter
        color: Theme.color.text
        selectionColor: Theme.color.selection
        font.family: Theme.font.family
        font.pixelSize: Theme.font.body
        echoMode: root.secret ? TextInput.Password : TextInput.Normal
        clip: true
        Accessible.name: root.placeholder
        onAccepted: root.accepted()
        Text {
            anchors.fill: parent
            verticalAlignment: Text.AlignVCenter
            text: root.placeholder
            color: Theme.color.textMuted
            font: input.font
            visible: !input.text && !input.preeditText
        }
    }
}
