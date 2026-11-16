import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services
import qs.widgets
import "../../config/island-summary.js" as Summary

Column {
    id: root
    readonly property var nextEvent: Summary.nextEvent(Events.events, clock.date.getTime())
    spacing: 8
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
    SummaryRow {
        width: parent.width
        visible: root.nextEvent !== null
        icon: "x-office-calendar-symbolic"
        title: root.nextEvent?.title || ""
        subtitle: Summary.eventLabel(root.nextEvent, clock.date.getTime())
        onClicked: Ui.openDashboard(false)
    }
    SummaryRow {
        width: parent.width
        visible: Notifications.count > 0
        icon: "preferences-system-notifications-symbolic"
        title: Summary.notificationLabel(Notifications.count)
        subtitle: [...new Set(Notifications.history.map(n => n.appName || "Приложение"))].slice(0, 3).join(" · ")
        onClicked: Notifications.centerOpen = true
    }
    Repeater {
        model: ScriptModel {
            values: BluetoothState.connectedDevices
        }
        SummaryRow {
            required property var modelData
            width: root.width
            icon: (modelData.icon || "bluetooth").replace(/-symbolic$/, "") + "-symbolic"
            title: modelData.name || modelData.address
            subtitle: modelData.batteryAvailable ? `Заряд ${Math.round(modelData.battery * 100)}%` : "Подключено по Bluetooth"
            onClicked: {
                Ui.controlCenterPage = "bluetooth";
                Ui.controlCenterOpen = true;
            }
        }
    }
    Repeater {
        model: Jobs.jobs
        Rectangle {
            id: jobCard
            required property var modelData
            width: root.width
            implicitHeight: jobBody.implicitHeight + 20
            color: Theme.color.surface
            radius: Theme.radius.control
            Column {
                id: jobBody
                x: 12
                y: 10
                width: parent.width - 24
                spacing: 6
                StyledText {
                    width: parent.width
                    text: jobCard.modelData.title
                    elide: Text.ElideRight
                }
                StyledText {
                    width: parent.width
                    font.pixelSize: Theme.font.caption
                    color: Theme.color.textMuted
                    text: jobCard.modelData.app + (jobCard.modelData.suspended ? " · Приостановлено" : jobCard.modelData.percent >= 0 ? ` · ${jobCard.modelData.percent}%` : " · Выполняется…")
                    elide: Text.ElideRight
                }
                Rectangle {
                    width: parent.width
                    height: 3
                    radius: 1.5
                    color: Theme.alpha(Theme.color.text, 0.12)
                    visible: jobCard.modelData.percent >= 0
                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, jobCard.modelData.percent / 100))
                        height: parent.height
                        radius: parent.radius
                        color: Theme.color.primary
                    }
                }
            }
        }
    }
    component SummaryRow: Rectangle {
        id: row
        property string icon
        property string title
        property string subtitle
        signal clicked
        implicitHeight: 56
        radius: Theme.radius.control
        color: area.containsMouse ? Theme.color.hover : Theme.color.surface
        activeFocusOnTab: true
        Accessible.name: title + " · " + subtitle
        Accessible.role: Accessible.Button
        Keys.onReturnPressed: clicked()
        Keys.onSpacePressed: clicked()
        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10
            SymbolIcon {
                name: row.icon
                implicitSize: 18
            }
            Column {
                Layout.fillWidth: true
                StyledText {
                    width: parent.width
                    text: row.title
                    elide: Text.ElideRight
                }
                StyledText {
                    width: parent.width
                    text: row.subtitle
                    font.pixelSize: Theme.font.caption
                    color: Theme.color.textMuted
                    elide: Text.ElideRight
                }
            }
            SymbolIcon {
                name: "go-next-symbolic"
                implicitSize: 12
                color: Theme.color.textMuted
            }
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.clicked()
        }
        FocusRing {}
    }
}
