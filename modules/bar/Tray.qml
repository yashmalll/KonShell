import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.config

// Значки приложений в трее (StatusNotifierItem).
// Левый клик: действие приложения, средний: второе действие, правый: меню,
// колесо: прокрутка. У системных значков (сеть, Bluetooth и т. п.) и у значков
// «только меню» левый клик тоже открывает меню: действия у них обычно нет.
Row {
    id: root

    spacing: Theme.spacing.sm

    Repeater {
        model: ScriptModel {
            values: SystemTray.items.values.filter(item =>
                (!Settings.tray.hidePassive || item.status !== Status.Passive)
                && !Settings.tray.hidden.includes(item.id))
        }

        Item {
            id: trayItem

            required property SystemTrayItem modelData
            property bool menuOpen: false

            readonly property bool menuOnLeftClick: modelData.onlyMenu
                || modelData.category === Category.SystemServices
                || modelData.category === Category.Hardware

            // Клик по значку при открытом меню сначала закрывает меню (grab),
            // и без этой отметки тот же клик открыл бы его снова.
            property real dismissedAt: 0

            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: Settings.tray.iconSize
            implicitHeight: Settings.tray.iconSize

            IconImage {
                anchors.fill: parent
                source: trayItem.modelData.icon
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -Theme.spacing.xs
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor

                onClicked: mouse => {
                    const item = trayItem.modelData;
                    if (mouse.button === Qt.MiddleButton) {
                        item.secondaryActivate();
                    } else if (mouse.button === Qt.RightButton || trayItem.menuOnLeftClick) {
                        if (Date.now() - trayItem.dismissedAt > 300)
                            trayItem.menuOpen = item.hasMenu && !trayItem.menuOpen;
                    } else {
                        item.activate();
                    }
                }
                onWheel: wheel => {
                    const horizontal = wheel.angleDelta.x !== 0;
                    trayItem.modelData.scroll(horizontal ? wheel.angleDelta.x : wheel.angleDelta.y, horizontal);
                }
            }

            LazyLoader {
                active: trayItem.menuOpen

                TrayMenu {
                    menu: trayItem.modelData.menu
                    anchor.item: trayItem
                    onDismissed: {
                        trayItem.dismissedAt = Date.now();
                        trayItem.menuOpen = false;
                    }
                }
            }
        }
    }
}
