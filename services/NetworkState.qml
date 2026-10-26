pragma Singleton

import QtQuick
import Quickshell
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
    readonly property var wifiNetworks: (wifiDevice?.networks.values ?? []).slice()
        .sort((a, b) => b.connected - a.connected || b.signalStrength - a.signalStrength)
    readonly property WifiNetwork activeWifi: wifiNetworks.find(n => n.connected) ?? null

    readonly property bool wiredConnected: wiredDevice?.connected ?? false
    readonly property bool connected: wiredConnected || activeWifi !== null

    // Имя текущего подключения для подписей.
    readonly property string connectionName: wiredConnected ? "Проводная сеть"
        : activeWifi ? activeWifi.name
        : !wifiEnabled ? "Wi-Fi выключен"
        : "Нет подключения"

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
        return strength > 0.75 ? "network-wireless-signal-excellent-symbolic"
            : strength > 0.5 ? "network-wireless-signal-good-symbolic"
            : strength > 0.25 ? "network-wireless-signal-ok-symbolic"
            : strength > 0.05 ? "network-wireless-signal-weak-symbolic"
            : "network-wireless-signal-none-symbolic";
    }

    function setWifiEnabled(value) {
        Networking.wifiEnabled = value;
    }

    // Сканирование нужно только пока открыт список сетей. Включается,
    // когда устройство Wi-Fi загружено: при открытии списка его может ещё не быть.
    property bool scanRequested: false
    readonly property bool shouldScan: scanRequested && wifiEnabled && wifiDevice !== null

    onShouldScanChanged: {
        if (wifiDevice)
            wifiDevice.scannerEnabled = shouldScan;
    }
}
