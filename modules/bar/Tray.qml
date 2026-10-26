import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs.config
import qs.widgets

// Трей: значки, закреплённые на панели (tray.pinned), и кнопка, открывающая
// остальные во всплывающем окне. Где показывать каждый значок — на панели,
// в трее или нигде — «Настройки KonShell» → «Панель» → «Трей».
Row {
    id: root

    // Значки, которые вообще показываются: не пассивные (если так настроено) и не скрытые.
    readonly property var items: SystemTray.items.values.filter(item =>
        (!Settings.tray.hidePassive || item.status !== Status.Passive)
        && !Settings.tray.hidden.includes(item.id))
    // На панели — в порядке списка tray.pinned.
    readonly property var pinnedItems: Settings.tray.pinned
        .map(id => items.find(item => item.id === id))
        .filter(item => item !== undefined)
    readonly property var trayItems: items.filter(item => !Settings.tray.pinned.includes(item.id))

    property bool popupOpen: false
    property real dismissedAt: 0

    spacing: Theme.spacing.sm

    Repeater {
        model: ScriptModel {
            values: root.pinnedItems
        }

        TrayIcon {
            required property SystemTrayItem modelData

            anchors.verticalCenter: parent.verticalCenter
            item: modelData
        }
    }

    // Кнопка трея: стрелка, повёрнутая вверх, пока окно открыто.
    Rectangle {
        id: button

        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: 22
        implicitHeight: 22
        radius: Theme.radius.full
        visible: root.trayItems.length > 0 || root.popupOpen
        color: root.popupOpen ? Theme.color.active
            : buttonArea.containsMouse ? Theme.color.hover
            : "transparent"

        Behavior on color {
            ColorAnimation { duration: Theme.anim.fast }
        }

        SymbolIcon {
            anchors.centerIn: parent
            implicitSize: 14
            name: "pan-down-symbolic"
            color: root.popupOpen ? Theme.color.activeText : Theme.color.text
            rotation: root.popupOpen ? 180 : 0

            Behavior on rotation {
                NumberAnimation { duration: Theme.anim.normal; easing.type: Theme.anim.enter }
            }
        }

        MouseArea {
            id: buttonArea

            anchors.fill: parent
            anchors.margins: -Theme.spacing.xxs
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (Date.now() - root.dismissedAt > 300)
                    root.popupOpen = !root.popupOpen;
            }
        }
    }

    LazyLoader {
        active: root.popupOpen

        TrayPopup {
            anchor.item: button
            items: root.trayItems
            onDismissed: {
                root.dismissedAt = Date.now();
                root.popupOpen = false;
            }
        }
    }
}
