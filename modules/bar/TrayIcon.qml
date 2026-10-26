import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.config

// Один значок трея (StatusNotifierItem) — на панели или во всплывающем окне трея.
// Левый клик: действие приложения, средний: второе действие, правый: меню,
// колесо: прокрутка. У системных значков (сеть, Bluetooth и т. п.) и у значков
// «только меню» левый клик тоже открывает меню: действия у них обычно нет.
// В меню всегда есть пункты оболочки: показывать на панели или в трее, скрыть.
Item {
    id: root

    required property SystemTrayItem item
    property int size: Settings.tray.iconSize
    // Наведение — для подписи во всплывающем окне трея.
    readonly property bool hovered: area.containsMouse

    // Приложение получило клик (не меню) — окно трея закрывается.
    signal activated

    property bool menuOpen: false
    // Клик по значку при открытом меню сначала закрывает меню (grab),
    // и без этой отметки тот же клик открыл бы его снова.
    property real dismissedAt: 0

    readonly property bool menuOnLeftClick: item.onlyMenu
        || item.category === Category.SystemServices
        || item.category === Category.Hardware

    implicitWidth: size
    implicitHeight: size

    IconImage {
        anchors.fill: parent
        source: root.item.icon
    }

    MouseArea {
        id: area

        anchors.fill: parent
        anchors.margins: -Theme.spacing.xs
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton) {
                root.item.secondaryActivate();
                root.activated();
            } else if (mouse.button === Qt.RightButton || (root.menuOnLeftClick && root.item.hasMenu)) {
                if (Date.now() - root.dismissedAt > 300)
                    root.menuOpen = !root.menuOpen;
            } else {
                root.item.activate();
                root.activated();
            }
        }
        onWheel: wheel => {
            const horizontal = wheel.angleDelta.x !== 0;
            root.item.scroll(horizontal ? wheel.angleDelta.x : wheel.angleDelta.y, horizontal);
        }
    }

    LazyLoader {
        active: root.menuOpen

        TrayMenu {
            menu: root.item.hasMenu ? root.item.menu : null
            itemId: root.item.id
            anchor.item: root
            onDismissed: {
                root.dismissedAt = Date.now();
                root.menuOpen = false;
            }
        }
    }
}
