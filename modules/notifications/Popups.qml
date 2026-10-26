import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Wayland
import qs.config
import qs.services

// Всплывающие уведомления на активном мониторе. Положение — notifications.position:
// top-right | top-left | top-center | bottom-right | bottom-left | bottom-center.
// По таймеру окно только скрывается, уведомление остаётся в истории.
LazyLoader {
    active: Notifications.popups.length > 0 && !Notifications.centerOpen

    PanelWindow {
        id: window

        readonly property string position: Settings.notifications.position
        readonly property bool atTop: !position.startsWith("bottom")
        // right | left | center
        readonly property string side: position.endsWith("left") ? "left" : position.endsWith("center") ? "center" : "right"

        // Отступ карточек от края — 6, как gaps у окон niri; с остальных сторон — поля под тень.
        readonly property int edgeGap: 6
        readonly property int shadowPad: 16

        screen: Quickshell.screens.find(s => s.name === Niri.focusedWorkspace?.output) ?? null
        WlrLayershell.namespace: "konshell-notifications"
        WlrLayershell.layer: WlrLayer.Overlay
        // Ни left, ни right — layer-shell ставит окно по центру по горизонтали.
        anchors {
            top: window.atTop
            bottom: !window.atTop
            left: window.side === "left"
            right: window.side === "right"
        }

        implicitWidth: Settings.notifications.width + (side === "center" ? shadowPad * 2 : edgeGap + shadowPad)
        implicitHeight: column.implicitHeight + edgeGap + shadowPad
        color: "transparent"
        // Поля прозрачны для мыши: клики проходят к окнам под ними.
        mask: Region {
            item: column
        }

        Column {
            id: column

            x: window.side === "right" ? parent.width - width - window.edgeGap
                : window.side === "left" ? window.edgeGap
                : window.shadowPad
            y: window.atTop ? window.edgeGap : parent.height - height - window.edgeGap
            width: Settings.notifications.width
            spacing: Theme.spacing.sm

            Repeater {
                model: ScriptModel {
                    values: Notifications.popups.slice(0, Settings.notifications.maxPopups)
                }

                NotificationCard {
                    id: card

                    required property Notification modelData

                    notification: modelData
                    elevated: true
                    width: column.width

                    // Срочные висят, пока их не закроют. Наведение мыши
                    // останавливает таймер, уход мыши запускает его заново.
                    Timer {
                        readonly property real timeout: card.modelData.expireTimeout > 0
                            ? card.modelData.expireTimeout * 1000
                            : Settings.notifications.timeout

                        interval: timeout
                        running: card.modelData.urgency !== NotificationUrgency.Critical && !card.hovered
                        onTriggered: {
                            if (card.modelData.transient)
                                card.modelData.expire();
                            else
                                Notifications.hidePopup(card.modelData);
                        }
                    }

                    // Выезд со стороны своего края экрана.
                    transform: Translate {
                        id: slide

                        x: window.side === "right" ? Settings.notifications.width
                            : window.side === "left" ? -Settings.notifications.width
                            : 0
                        y: window.side !== "center" ? 0 : window.atTop ? -24 : 24
                    }
                    opacity: 0
                    Component.onCompleted: slideIn.start()

                    ParallelAnimation {
                        id: slideIn

                        NumberAnimation { target: slide; property: "x"; to: 0; duration: Theme.anim.normal; easing.type: Theme.anim.enter }
                        NumberAnimation { target: slide; property: "y"; to: 0; duration: Theme.anim.normal; easing.type: Theme.anim.enter }
                        NumberAnimation { target: card; property: "opacity"; to: 1; duration: Theme.anim.normal; easing.type: Theme.anim.enter }
                    }
                }
            }
        }
    }
}
