import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import qs.config
import qs.services
import qs.widgets

Column {
    id: root
    property real maximumHeight: 480
    spacing: 14

    RowLayout {
        width: parent.width
        StyledText {
            text: Notifications.count ? `Уведомления · ${Notifications.count}` : "Уведомления"
            font.pixelSize: Theme.font.title
            font.weight: Font.DemiBold
            Layout.fillWidth: true
        }
        TextButton {
            text: "Очистить"
            enabled: Notifications.count > 0
            onClicked: Notifications.clearAll()
        }
    }
    RowLayout {
        width: parent.width
        StyledText {
            text: "Не беспокоить"
            color: Theme.color.textMuted
            Layout.fillWidth: true
        }
        Switch {
            checked: Notifications.dnd
            Accessible.name: "Не беспокоить"
            onToggled: Notifications.setDnd(!Notifications.dnd)
        }
    }
    ListView {
        width: parent.width
        height: Math.min(contentHeight, Math.max(80, root.maximumHeight - 90))
        visible: count > 0
        clip: true
        spacing: 8
        boundsBehavior: Flickable.StopAtBounds
        model: ScriptModel {
            values: Notifications.history
        }
        delegate: NotificationCard {
            required property Notification modelData
            notification: modelData
            width: ListView.view.width
        }
    }
    StyledText {
        width: parent.width
        height: 100
        visible: Notifications.count === 0
        text: Notifications.dnd ? "Тихий режим включён. Здесь появится история уведомлений." : "Пока всё спокойно — уведомлений нет"
        wrapMode: Text.Wrap
        horizontalAlignment: Text.AlignHCenter
        color: Theme.color.textMuted
    }
}
