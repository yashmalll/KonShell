import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// История уведомлений и переключатель «не беспокоить».
// Открывается кнопкой в панели или через IPC:
//   qs -c konshell ipc call notifications toggleCenter
Scope {
    id: root

    IpcHandler {
        target: "notifications"

        function toggleCenter(): void {
            Notifications.centerOpen = !Notifications.centerOpen;
        }
        function toggleDnd(): void {
            Notifications.setDnd(!Notifications.dnd);
        }
        function clear(): void {
            Notifications.clearAll();
        }
    }

    PopupLoader {
        id: popup

        open: Notifications.centerOpen

        PanelWindow {

            // Скрытое окно (PopupLoader.keepLoaded) не показывается, но и не удаляется.

            visible: popup.windowVisible

            screen: Quickshell.screens.find(s => s.name === Niri.focusedWorkspace?.output) ?? null
            WlrLayershell.namespace: "konshell-notification-center"
            // Размытие только под панелью, а не под всем прозрачным окном.
            BackgroundEffect.blurRegion: Region {
                item: panel.blurItem
                radius: Theme.radius.panel
            }

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: popup.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: "transparent"
            // Пока сворачивается — клики и клавиатура уже не перехватываются.
            mask: popup.open ? null : closedMask

            Region {
                id: closedMask
            }

            // Клик мимо панели (в том числе по кнопке в баре) закрывает её.
            MouseArea {
                anchors.fill: parent
                onClicked: Notifications.centerOpen = false
            }

            PopupSurface {
                id: panel

                shown: popup.open

                anchors.top: parent.top
                anchors.right: parent.right
                // Отступы как у окон niri (gaps 6).
                anchors.topMargin: Settings.bar.height + 6
                anchors.rightMargin: 6
                width: Settings.notifications.width
                height: Math.min(content.implicitHeight + Theme.spacing.lg * 2, parent.height * 0.75)
                focus: true

                Keys.onEscapePressed: Notifications.centerOpen = false

                MouseArea {
                    anchors.fill: parent
                }

                Column {
                    id: content

                    anchors.fill: parent
                    anchors.margins: Theme.spacing.lg
                    spacing: Theme.spacing.md

                    Item {
                        width: parent.width
                        implicitHeight: 30

                        StyledText {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Уведомления"
                            font.pixelSize: Theme.font.title
                            font.weight: Theme.font.medium
                        }

                        TextButton {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Очистить"
                            visible: Notifications.count > 0
                            onClicked: Notifications.clearAll()
                        }
                    }

                    // Переключатель с подписью: состояние читается без цвета.
                    Item {
                        width: parent.width
                        implicitHeight: 24

                        StyledText {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Не беспокоить"
                            color: Theme.color.textMuted
                        }

                        Switch {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            checked: Notifications.dnd
                            Accessible.name: "Не беспокоить"
                            onToggled: Notifications.setDnd(!Notifications.dnd)
                        }
                    }

                    ListView {
                        width: parent.width
                        height: Math.min(contentHeight, panel.parent.height * 0.75 - 30 - 24 - Theme.spacing.md * 2 - Theme.spacing.lg * 2)
                        visible: count > 0
                        clip: true
                        spacing: Theme.spacing.xs
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
                        height: 72
                        horizontalAlignment: Text.AlignHCenter
                        text: Notifications.dnd ? "Уведомлений нет. Новые не всплывают, пока включено «Не беспокоить»" : "Уведомлений нет"
                        wrapMode: Text.Wrap
                        color: Theme.color.textMuted
                        visible: Notifications.count === 0
                    }
                }
            }
        }
    }
}
