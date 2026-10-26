import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.services
import qs.widgets

// Значок приложения в доке. Под значком — индикатор: точки по числу окон (до трёх),
// полоса акцентного цвета — приложение в фокусе, цвет ошибки — окно просит внимания.
Item {
    id: root

    required property var item
    property int iconSize: 40

    property bool menuOpen: false
    // Клик по значку при открытом меню сначала закрывает меню (grab),
    // и без этой отметки тот же клик открыл бы его снова.
    property real dismissedAt: 0

    readonly property bool running: item.windows.length > 0
    readonly property bool focused: DockApps.isFocused(item)
    readonly property bool urgent: DockApps.isUrgent(item)
    readonly property bool launching: DockApps.isLaunching(item)
    readonly property bool hovered: area.containsMouse && !menuOpen

    readonly property string iconSource: item.icon.startsWith("/")
        ? "file://" + item.icon
        : Quickshell.iconPath(item.icon, "application-x-executable")

    implicitWidth: iconSize + Theme.spacing.xs * 2
    implicitHeight: iconSize + 6

    // Подложка под мышью.
    Rectangle {
        anchors.horizontalCenter: icon.horizontalCenter
        y: icon.y - Theme.spacing.xs
        width: root.iconSize + Theme.spacing.xs * 2
        height: width
        radius: Theme.radius.control + 2
        color: area.pressed ? Theme.color.pressed : Theme.color.hover
        opacity: area.containsMouse || root.menuOpen ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Theme.anim.fast }
        }
    }

    IconImage {
        id: icon

        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        implicitSize: root.iconSize
        source: root.iconSource
        asynchronous: true
        mipmap: true
        // Не запущенные закреплённые — чуть приглушены.
        opacity: root.running || root.launching ? 1 : 0.85

        transformOrigin: Item.Bottom
        scale: area.pressed ? 0.92 : root.hovered && Settings.dock.magnify ? 1.18 : 1
        transform: Translate {
            id: bounce
        }

        Behavior on scale {
            NumberAnimation { duration: Theme.anim.fast; easing.type: Easing.OutBack }
        }
    }

    // Пока приложение запускается — значок подпрыгивает.
    SequentialAnimation {
        running: root.launching && !Theme.reduceMotion
        loops: Animation.Infinite
        onRunningChanged: if (!running) bounce.y = 0

        NumberAnimation { target: bounce; property: "y"; to: -8; duration: 260; easing.type: Easing.OutQuad }
        NumberAnimation { target: bounce; property: "y"; to: 0; duration: 260; easing.type: Easing.InQuad }
        PauseAnimation { duration: 120 }
    }

    // Индикатор окон.
    Item {
        id: indicator

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: root.iconSize
        height: 4

        // Приложение в фокусе — полоса.
        Rectangle {
            anchors.centerIn: parent
            width: root.focused ? 16 : 0
            height: 4
            radius: Theme.radius.full
            color: root.urgent ? Theme.color.error : Theme.color.primary
            opacity: root.focused ? 1 : 0

            Behavior on width {
                NumberAnimation { duration: Theme.anim.normal; easing.type: Theme.anim.enter }
            }
            Behavior on opacity {
                NumberAnimation { duration: Theme.anim.fast }
            }
        }

        // Остальное — точки по числу окон.
        Row {
            anchors.centerIn: parent
            spacing: 3
            opacity: root.running && !root.focused ? 1 : 0

            Behavior on opacity {
                NumberAnimation { duration: Theme.anim.fast }
            }

            Repeater {
                model: Math.min(3, root.item.windows.length)

                Rectangle {
                    width: 4
                    height: 4
                    radius: 2
                    color: root.urgent ? Theme.color.error : Theme.color.textMuted
                }
            }
        }

        // Окно просит внимания — индикатор пульсирует.
        SequentialAnimation on opacity {
            running: root.urgent && !Theme.reduceMotion
            loops: Animation.Infinite
            onRunningChanged: if (!running) indicator.opacity = 1

            NumberAnimation { to: 0.3; duration: 500; easing.type: Easing.InOutQuad }
            NumberAnimation { to: 1; duration: 500; easing.type: Easing.InOutQuad }
        }
    }

    // Подсказка с названием над значком.
    Rectangle {
        id: tooltip

        anchors.horizontalCenter: parent.horizontalCenter
        y: -height - Theme.spacing.md - (Settings.dock.magnify ? root.iconSize * 0.18 : 0)
        width: tooltipText.implicitWidth + Theme.spacing.md * 2
        height: tooltipText.implicitHeight + Theme.spacing.xs * 2
        radius: Theme.radius.control
        color: Theme.color.popup
        border.width: Theme.borders ? 1 : 0
        border.color: Theme.color.border
        opacity: root.hovered ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation { duration: Theme.anim.fast }
        }

        StyledText {
            id: tooltipText

            anchors.centerIn: parent
            text: root.item.windows.length > 1 ? `${root.item.name} · ${root.item.windows.length}` : root.item.name
            font.pixelSize: Theme.font.caption
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                if (Date.now() - root.dismissedAt > 300)
                    root.menuOpen = !root.menuOpen;
            } else if (mouse.button === Qt.MiddleButton) {
                DockApps.launch(root.item);
            } else {
                DockApps.activate(root.item);
            }
        }
        // Колесо — окна приложения по очереди.
        onWheel: wheel => {
            if (root.running && wheel.angleDelta.y !== 0)
                DockApps.activate(root.item);
        }
    }

    LazyLoader {
        active: root.menuOpen

        DockMenu {
            item: root.item
            anchor.item: icon
            onDismissed: {
                root.dismissedAt = Date.now();
                root.menuOpen = false;
            }
        }
    }
}
