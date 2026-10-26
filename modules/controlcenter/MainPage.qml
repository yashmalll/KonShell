import QtQuick
import qs.config
import qs.services
import qs.widgets

// Главная страница центра управления. Сверху вниз по важности:
// заряд, быстрые переключатели, громкость и яркость, музыка.
Column {
    id: root

    signal openPage(string name)

    spacing: Theme.spacing.lg

    // Шапка: заряд слева, настройки и питание справа.
    Item {
        width: parent.width
        implicitHeight: Math.max(batteryRow.visible ? batteryRow.implicitHeight : 0, headerButtons.implicitHeight)

        // Заряд крупно, состояние и время — рядом приглушённым текстом.
        Row {
            id: batteryRow

            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - headerButtons.width - Theme.spacing.sm
            spacing: Theme.spacing.md
            visible: Battery.available

            SymbolIcon {
                anchors.verticalCenter: parent.verticalCenter
                implicitSize: 20
                name: Battery.icon
                color: Battery.percent < 0.15 && !Battery.charging ? Theme.color.error : Theme.color.text
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: `${Math.round(Battery.percent * 100)}%`
                font.pixelSize: Theme.font.display
                font.weight: Theme.font.medium
                font.features: { "tnum": 1 }
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - x
                text: {
                    const time = Battery.formatTime(Battery.timeLeft);
                    if (Battery.full)
                        return "Заряжена";
                    if (Battery.charging)
                        return time ? `Заряжается, до полной ${time}` : "Заряжается";
                    if (Battery.pluggedIn)
                        return "Подключена к сети";
                    return time ? `Осталось ${time}` : "От батареи";
                }
                color: Theme.color.textMuted
                font.pixelSize: Theme.font.caption
            }
        }

        Row {
            id: headerButtons

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacing.xxs

            IconButton {
                icon: "preferences-system-symbolic"
                Accessible.name: "Настройки KonShell"
                onClicked: Ui.openSettings("")
            }

            IconButton {
                icon: "system-shutdown-symbolic"
                Accessible.name: "Выключение, перезагрузка, выход"
                onClicked: Ui.sessionOpen = true
            }
        }
    }

    Grid {
        id: tiles

        readonly property real tileWidth: (width - spacing) / 2

        width: parent.width
        columns: 2
        spacing: Theme.spacing.sm

        Tile {
            width: tiles.tileWidth
            icon: NetworkState.icon
            title: "Wi-Fi"
            subtitle: NetworkState.connectionName
            active: NetworkState.wifiEnabled
            hasDetails: NetworkState.wifiDevice !== null
            onClicked: NetworkState.setWifiEnabled(!NetworkState.wifiEnabled)
            onDetailsClicked: root.openPage("wifi")
        }

        Tile {
            width: tiles.tileWidth
            icon: BluetoothState.icon
            title: "Bluetooth"
            subtitle: BluetoothState.summary
            active: BluetoothState.enabled
            hasDetails: BluetoothState.available
            onClicked: BluetoothState.setEnabled(!BluetoothState.enabled)
            onDetailsClicked: root.openPage("bluetooth")
        }

        Tile {
            width: tiles.tileWidth
            icon: Notifications.dnd ? "notifications-disabled-symbolic" : "preferences-system-notifications-symbolic"
            title: "Не беспокоить"
            subtitle: Notifications.dnd ? "Включено" : "Выключено"
            active: Notifications.dnd
            onClicked: Notifications.setDnd(!Notifications.dnd)
        }

        Tile {
            width: tiles.tileWidth
            icon: Battery.profileIcon(Battery.profile)
            title: "Питание"
            subtitle: Battery.profileName(Battery.profile)
            active: Battery.profile !== Battery.profiles[1]
            onClicked: Battery.cycleProfile()
        }

        // Запись: клик — весь экран, стрелка — выбрать область; во время записи клик — стоп.
        // Пауза перед стартом — центр управления успевает закрыться и не попадает в кадр.
        Tile {
            width: tiles.tileWidth
            icon: "media-record-symbolic"
            title: "Запись экрана"
            subtitle: ScreenRecorder.recording ? `Идёт ${ScreenRecorder.format(ScreenRecorder.elapsed)} · стоп`
                : ScreenRecorder.available ? "Весь экран, → область" : "Нужны wf-recorder и slurp"
            active: ScreenRecorder.recording
            enabled: ScreenRecorder.available
            hasDetails: ScreenRecorder.available && !ScreenRecorder.recording
            onClicked: {
                if (ScreenRecorder.recording) {
                    ScreenRecorder.stop();
                } else {
                    Ui.controlCenterOpen = false;
                    ScreenRecorder.start("screen", 400);
                }
            }
            onDetailsClicked: {
                Ui.controlCenterOpen = false;
                ScreenRecorder.start("region", 400);
            }
        }

        // Встроенный инструмент снимков niri: область, окно или экран, сохраняет и копирует.
        Tile {
            width: tiles.tileWidth
            icon: "applets-screenshooter-symbolic"
            title: "Скриншот"
            subtitle: "Область, окно или экран"
            onClicked: {
                Ui.controlCenterOpen = false;
                ScreenRecorder.screenshot(350);
            }
        }

        Tile {
            width: tiles.tileWidth
            icon: "preferences-desktop-screensaver-symbolic"
            title: "Не засыпать"
            subtitle: Caffeine.summary
            active: Caffeine.active
            onClicked: Caffeine.cycle()
        }

        Tile {
            width: tiles.tileWidth
            icon: "power-profile-performance-symbolic"
            title: "Система"
            subtitle: `Процессор ${Math.round(SystemStats.cpu * 100)}% · память ${Math.round(SystemStats.memory * 100)}%`
            onClicked: {
                Ui.controlCenterOpen = false;
                Ui.dashboardOpen = true;
            }
        }
    }

    Column {
        width: parent.width
        spacing: Theme.spacing.xs

        SliderRow {
            icon: Audio.icon
            iconLabel: Audio.muted ? "Включить звук" : "Выключить звук"
            value: Audio.muted ? 0 : Audio.volume
            hasDetails: true
            onIconClicked: Audio.toggleMute()
            onMoved: value => Audio.setVolume(value)
            onDetailsClicked: root.openPage("audio")
        }

        SliderRow {
            icon: Audio.micIcon
            iconLabel: Audio.micMuted ? "Включить микрофон" : "Выключить микрофон"
            value: Audio.micMuted ? 0 : Audio.micVolume
            visible: Audio.source !== null
            onIconClicked: Audio.toggleMicMute()
            onMoved: value => Audio.setMicVolume(value)
        }

        SliderRow {
            icon: "display-brightness-symbolic"
            value: Brightness.percent
            visible: Brightness.available
            iconClickable: false
            onMoved: value => Brightness.setPercent(value)
        }
    }

    AppearanceRow {
        width: parent.width
        onClicked: Ui.openSettings("appearance")
    }

    MediaCard {
        width: parent.width
    }

    // Строка «иконка — ползунок — проценты». Имя устройства здесь не показываем:
    // оно на странице «Звук», куда ведёт стрелка.
    component SliderRow: Row {
        id: sliderRow

        property string icon
        property string iconLabel
        property bool iconClickable: true
        property real value
        property bool hasDetails: false

        signal moved(real value)
        signal iconClicked
        signal detailsClicked

        width: parent.width
        height: 32
        spacing: Theme.spacing.sm

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: sliderRow.icon
            // Иконка яркости — просто подпись, не кнопка.
            activeFocusOnTab: sliderRow.iconClickable
            Accessible.name: sliderRow.iconLabel
            onClicked: if (sliderRow.iconClickable) sliderRow.iconClicked()
        }

        Slider {
            anchors.verticalCenter: parent.verticalCenter
            // Место под стрелку есть во всех строках, чтобы дорожки и проценты стояли ровно.
            width: parent.width - 28 - percent.width - details.width - parent.spacing * 3
            value: sliderRow.value
            onMoved: value => sliderRow.moved(value)
        }

        StyledText {
            id: percent

            anchors.verticalCenter: parent.verticalCenter
            width: 36
            horizontalAlignment: Text.AlignRight
            text: `${Math.round(sliderRow.value * 100)}%`
            color: Theme.color.textMuted
            font.pixelSize: Theme.font.caption
            font.features: { "tnum": 1 }
        }

        IconButton {
            id: details

            anchors.verticalCenter: parent.verticalCenter
            opacity: sliderRow.hasDetails ? 1 : 0
            enabled: sliderRow.hasDetails
            icon: "go-next-symbolic"
            iconSize: 14
            Accessible.name: "Устройства звука"
            onClicked: sliderRow.detailsClicked()
        }
    }
}
