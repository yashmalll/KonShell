import QtQuick
import qs.config
import qs.widgets

// Заголовок вложенной страницы: «назад», название и элемент справа.
Item {
    id: root

    property string title: ""
    default property alias trailing: trailingRow.data

    signal back

    width: parent?.width ?? 0
    implicitHeight: 32

    IconButton {
        id: backButton

        anchors.left: parent.left
        anchors.leftMargin: -Theme.spacing.xs
        anchors.verticalCenter: parent.verticalCenter
        icon: "go-previous-symbolic"
        Accessible.name: "Назад"
        onClicked: root.back()
    }

    StyledText {
        anchors.left: backButton.right
        anchors.leftMargin: Theme.spacing.xs
        anchors.verticalCenter: parent.verticalCenter
        text: root.title
        font.pixelSize: Theme.font.title
        font.weight: Theme.font.medium
    }

    Row {
        id: trailingRow

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacing.sm
    }
}
