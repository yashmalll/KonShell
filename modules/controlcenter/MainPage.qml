import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.config
import qs.services
import qs.widgets

// Главная страница центра управления. Сверху вниз по важности:
// заряд (или пользователь, если батареи нет), быстрые переключатели,
// громкость и яркость, оформление, музыка.
Column {
    id: root

    signal openPage(string name)

    readonly property string userName: {
        const name = Quickshell.env("USER") ?? "";
        return name.charAt(0).toUpperCase() + name.slice(1);
    }

    // Сколько работает компьютер — из /proc/uptime, раз в минуту, пока страница открыта.
    property string uptimeText: ""

    function updateUptime() {
        uptimeFile.reload();
        const seconds = parseFloat(uptimeFile.text().split(" ")[0]);
        if (isNaN(seconds)) {
            uptimeText = "";
            return;
        }
        const days = Math.floor(seconds / 86400);
        const hours = Math.floor(seconds % 86400 / 3600);
        const minutes = Math.floor(seconds % 3600 / 60);
        uptimeText = "Работает " + (days > 0 ? `${days} д ${hours} ч` : hours > 0 ? `${hours} ч ${minutes} мин` : `${minutes} мин`);
    }

    FileView {
        id: uptimeFile

        path: "/proc/uptime"
        blockLoading: true
        printErrors: false
    }

    Timer {
        interval: 60000
        repeat: true
        triggeredOnStart: true
        running: root.visible && !Battery.available
        onTriggered: root.updateUptime()
    }

    spacing: Theme.spacing.lg

    // Шапка: заряд слева, настройки и питание справа.
    Item {
        width: parent.width
        implicitHeight: Math.max(batteryRow.visible ? batteryRow.implicitHeight : 0,
                                 userRow.visible ? 40 : 0, headerButtons.implicitHeight)

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

        // Без батареи: аватар (lock.avatarPath или ~/.face, иначе первая буква),
        // имя пользователя и сколько работает компьютер.
        Row {
            id: userRow

            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - headerButtons.width - Theme.spacing.sm
            spacing: Theme.spacing.md
            visible: !Battery.available

            Rectangle {
                width: 40
                height: 40
                radius: Theme.radius.full
                color: Theme.color.primaryContainer

                StyledText {
                    anchors.centerIn: parent
                    text: root.userName.charAt(0).toUpperCase()
                    color: Theme.color.primaryContainerText
                    font.pixelSize: Theme.font.title
                    font.weight: Theme.font.medium
                    visible: avatar.status !== Image.Ready
                }

                ClippingRectangle {
                    anchors.fill: parent
                    radius: Theme.radius.full
                    color: "transparent"
                    visible: avatar.status === Image.Ready

                    Image {
                        id: avatar

                        anchors.fill: parent
                        source: "file://" + (Settings.lock.avatarPath || Quickshell.env("HOME") + "/.face")
                        sourceSize: Qt.size(80, 80)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 40 - parent.spacing

                StyledText {
                    width: parent.width
                    text: root.userName
                    font.pixelSize: Theme.font.title
                    font.weight: Theme.font.medium
                    elide: Text.ElideRight
                }

                StyledText {
                    width: parent.width
                    text: root.uptimeText
                    color: Theme.color.textMuted
                    font.pixelSize: Theme.font.caption
                    elide: Text.ElideRight
                    visible: text !== ""
                }
            }
        }

        Row {
            id: headerButtons

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacing.xs

            // Круглые кнопки на подложке — заметнее, чем голые значки.
            IconButton {
                implicitWidth: 34
                implicitHeight: 34
                baseColor: Theme.color.surface
                icon: "preferences-system-symbolic"
                Accessible.name: "Настройки KonShell"
                onClicked: Ui.openSettings("")
            }

            IconButton {
                implicitWidth: 34
                implicitHeight: 34
                baseColor: Theme.color.surface
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

        // Есть Wi-Fi — плитка включает и выключает его, стрелка — список сетей.
        // Только кабель — плитка показывает подключение и открывает карточку сети
        // в панели под часами.
        Tile {
            readonly property bool wifi: NetworkState.wifiDevice !== null

            width: tiles.tileWidth
            icon: wifi ? (!NetworkState.wifiEnabled ? "network-wireless-disabled-symbolic"
                          : NetworkState.activeWifi ? NetworkState.signalIcon(NetworkState.activeWifi.signalStrength)
                          : "network-wireless-offline-symbolic")
                : NetworkState.wiredConnected ? "network-wired-symbolic" : "network-offline-symbolic"
            title: wifi ? "Wi-Fi" : "Сеть"
            subtitle: wifi ? (!NetworkState.wifiEnabled ? (NetworkState.wiredConnected ? "Выключен · есть кабель" : "Выключен")
                              : NetworkState.activeWifi ? NetworkState.activeWifi.name
                              : NetworkState.wiredConnected ? "Через кабель" : "Не подключено")
                : NetworkState.wiredConnected ? "Кабель подключён" : "Нет подключения"
            active: wifi ? NetworkState.wifiEnabled : NetworkState.wiredConnected
            hasDetails: wifi
            onClicked: {
                if (wifi) {
                    NetworkState.setWifiEnabled(!NetworkState.wifiEnabled);
                } else {
                    Ui.controlCenterOpen = false;
                    Ui.dashboardOpen = true;
                }
            }
            onDetailsClicked: root.openPage("wifi")
        }

        Tile {
            width: tiles.tileWidth
            icon: BluetoothState.icon
            title: "Bluetooth"
            subtitle: BluetoothState.summary
            active: BluetoothState.enabled
            enabled: BluetoothState.available
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
                : ScreenRecorder.available ? "Весь экран" : "Нужны wf-recorder и slurp"
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
            subtitle: "Область или окно"
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
            subtitle: `ЦП ${Math.round(SystemStats.cpu * 100)}% · ОЗУ ${Math.round(SystemStats.memory * 100)}%`
            onClicked: {
                Ui.controlCenterOpen = false;
                Ui.dashboardOpen = true;
            }
        }
    }

    // Громкость, микрофон и яркость — одной карточкой.
    Rectangle {
        width: parent.width
        implicitHeight: sliders.implicitHeight + Theme.spacing.sm * 2
        radius: Theme.radius.panel
        color: Theme.color.surface

        Column {
            id: sliders

            x: Theme.spacing.sm
            y: Theme.spacing.sm
            width: parent.width - Theme.spacing.sm * 2
            spacing: Theme.spacing.xxs

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
