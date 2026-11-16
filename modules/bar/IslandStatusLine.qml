import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services
import qs.widgets

RowLayout {
    id: root
    property string title: ""
    property bool closable: false
    readonly property bool trayOpen: tray.popupOpen
    signal closeRequested
    spacing: 8
    Clock { compact: true; visible: root.title === "" }
    StyledText {
        text: root.title
        visible: root.title !== ""
        font.pixelSize: Theme.font.title
        font.weight: Font.DemiBold
        Layout.fillWidth: true
        Layout.minimumWidth: 0
    }
    Item { Layout.fillWidth: true; visible: root.title === "" }
    StyledText {
        text: Qt.formatTime(clock.date, "HH:mm")
        color: Theme.color.textMuted
        visible: root.title !== "" && root.width > 600
        font.features: { "tnum": 1 }
    }
    SystemClock { id: clock; precision: SystemClock.Minutes }
    Row {
        spacing: 4
        visible: Battery.available && root.width >= 480
        SymbolIcon { anchors.verticalCenter: parent.verticalCenter; name: Battery.icon; implicitSize: 15 }
        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: `${Math.round(Battery.percent * 100)}%`
            font.pixelSize: Theme.font.caption
            color: Battery.percent <= 0.15 && !Battery.charging ? Theme.color.error : Theme.color.textMuted
        }
    }
    IconButton {
        icon: NetworkState.icon
        Accessible.name: "Сеть и Wi-Fi"
        onClicked: { Ui.controlCenterPage = NetworkState.wifiDevice !== null ? "wifi" : "main"; Ui.controlCenterOpen = true; }
    }
    IconButton {
        icon: Audio.icon
        Accessible.name: "Выбрать устройство вывода звука"
        onClicked: { Ui.controlCenterPage = "audio"; Ui.controlCenterOpen = true; }
    }
    Tray { id: tray; Layout.alignment: Qt.AlignVCenter }
    PrivacyIndicator { showWhenIdle: true }
    IconButton {
        icon: "system-search-symbolic"
        Accessible.name: "Общий поиск"
        onClicked: Ui.searchRequested()
    }
    IconButton {
        icon: "emblem-system-symbolic"
        Accessible.name: "Настройки оболочки"
        onClicked: Ui.openSettings("")
    }
    IconButton {
        icon: "window-close-symbolic"
        visible: root.closable
        Accessible.name: "Закрыть островок"
        onClicked: root.closeRequested()
    }
}
