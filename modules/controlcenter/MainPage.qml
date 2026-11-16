import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services
import qs.widgets
import qs.modules.bar

// Частые настройки видны сразу; дополнительные действия расположены ниже.
Column {
    id: root
    signal openPage(string name)
    readonly property bool wide: width >= 720
    spacing: 16

    RowLayout {
        width: parent.width
        spacing: 12
        Item { Layout.fillWidth: true }
        IconButton {
            icon: "system-lock-screen-symbolic"
            Accessible.name: "Заблокировать экран"
            onClicked: Lock.lock("manual")
        }
        IconButton {
            icon: "system-shutdown-symbolic"
            Accessible.name: "Выключение, перезагрузка, выход"
            onClicked: Ui.sessionOpen = true
        }
    }

    Grid {
        id: mainColumns
        width: parent.width
        columns: root.wide ? 2 : 1
        spacing: 20
        Column {
            width: (mainColumns.width - mainColumns.spacing * (mainColumns.columns - 1)) / mainColumns.columns
            spacing: 12
            SectionLabel {
                text: "Подключения"
            }
            Grid {
                width: parent.width
                columns: 2
                spacing: 8
                Tile {
                    readonly property bool wifi: NetworkState.wifiDevice !== null

                    width: (parent.width - parent.spacing) / 2
                    icon: wifi ? (!NetworkState.wifiEnabled ? "network-wireless-disabled-symbolic" : NetworkState.activeWifi ? NetworkState.signalIcon(NetworkState.activeWifi.signalStrength) : "network-wireless-offline-symbolic") : NetworkState.wiredConnected ? "network-wired-symbolic" : "network-offline-symbolic"
                    title: wifi ? "Wi-Fi" : "Сеть"
                    subtitle: wifi ? (!NetworkState.wifiEnabled ? (NetworkState.wiredConnected ? "Выключен · есть кабель" : "Выключен") : NetworkState.activeWifi ? NetworkState.activeWifi.name : NetworkState.wiredConnected ? "Через кабель" : "Не подключено") : NetworkState.wiredConnected ? "Кабель подключён" : "Нет подключения"
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
                    width: (parent.width - parent.spacing) / 2
                    icon: BluetoothState.icon
                    title: "Bluetooth"
                    subtitle: BluetoothState.summary
                    active: BluetoothState.enabled
                    enabled: BluetoothState.available
                    hasDetails: BluetoothState.available
                    onClicked: BluetoothState.setEnabled(!BluetoothState.enabled)
                    onDetailsClicked: root.openPage("bluetooth")
                }
            }
            SectionLabel {
                text: "Режимы"
            }
            Grid {
                width: parent.width
                columns: 2
                spacing: 8
                Tile {
                    width: (parent.width - parent.spacing) / 2
                    icon: "preferences-system-time-symbolic"
                    title: "Фокусировка"
                    subtitle: FocusMode.summary
                    active: FocusMode.active
                    onClicked: FocusMode.toggle()
                }
                Tile {
                    width: (parent.width - parent.spacing) / 2
                    icon: Notifications.dnd ? "notifications-disabled-symbolic" : "preferences-system-notifications-symbolic"
                    title: "Не беспокоить"
                    subtitle: Notifications.dnd ? "Включено" : "Выключено"
                    active: Notifications.dnd
                    onClicked: Notifications.setDnd(!Notifications.dnd)
                }
                Tile {
                    width: (parent.width - parent.spacing) / 2
                    icon: "preferences-desktop-screensaver-symbolic"
                    title: "Не засыпать"
                    subtitle: Caffeine.summary
                    active: Caffeine.active
                    onClicked: Caffeine.cycle()
                }
                Tile {
                    width: (parent.width - parent.spacing) / 2
                    icon: "microphone-sensitivity-high-symbolic"
                    title: "Приватность"
                    subtitle: Privacy.active ? Privacy.summary : "Микрофон, камера, экран"
                    active: Privacy.active
                    onClicked: Ui.openPrivacy()
                }
            }
        }
        Column {
            width: (mainColumns.width - mainColumns.spacing * (mainColumns.columns - 1)) / mainColumns.columns
            spacing: 12
            SectionLabel {
                text: "Звук и экран"
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

            Column {
                id: outputPicker
                width: parent.width
                spacing: 4
                property bool expanded: false
                ListRow {
                    width: parent.width
                    icon: Audio.icon
                    title: "Устройство вывода"
                    subtitle: Audio.sink ? Audio.deviceName(Audio.sink) : "Нет доступных устройств"
                    highlighted: outputPicker.expanded
                    onClicked: outputPicker.expanded = !outputPicker.expanded
                }
                Column {
                    width: parent.width
                    visible: outputPicker.expanded
                    Repeater {
                        model: ScriptModel { values: Audio.outputs }
                        ListRow {
                            required property var modelData
                            width: outputPicker.width
                            icon: "audio-speakers-symbolic"
                            title: Audio.deviceName(modelData)
                            checked: modelData === Audio.sink
                            onClicked: { Audio.setOutput(modelData); outputPicker.expanded = false; }
                        }
                    }
                    TextButton { text: "Выходы и микрофоны"; onClicked: root.openPage("audio") }
                }
            }

            AppearanceRow {
                width: parent.width
                onClicked: Ui.openSettings("appearance")
            }
            SectionLabel {
                text: "Питание и система"
            }
            Grid {
                width: parent.width
                columns: 2
                spacing: 8
                Tile {
                    width: (parent.width - parent.spacing) / 2
                    icon: Battery.profileIcon(Battery.profile)
                    title: "Питание"
                    subtitle: Battery.profileName(Battery.profile)
                    active: Battery.profile !== Battery.profiles[1]
                    onClicked: Battery.cycleProfile()
                }
                Tile {
                    width: (parent.width - parent.spacing) / 2
                    icon: "power-profile-performance-symbolic"
                    title: "Система"
                    subtitle: `ЦП ${Math.round(SystemStats.cpu * 100)}% · ОЗУ ${Math.round(SystemStats.memory * 100)}%`
                    onClicked: {
                        Ui.controlCenterOpen = false;
                        Ui.dashboardOpen = true;
                    }
                }
            }
        }
    }

    ActivityCard {
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
            onClicked: if (sliderRow.iconClickable)
                sliderRow.iconClicked()
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
            font.features: {
                "tnum": 1
            }
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
