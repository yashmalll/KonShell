import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs.config
import qs.services
import qs.widgets

// Устройства Bluetooth. Пока страница открыта, адаптер ищет новые устройства.
// Клик раскрывает действия: подключить/отключить, сопрячь, забыть.
Column {
    id: root

    property real maxListHeight: 400
    property string expandedAddress: ""

    // Устройства без имени (только MAC-адрес) не показываем.
    readonly property var devices: BluetoothState.devices
        .filter(d => d.name && d.name.replace(/[-:]/g, "") !== d.address.replace(/:/g, ""))

    signal back

    spacing: Theme.spacing.sm

    Component.onCompleted: BluetoothState.discoveryRequested = true
    Component.onDestruction: BluetoothState.discoveryRequested = false

    PageHeader {
        title: "Bluetooth"
        onBack: root.back()

        Switch {
            checked: BluetoothState.enabled
            onToggled: BluetoothState.setEnabled(!BluetoothState.enabled)
        }
    }

    StyledText {
        width: parent.width
        height: 60
        horizontalAlignment: Text.AlignHCenter
        text: BluetoothState.enabled ? "Поиск устройств…" : "Bluetooth выключен"
        color: Theme.color.textMuted
        visible: !BluetoothState.enabled || root.devices.length === 0
    }

    ListView {
        width: parent.width
        height: Math.min(contentHeight, root.maxListHeight)
        visible: BluetoothState.enabled && count > 0
        clip: true
        spacing: Theme.spacing.xxs
        boundsBehavior: Flickable.StopAtBounds

        model: ScriptModel {
            values: root.devices
        }

        delegate: ListRow {
            id: row

            required property BluetoothDevice modelData

            readonly property bool busy: modelData.pairing
                || modelData.state === BluetoothDeviceState.Connecting
                || modelData.state === BluetoothDeviceState.Disconnecting

            width: ListView.view.width
            icon: (modelData.icon || "bluetooth") + "-symbolic"
            title: modelData.name
            subtitle: {
                if (modelData.pairing)
                    return "Сопряжение…";
                if (modelData.state === BluetoothDeviceState.Connecting)
                    return "Подключение…";
                if (modelData.state === BluetoothDeviceState.Disconnecting)
                    return "Отключение…";
                if (modelData.connected)
                    return modelData.batteryAvailable ? `Подключено, заряд ${Math.round(modelData.battery * 100)}%` : "Подключено";
                return modelData.paired ? "Сопряжено" : "Доступно";
            }
            checked: modelData.connected
            expanded: root.expandedAddress === modelData.address
            onClicked: root.expandedAddress = expanded ? "" : modelData.address

            Row {
                spacing: Theme.spacing.xs

                TextButton {
                    primary: true
                    enabled: !row.busy
                    text: row.modelData.connected ? "Отключить"
                        : row.modelData.paired ? "Подключить"
                        : "Сопрячь"
                    onClicked: {
                        if (!enabled)
                            return;
                        const device = row.modelData;
                        if (device.connected) {
                            device.disconnect();
                        } else if (device.paired) {
                            device.connect();
                        } else {
                            // Доверенное устройство потом подключается само.
                            device.trusted = true;
                            device.pair();
                        }
                        root.expandedAddress = "";
                    }
                }

                TextButton {
                    text: "Забыть"
                    visible: row.modelData.paired
                    onClicked: {
                        row.modelData.forget();
                        root.expandedAddress = "";
                    }
                }
            }
        }
    }
}
