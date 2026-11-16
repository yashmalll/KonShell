import QtQuick
import qs.services

Loader {
    id: root
    property string page: Ui.controlCenterPage
    property real maxListHeight: 400
    sourceComponent: page === "wifi" ? wifiPage
        : page === "bluetooth" ? bluetoothPage
        : page === "audio" ? audioPage : mainPage
    Component {
        id: mainPage
        MainPage { onOpenPage: name => Ui.controlCenterPage = name }
    }
    Component {
        id: wifiPage
        WifiPage { maxListHeight: root.maxListHeight; onBack: Ui.controlCenterPage = "main" }
    }
    Component {
        id: bluetoothPage
        BluetoothPage { maxListHeight: root.maxListHeight; onBack: Ui.controlCenterPage = "main" }
    }
    Component {
        id: audioPage
        AudioPage { maxListHeight: root.maxListHeight; onBack: Ui.controlCenterPage = "main" }
    }
}
