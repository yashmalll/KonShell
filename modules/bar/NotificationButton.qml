import QtQuick
import qs.config
import qs.services
import qs.widgets

// Колокольчик с числом уведомлений. Левый клик открывает историю,
// правый переключает «не беспокоить».
Item {
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Row {
        id: row

        spacing: Theme.spacing.xs

        SymbolIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: Notifications.dnd ? "notifications-disabled-symbolic" : "preferences-system-notifications-symbolic"
            color: Notifications.count > 0 && !Notifications.dnd ? Theme.color.primary : Theme.color.text
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: Notifications.count
            visible: Notifications.count > 0
            font.pixelSize: Theme.font.caption
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -Theme.spacing.xs
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                Notifications.setDnd(!Notifications.dnd);
            else
                Notifications.centerOpen = !Notifications.centerOpen;
        }
    }
}
