import QtQuick
import qs.config

// Выбор одного варианта из нескольких: выбранный отмечен заливкой и галочкой,
// не только цветом. Клик, Enter или пробел вызывают clicked().
Rectangle {
    id: chip

    property alias text: label.text
    property bool checked: false

    signal clicked

    implicitWidth: row.implicitWidth + Theme.spacing.md * 2
    implicitHeight: 30
    radius: Theme.radius.control
    color: checked ? Theme.color.active
        : chipArea.containsMouse ? Theme.color.hover
        : "transparent"
    border.width: checked ? 0 : 1
    border.color: Theme.color.border

    activeFocusOnTab: true
    Keys.onReturnPressed: clicked()
    Keys.onEnterPressed: clicked()
    Keys.onSpacePressed: clicked()

    Row {
        id: row

        anchors.centerIn: parent
        spacing: Theme.spacing.xs

        SymbolIcon {
            anchors.verticalCenter: parent.verticalCenter
            implicitSize: 12
            name: "object-select-symbolic"
            color: Theme.color.activeText
            visible: chip.checked
        }

        StyledText {
            id: label

            anchors.verticalCenter: parent.verticalCenter
            color: chip.checked ? Theme.color.activeText : Theme.color.text
            font.pixelSize: Theme.font.caption
            font.weight: chip.checked ? Theme.font.medium : Theme.font.regular
        }
    }

    MouseArea {
        id: chipArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: chip.clicked()
    }

    FocusRing {}
}
