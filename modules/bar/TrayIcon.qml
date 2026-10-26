import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.config

// Один значок трея (StatusNotifierItem) — на панели или во всплывающем окне трея.
// Левый клик: действие приложения, средний: второе действие, правый: меню
// самого приложения (как его рисует Qt), колесо: прокрутка. У системных значков
// (сеть, Bluetooth и т. п.) и у значков «только меню» левый клик тоже открывает
// меню: действия у них обычно нет. Где показывать значок — в настройках
// («Панель» → «Трей»).
Item {
    id: root

    required property SystemTrayItem item
    property int size: Settings.tray.iconSize
    // Наведение — для подсветки ячейки во всплывающем окне трея.
    readonly property bool hovered: area.containsMouse

    // Приложение получило клик (не меню) — окно трея закрывается.
    signal activated

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
                // Меню — под значком, координаты относительно окна панели или трея.
                if (root.item.hasMenu) {
                    const point = root.mapToItem(null, 0, root.height + Theme.spacing.xs);
                    root.item.display(root.QsWindow.window, point.x, point.y);
                }
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
}
