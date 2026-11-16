import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs.config
import qs.services
import qs.widgets

Column {
    id: root
    property real maxListHeight: 400
    property string expandedAddress: ""
    property string forgetAddress: ""
    property string filter: ""
    property bool onlySaved: false
    readonly property var devices: BluetoothState.devices.filter(d => (!onlySaved || d.paired || d.connected) && ((d.name || "") + " " + d.address).toLowerCase().includes(filter.toLowerCase()))
    signal back
    spacing: 10
    Component.onCompleted: BluetoothState.discoveryRequested = true
    Component.onDestruction: BluetoothState.discoveryRequested = false

    PageHeader {
        title: "Bluetooth"
        onBack: root.back()
        Switch {
            checked: BluetoothState.enabled
            enabled: BluetoothState.available && !BluetoothState.blocked
            onToggled: BluetoothState.setEnabled(!BluetoothState.enabled)
        }
    }
    Flow {
        width: parent.width
        spacing: 8
        visible: BluetoothState.adapters.length > 1
        Repeater {
            model: ScriptModel {
                values: BluetoothState.adapters
            }
            TextButton {
                required property BluetoothAdapter modelData
                text: modelData.name
                primary: modelData === BluetoothState.adapter
                onClicked: BluetoothState.selectedAdapter = modelData.adapterId
            }
        }
    }
    StyledText {
        width: parent.width
        wrapMode: Text.Wrap
        color: Theme.color.textMuted
        font.pixelSize: Theme.font.caption
        text: !BluetoothState.available ? "Адаптер не найден. Проверьте USB-подключение и службу bluetooth." : BluetoothState.blocked ? "Bluetooth заблокирован аппаратно. Проверьте режим полёта или переключатель на корпусе." : !BluetoothState.enabled ? "Включите Bluetooth для подключения устройств." : `${BluetoothState.adapter.name} · ${BluetoothState.adapter.adapterId} · ${BluetoothState.adapter.discovering ? "Поиск устройств…" : "Поиск остановлен"}`
    }
    StyledText {
        width: parent.width
        wrapMode: Text.Wrap
        text: BluetoothState.agentError
        color: Theme.color.error
        visible: text !== ""
    }
    Rectangle {
        width: parent.width
        implicitHeight: promptBody.implicitHeight + 24
        radius: Theme.radius.panel
        color: Theme.color.surface
        visible: BluetoothState.prompt !== null
        Column {
            id: promptBody
            x: 12
            y: 12
            width: parent.width - 24
            spacing: 10
            StyledText {
                width: parent.width
                wrapMode: Text.Wrap
                text: {
                    const p = BluetoothState.prompt;
                    if (!p)
                        return "";
                    const device = BluetoothState.devices.find(d => d.dbusPath === p.device);
                    return (device?.name || p.device.split("/").pop().replace("dev_", "").replace(/_/g, ":")) + " · " + (p.event === "display" ? "Введите код на устройстве" : p.kind === "confirm" ? "Код совпадает на обоих устройствах?" : p.kind === "authorize" ? "Разрешить подключение?" : "Введите код устройства");
                }
            }
            StyledText {
                text: BluetoothState.prompt?.code || ""
                font.pixelSize: Theme.font.display
                visible: text !== ""
            }
            SearchField {
                id: pin
                width: parent.width
                placeholder: BluetoothState.prompt?.kind === "passkey" ? "Код до 6 цифр" : "PIN устройства"
                secret: true
                visible: ["pin", "passkey"].includes(BluetoothState.prompt?.kind)
                onVisibleChanged: text = ""
                onAccepted: BluetoothState.respond(true, text)
            }
            StyledText {
                width: parent.width
                wrapMode: Text.Wrap
                text: BluetoothState.inputError
                color: Theme.color.error
                visible: text !== ""
            }
            Row {
                spacing: 8
                TextButton {
                    text: "Подтвердить"
                    primary: true
                    visible: BluetoothState.prompt?.event !== "display"
                    onClicked: {
                        BluetoothState.respond(true, pin.text);
                        pin.text = "";
                    }
                }
                TextButton {
                    text: "Отменить"
                    onClicked: {
                        BluetoothState.cancelPrompt();
                        pin.text = "";
                    }
                }
            }
        }
    }
    SearchField {
        width: parent.width
        placeholder: "Название или адрес устройства"
        visible: BluetoothState.enabled
        onTextChanged: root.filter = text
    }
    Flow {
        width: parent.width
        spacing: 8
        visible: BluetoothState.enabled
        TextButton {
            text: "Все устройства"
            primary: !root.onlySaved
            onClicked: root.onlySaved = false
        }
        TextButton {
            text: "Мои устройства"
            primary: root.onlySaved
            onClicked: root.onlySaved = true
        }
        TextButton {
            text: BluetoothState.discoveryRequested ? "Остановить поиск" : "Найти устройства"
            onClicked: BluetoothState.discoveryRequested = !BluetoothState.discoveryRequested
        }
    }
    StyledText {
        width: parent.width
        wrapMode: Text.Wrap
        color: Theme.color.textMuted
        visible: BluetoothState.enabled && root.devices.length === 0
        text: root.filter ? "Совпадений нет." : root.onlySaved ? "Сохранённых устройств пока нет." : "Устройства пока не найдены. Включите режим сопряжения и отключите устройство от другого телефона или компьютера."
    }
    ListView {
        width: parent.width
        height: Math.min(contentHeight, root.maxListHeight)
        visible: BluetoothState.enabled && count > 0
        clip: true
        spacing: 4
        boundsBehavior: Flickable.StopAtBounds
        model: ScriptModel {
            values: root.devices
        }
        delegate: ListRow {
            id: row
            required property BluetoothDevice modelData
            readonly property var operation: BluetoothState.stateFor(modelData)
            readonly property bool busy: BluetoothState.busy(modelData)
            width: ListView.view.width
            icon: (modelData.icon || "bluetooth").replace(/-symbolic$/, "") + "-symbolic"
            title: modelData.name || modelData.address
            subtitle: operation.stage || (operation.error ? "Ошибка · нажмите для подробностей" : modelData.pairing ? "Сопряжение…" : modelData.state === BluetoothDeviceState.Connecting ? "Подключение…" : modelData.state === BluetoothDeviceState.Disconnecting ? "Отключение…" : modelData.connected ? "Подключено" + (modelData.batteryAvailable ? ` · ${Math.round(modelData.battery * 100)}%` : "") : modelData.blocked ? "Заблокировано" : modelData.paired ? "Сохранено" : "Доступно для сопряжения")
            checked: modelData.connected
            expanded: root.expandedAddress === modelData.address
            onClicked: {
                root.expandedAddress = expanded ? "" : modelData.address;
                root.forgetAddress = "";
            }
            StyledText {
                width: parent.width
                wrapMode: Text.Wrap
                font.pixelSize: Theme.font.caption
                color: Theme.color.textMuted
                text: `${row.modelData.address} · ${row.modelData.trusted ? "Доверенное" : "Без доверия"} · ${row.modelData.paired ? "Сопряжено" : "Не сопряжено"}`
            }
            StyledText {
                width: parent.width
                wrapMode: Text.Wrap
                text: row.operation.error
                color: Theme.color.error
                visible: text !== ""
            }
            Flow {
                width: parent.width
                spacing: 8
                TextButton {
                    primary: true
                    text: row.modelData.blocked ? "Разблокировать" : row.modelData.connected ? "Отключить" : row.modelData.paired ? "Подключить" : "Сопрячь и подключить"
                    enabled: !row.busy && BluetoothState.agentReady
                    onClicked: BluetoothState.act(row.modelData, row.modelData.blocked ? "unblock" : row.modelData.connected ? "disconnect" : "connect")
                }
                TextButton {
                    text: "Отменить"
                    visible: row.busy
                    onClicked: BluetoothState.act(row.modelData, "cancel")
                }
                TextButton {
                    text: row.modelData.trusted ? "Убрать доверие" : "Доверять"
                    visible: row.modelData.paired
                    enabled: !row.busy
                    onClicked: BluetoothState.act(row.modelData, row.modelData.trusted ? "untrust" : "trust")
                }
                TextButton {
                    text: root.forgetAddress === row.modelData.address ? "Подтвердить удаление" : "Забыть устройство"
                    visible: row.modelData.paired
                    enabled: !row.busy
                    onClicked: {
                        if (root.forgetAddress === row.modelData.address) {
                            BluetoothState.act(row.modelData, "forget");
                            root.forgetAddress = "";
                        } else
                            root.forgetAddress = row.modelData.address;
                    }
                }
            }
        }
    }
    TextButton {
        text: "Повторно запустить агент"
        visible: !BluetoothState.agentReady
        onClicked: BluetoothState.send({
            action: "register"
        })
    }
}
