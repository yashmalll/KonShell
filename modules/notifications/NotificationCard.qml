import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets
import qs.config
import qs.services
import qs.widgets

// Карточка уведомления: и всплывающее окно (elevated, с тенью), и строка истории.
// Сверху мелко — приложение и время, ниже — заголовок, текст и действия.
// Клик по карточке выполняет действие по умолчанию, крестик закрывает.
Rectangle {
    id: root

    required property Notification notification
    // Всплывающая карточка парит над окнами: тень и рамка. В истории — без них.
    property bool elevated: false

    readonly property bool hovered: hover.hovered
    readonly property bool critical: notification.urgency === NotificationUrgency.Critical
    readonly property var defaultAction: notification.actions.find(a => a.identifier === "default") ?? null
    readonly property var buttons: notification.actions.filter(a => a.identifier !== "default")
    readonly property string appIconSource: Quickshell.iconPath(notification.appIcon || notification.desktopEntry, true)

    implicitHeight: content.implicitHeight + Theme.spacing.md * 2
    radius: elevated ? Theme.radius.panel : Theme.radius.control
    color: elevated ? Theme.color.popup : Theme.color.surface
    border.width: critical ? 1.5 : elevated && Theme.borders ? 1 : 0
    border.color: critical ? Theme.color.error : Theme.color.border

    layer.enabled: elevated && Theme.shadows
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: Theme.color.shadow
        shadowBlur: 0.8
        shadowVerticalOffset: 4
        autoPaddingEnabled: true
    }

    HoverHandler {
        id: hover
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: root.defaultAction ? Qt.PointingHandCursor : Qt.ArrowCursor
        // invoke() сам закрывает обычное уведомление.
        onClicked: root.defaultAction?.invoke()
    }

    Column {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.spacing.md
        spacing: Theme.spacing.xs

        // Приложение, время, закрыть.
        Item {
            width: parent.width
            implicitHeight: 20

            Row {
                anchors.left: parent.left
                anchors.right: time.left
                anchors.rightMargin: Theme.spacing.sm
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacing.xs

                // Срочное отмечено не только цветом рамки, но и значком.
                SymbolIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    implicitSize: 14
                    name: "dialog-warning-symbolic"
                    color: Theme.color.error
                    visible: root.critical
                }

                IconImage {
                    anchors.verticalCenter: parent.verticalCenter
                    implicitSize: 14
                    source: root.appIconSource
                    visible: root.appIconSource !== "" && !root.critical
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, parent.width - 20)
                    text: root.notification.appName
                    visible: Settings.notifications.showAppName
                    color: Theme.color.textMuted
                    font.pixelSize: Theme.font.caption
                }
            }

            StyledText {
                id: time

                anchors.right: close.left
                anchors.rightMargin: Theme.spacing.xxs
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.color.textMuted
                font.pixelSize: Theme.font.caption
                font.features: { "tnum": 1 }
                // Пересчитывается раз в минуту вместе с часами.
                text: {
                    const at = Notifications.receivedAt[root.notification.id];
                    if (!at)
                        return "";
                    const minutes = Math.floor((clock.date - at) / 60000);
                    return minutes < 1 ? "сейчас" : minutes < 60 ? `${minutes} мин назад` : Qt.formatTime(at, "HH:mm");
                }

                SystemClock {
                    id: clock
                    precision: SystemClock.Minutes
                }
            }

            IconButton {
                id: close

                anchors.right: parent.right
                anchors.rightMargin: -Theme.spacing.xs
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: 24
                implicitHeight: 24
                icon: "window-close-symbolic"
                iconSize: 12
                iconColor: Theme.color.textMuted
                Accessible.name: "Закрыть уведомление"
                onClicked: root.notification.dismiss()
            }
        }

        // Заголовок и текст; картинка уведомления (обложка, аватар) справа.
        Row {
            width: parent.width
            spacing: Theme.spacing.md

            Column {
                width: parent.width - (image.visible ? image.width + parent.spacing : 0)
                spacing: Theme.spacing.xxs

                StyledText {
                    width: parent.width
                    text: root.notification.summary
                    font.weight: Theme.font.medium
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                }

                StyledText {
                    width: parent.width
                    text: root.notification.body
                    textFormat: Text.StyledText
                    color: Theme.color.textMuted
                    wrapMode: Text.Wrap
                    maximumLineCount: 4
                    lineHeight: 1.15
                    visible: text !== ""
                    onLinkActivated: link => Qt.openUrlExternally(link)
                }
            }

            ClippingRectangle {
                id: image

                width: 40
                height: 40
                radius: Theme.radius.control
                color: "transparent"
                visible: root.notification.image !== ""

                Image {
                    anchors.fill: parent
                    source: root.notification.image
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(80, 80)
                    asynchronous: true
                }
            }
        }

        Row {
            spacing: Theme.spacing.xs
            topPadding: Theme.spacing.xs
            visible: root.buttons.length > 0 && Settings.notifications.showActions

            Repeater {
                model: root.buttons

                TextButton {
                    required property NotificationAction modelData

                    text: modelData.text
                    // Обычное (не resident) уведомление Quickshell закрывает сам:
                    // после invoke() карточки уже может не быть.
                    onClicked: modelData.invoke()
                }
            }
        }
    }
}
