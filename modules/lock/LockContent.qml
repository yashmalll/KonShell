import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.services
import qs.widgets

// Содержимое экрана блокировки на одном мониторе: размытые обои, часы, дата,
// поле пароля и состояние проверки. Пароль и проверка общие для всех мониторов
// (context — LockScreen).
Item {
    id: root

    required property var context

    // Затемнение поверх размытых обоев, чтобы текст читался на любой картинке.
    readonly property real scrimOpacity: Math.max(0, Math.min(1, Settings.lock.tint))

    Image {
        id: wallpaper

        anchors.fill: parent
        source: Wallpaper.path ? "file://" + Wallpaper.path : ""
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(root.width, root.height)
        asynchronous: true
        visible: false
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.color.background
    }

    MultiEffect {
        anchors.fill: parent
        source: wallpaper
        visible: wallpaper.status === Image.Ready
        blurEnabled: true
        blur: Math.max(0, Math.min(1, Settings.lock.blur))
        blurMax: 64
        autoPaddingEnabled: false
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.color.background, root.scrimOpacity)
    }

    // Отсрочка после блокировки по простою: шевельнули мышью — разблокировано.
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onPositionChanged: root.context.tryGracePeriod()
    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    // Часы — главное на экране, поэтому крупнее шкалы оболочки.
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.22
        spacing: Theme.spacing.xs

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(clock.date, "HH:mm")
            font.pixelSize: 80
            font.weight: Theme.font.medium
            font.features: { "tnum": 1 }
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: {
                const date = Qt.locale("ru_RU").toString(clock.date, Settings.lock.dateFormat || "dddd, d MMMM");
                return date.charAt(0).toUpperCase() + date.slice(1);
            }
            color: Theme.color.textMuted
            font.pixelSize: Theme.font.title
        }
    }

    Column {
        id: form

        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.6
        width: 320
        spacing: Theme.spacing.md

        // Аватар: lock.avatarPath или ~/.face; без картинки места не занимает.
        ClippingRectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 72
            height: 72
            radius: Theme.radius.full
            color: "transparent"
            visible: avatar.status === Image.Ready

            Image {
                id: avatar

                anchors.fill: parent
                source: "file://" + (Settings.lock.avatarPath || Quickshell.env("HOME") + "/.face")
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(144, 144)
                asynchronous: true
            }
        }

        // Поле пароля с раскладкой справа: пароль часто набирают не в той раскладке.
        Rectangle {
            id: field

            width: parent.width
            height: 46
            radius: Theme.radius.full
            color: Theme.color.panel
            border.width: input.activeFocus ? 2 : 1
            border.color: root.context.error !== "" ? Theme.color.error
                : input.activeFocus ? Theme.color.focus
                : Theme.color.border
            opacity: root.context.busy ? 0.6 : 1

            transform: Translate {
                id: shake
            }

            SymbolIcon {
                id: lockIcon

                anchors.left: parent.left
                anchors.leftMargin: Theme.spacing.lg
                anchors.verticalCenter: parent.verticalCenter
                name: "system-lock-screen-symbolic"
                color: Theme.color.textMuted
            }

            TextInput {
                id: input

                anchors.left: lockIcon.right
                anchors.right: layout.left
                anchors.leftMargin: Theme.spacing.md
                anchors.rightMargin: Theme.spacing.sm
                anchors.verticalCenter: parent.verticalCenter
                echoMode: TextInput.Password
                passwordCharacter: "•"
                color: Theme.color.text
                selectionColor: Theme.color.selection
                font.family: Theme.font.family
                font.pixelSize: Theme.font.title
                readOnly: root.context.busy
                focus: true
                clip: true

                onTextChanged: {
                    root.context.password = text;
                    root.context.tryGracePeriod();
                }
                onAccepted: root.context.submit()
                Keys.onEscapePressed: {
                    if (text !== "")
                        text = "";
                    else
                        root.context.cancelPreview();
                }

                StyledText {
                    anchors.fill: parent
                    text: Lock.hasPin ? "PIN или пароль" : "Пароль"
                    color: Theme.color.textMuted
                    font.pixelSize: Theme.font.title
                    visible: input.text === ""
                }

                Component.onCompleted: forceActiveFocus()
            }

            StyledText {
                id: layout

                anchors.right: parent.right
                anchors.rightMargin: Theme.spacing.lg
                anchors.verticalCenter: parent.verticalCenter
                text: Niri.currentLayoutLabel
                color: Theme.color.textMuted
                font.pixelSize: Theme.font.caption
                font.weight: Theme.font.medium
                visible: Niri.keyboardLayouts.length > 1
            }
        }

        // Состояние проверки. Ошибка — цветом, значком и текстом.
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacing.xs

            SymbolIcon {
                anchors.verticalCenter: parent.verticalCenter
                implicitSize: 14
                name: "dialog-warning-symbolic"
                color: Theme.color.error
                visible: root.context.error !== ""
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, form.width)
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                font.pixelSize: Theme.font.caption
                color: root.context.error !== "" ? Theme.color.error : Theme.color.textMuted
                text: root.context.busy ? "Проверка…"
                    : root.context.error !== "" ? root.context.error
                    : root.context.preview ? "Предпросмотр: Esc — закрыть"
                    : Lock.hasPin && !Lock.pinBlocked ? "Введите PIN или пароль"
                    : Lock.pinBlocked ? "PIN временно отключён — введите пароль"
                    : "Введите пароль, чтобы разблокировать"
            }
        }
    }

    // Заряд в углу: при долгой блокировке важно знать, не пора ли к розетке.
    Row {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.spacing.lg
        spacing: Theme.spacing.xs
        visible: Battery.available && Settings.lock.showBattery

        SymbolIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: Battery.icon
            color: Battery.percent < 0.15 && !Battery.charging ? Theme.color.error : Theme.color.text
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: `${Math.round(Battery.percent * 100)}%`
            font.pixelSize: Theme.font.caption
            font.features: { "tnum": 1 }
        }
    }

    // Неверный пароль: поле очищается и коротко встряхивается.
    Connections {
        target: root.context

        function onFailed() {
            input.text = "";
            shakeAnimation.restart();
        }
        function onPasswordChanged() {
            if (root.context.password === "" && input.text !== "")
                input.text = "";
        }
    }

    SequentialAnimation {
        id: shakeAnimation

        NumberAnimation { target: shake; property: "x"; to: -10; duration: Theme.anim.fast / 3 }
        NumberAnimation { target: shake; property: "x"; to: 10; duration: Theme.anim.fast / 2 }
        NumberAnimation { target: shake; property: "x"; to: -6; duration: Theme.anim.fast / 2 }
        NumberAnimation { target: shake; property: "x"; to: 0; duration: Theme.anim.fast / 3 }
    }
}
