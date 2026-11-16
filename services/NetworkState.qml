pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

// Сеть через NetworkManager: первое Wi-Fi и первое проводное устройство.
// Название с суффиксом, чтобы не перекрывать тип Network из Quickshell.Networking.
Singleton {
    id: root

    readonly property var devices: Networking.devices.values
    readonly property WifiDevice wifiDevice: devices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property WiredDevice wiredDevice: devices.find(d => d.type === DeviceType.Wired) ?? null

    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property bool wifiHardwareEnabled: Networking.wifiHardwareEnabled

    // Сети отсортированы: подключённая первой, дальше по силе сигнала.
    readonly property var wifiNetworks: (wifiDevice?.networks.values ?? []).slice().sort((a, b) => b.connected - a.connected || b.signalStrength - a.signalStrength)
    readonly property WifiNetwork activeWifi: wifiNetworks.find(n => n.connected) ?? null

    readonly property bool wiredConnected: wiredDevice?.connected ?? false
    readonly property bool connected: wiredConnected || activeWifi !== null

    // Имя текущего подключения для подписей.
    readonly property string connectionName: wiredConnected ? "Проводная сеть" : activeWifi ? (activeWifi.name || "Wi-Fi") : !wifiEnabled ? "Wi-Fi выключен" : "Нет подключения"

    readonly property string icon: {
        if (wiredConnected)
            return "network-wired-symbolic";
        if (!wifiHardwareEnabled || !wifiEnabled)
            return wiredDevice ? "network-offline-symbolic" : "network-wireless-disabled-symbolic";
        if (activeWifi)
            return signalIcon(activeWifi.signalStrength);
        return "network-wireless-offline-symbolic";
    }

    function signalIcon(strength) {
        return strength > 0.75 ? "network-wireless-signal-excellent-symbolic" : strength > 0.5 ? "network-wireless-signal-good-symbolic" : strength > 0.25 ? "network-wireless-signal-ok-symbolic" : strength > 0.05 ? "network-wireless-signal-weak-symbolic" : "network-wireless-signal-none-symbolic";
    }

    function setWifiEnabled(value) {
        Networking.wifiEnabled = value;
    }

    // Сканирование нужно только пока открыт список сетей. Включается,
    // когда устройство Wi-Fi загружено: при открытии списка его может ещё не быть.
    property bool scanRequested: false
    readonly property bool shouldScan: scanRequested && wifiEnabled && wifiDevice !== null

    property var scanningDevice: null
    function syncScan() {
        if (scanningDevice && scanningDevice !== wifiDevice)
            scanningDevice.scannerEnabled = false;
        scanningDevice = wifiDevice;
        if (wifiDevice)
            wifiDevice.scannerEnabled = shouldScan;
    }
    onShouldScanChanged: syncScan()
    onWifiDeviceChanged: syncScan()
    property var details: ({
            device: {},
            networks: {}
        })
    property string scanError: ""
    readonly property bool refreshing: rescan.running
    function refreshDetails() {
        if (wifiDevice && !detailProcess.running)
            detailProcess.running = true;
    }
    function rescanNetworks() {
        if (wifiDevice && wifiEnabled && !rescan.running) {
            scanError = "";
            rescan.running = true;
        }
    }
    Process {
        id: detailProcess
        command: ["python3", Quickshell.shellDir + "/scripts/network-details.py", root.wifiDevice?.name ?? ""]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.details = JSON.parse(text);
                } catch (e) {}
            }
        }
    }
    Process {
        id: rescan
        command: ["nmcli", "device", "wifi", "rescan", "ifname", root.wifiDevice?.name ?? ""]
        onExited: code => {
            if (code !== 0)
                root.scanError = "Не удалось обновить список. Повторите через несколько секунд.";
            root.refreshDetails();
        }
    }
    Timer {
        interval: 10000
        running: root.scanRequested
        triggeredOnStart: true
        repeat: true
        onTriggered: root.refreshDetails()
    }
}
