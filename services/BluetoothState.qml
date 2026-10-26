pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth

// Адаптер Bluetooth по умолчанию и подключённые устройства.
// Название с суффиксом, чтобы не перекрывать модуль Quickshell.Bluetooth.
Singleton {
    id: root

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool enabled: adapter?.enabled ?? false

    // Подключённые первыми, дальше сопряжённые, остальные по имени.
    readonly property var devices: (adapter?.devices.values ?? []).slice()
        .sort((a, b) => b.connected - a.connected || b.paired - a.paired || a.name.localeCompare(b.name))
    readonly property var connectedDevices: devices.filter(d => d.connected)

    readonly property string icon: !available || !enabled ? "bluetooth-disabled-symbolic"
        : connectedDevices.length > 0 ? "bluetooth-active-symbolic"
        : "bluetooth-symbolic"

    readonly property string summary: !available ? "Нет адаптера"
        : !enabled ? "Выключен"
        : connectedDevices.length === 1 ? connectedDevices[0].name
        : connectedDevices.length > 1 ? `Устройств: ${connectedDevices.length}`
        : "Включён"

    function setEnabled(value) {
        if (adapter)
            adapter.enabled = value;
    }

    // Страница устройств просит поиск, а включается он, когда адаптер
    // загружен и включён: при открытии страницы адаптера может ещё не быть.
    property bool discoveryRequested: false
    readonly property bool shouldDiscover: discoveryRequested && enabled

    onShouldDiscoverChanged: {
        if (adapter)
            adapter.discovering = shouldDiscover;
    }
}
