import QtQuick
import Quickshell
import Quickshell.Networking
import qs.config
import qs.services
import qs.widgets

Column {
    id: root
    property real maxListHeight: 400
    property string expandedName: ""
    property string filter: ""
    property bool onlySaved: false
    property var errors: ({})
    property string forgetName: ""
    readonly property var networks: NetworkState.wifiNetworks.filter(n => (!onlySaved || n.known || n.connected) && n.name.toLowerCase().includes(filter.toLowerCase()))
    signal back
    spacing: 10
    function failure(reason) {
        switch (reason) {
        case ConnectionFailReason.NoSecrets:
            return "Нужен пароль. Введите его заново или откройте параметры сети.";
        case ConnectionFailReason.WifiAuthTimeout:
            return "Истекло время проверки пароля. Проверьте пароль и сигнал.";
        case ConnectionFailReason.WifiNetworkLost:
            return "Сеть потеряна. Подойдите ближе и обновите список.";
        case ConnectionFailReason.WifiClientDisconnected:
            return "Точка доступа разорвала соединение.";
        default:
            return "Подключение не удалось. Проверьте пароль и настройки точки доступа.";
        }
    }
    Component.onCompleted: {
        NetworkState.scanRequested = true;
        NetworkState.refreshDetails();
    }
    Component.onDestruction: NetworkState.scanRequested = false
    PageHeader {
        title: "Wi-Fi"
        onBack: root.back()
        Switch {
            checked: NetworkState.wifiEnabled
            enabled: NetworkState.wifiHardwareEnabled && NetworkState.wifiDevice !== null
            onToggled: NetworkState.setWifiEnabled(!NetworkState.wifiEnabled)
        }
    }
    StyledText {
        width: parent.width
        wrapMode: Text.Wrap
        color: Theme.color.textMuted
        text: !NetworkState.wifiDevice ? "Wi-Fi адаптер не найден." : !NetworkState.wifiHardwareEnabled ? "Wi-Fi заблокирован аппаратно. Проверьте режим полёта." : !NetworkState.wifiEnabled ? "Wi-Fi выключен" : `${NetworkState.wifiDevice.name} · ${NetworkState.connectionName}`
    }
    Rectangle {
        width: parent.width
        implicitHeight: info.implicitHeight + 24
        radius: Theme.radius.panel
        color: Theme.color.surface
        visible: NetworkState.activeWifi !== null
        Column {
            id: info
            x: 12
            y: 12
            width: parent.width - 24
            spacing: 5
            StyledText {
                width: parent.width
                text: NetworkState.activeWifi?.name ?? ""
                font.weight: Font.DemiBold
            }
            StyledText {
                width: parent.width
                wrapMode: Text.Wrap
                font.pixelSize: Theme.font.caption
                color: Theme.color.textMuted
                text: {
                    const d = NetworkState.details.device || {};
                    const ap = (NetworkState.details.networks || {})[NetworkState.activeWifi?.name] || {};
                    return [NetworkState.activeWifi ? `Сигнал ${Math.round(NetworkState.activeWifi.signalStrength * 100)}%` : "", ap.frequency, ap.channel ? "Канал " + ap.channel : "", ap.security].filter(Boolean).join(" · ") + "\n" + [d['IP4.ADDRESS']?.length ? "IP: " + d['IP4.ADDRESS'].join(", ") : "Получение IP-адреса…", d['IP4.GATEWAY']?.filter(Boolean).length ? "Шлюз: " + d['IP4.GATEWAY'].join(", ") : "", d['IP4.DNS']?.length ? "DNS: " + d['IP4.DNS'].join(", ") : ""].filter(Boolean).join("\n");
                }
            }
        }
    }
    SearchField {
        width: parent.width
        placeholder: "Найти сеть по названию"
        visible: NetworkState.wifiEnabled
        onTextChanged: root.filter = text
    }
    Flow {
        width: parent.width
        spacing: 8
        visible: NetworkState.wifiEnabled
        TextButton {
            text: "Все сети"
            primary: !root.onlySaved
            onClicked: root.onlySaved = false
        }
        TextButton {
            text: "Сохранённые"
            primary: root.onlySaved
            onClicked: root.onlySaved = true
        }
        TextButton {
            text: NetworkState.refreshing ? "Обновление…" : "Обновить"
            enabled: !NetworkState.refreshing
            onClicked: NetworkState.rescanNetworks()
        }
    }
    StyledText {
        width: parent.width
        wrapMode: Text.Wrap
        text: NetworkState.scanError || NetworkState.details.error || ""
        visible: text !== ""
        color: Theme.color.error
    }
    StyledText {
        width: parent.width
        text: root.filter ? "Совпадений нет" : root.onlySaved ? "Сохранённых сетей не найдено" : "Поиск сетей…"
        color: Theme.color.textMuted
        visible: NetworkState.wifiEnabled && !root.networks.length
    }
    ListView {
        width: parent.width
        height: Math.min(contentHeight, root.maxListHeight)
        visible: NetworkState.wifiEnabled && count > 0
        clip: true
        spacing: 4
        boundsBehavior: Flickable.StopAtBounds
        model: ScriptModel {
            values: root.networks
        }
        delegate: ListRow {
            id: row
            required property WifiNetwork modelData
            readonly property bool psk: [WifiSecurityType.WpaPsk, WifiSecurityType.Wpa2Psk, WifiSecurityType.Sae].includes(modelData.security)
            readonly property bool openNetwork: [WifiSecurityType.Open, WifiSecurityType.Owe].includes(modelData.security)
            readonly property bool needsPassword: psk && (!modelData.known || retryPassword)
            property bool retryPassword: false
            readonly property bool busy: modelData.stateChanging
            readonly property string error: root.errors[modelData.name] ?? ""
            width: ListView.view.width
            icon: NetworkState.signalIcon(modelData.signalStrength)
            title: modelData.name
            subtitle: (busy ? "Подключение меняется…" : modelData.connected ? "Подключено" : modelData.known ? "Сохранена" : openNetwork ? "Открытая" : "Защищена") + ` · ${Math.round(modelData.signalStrength * 100)}%`
            checked: modelData.connected
            expanded: root.expandedName === modelData.name
            onClicked: {
                root.expandedName = expanded ? "" : modelData.name;
                root.forgetName = "";
            }
            Connections {
                target: row.modelData
                function onConnectionFailed(reason) {
                    root.errors = Object.assign({}, root.errors, {
                        [row.modelData.name]: root.failure(reason)
                    });
                    root.expandedName = row.modelData.name;
                    row.retryPassword = row.psk;
                }
                function onConnectedChanged() {
                    if (row.modelData.connected) {
                        root.errors = Object.assign({}, root.errors, {
                            [row.modelData.name]: ""
                        });
                        password.text = "";
                        row.retryPassword = false;
                        NetworkState.refreshDetails();
                    }
                }
            }
            StyledText {
                width: parent.width
                wrapMode: Text.Wrap
                font.pixelSize: Theme.font.caption
                color: Theme.color.textMuted
                text: {
                    const ap = (NetworkState.details.networks || {})[row.modelData.name] || {};
                    return [ap.security || WifiSecurityType.toString(row.modelData.security), ap.frequency, ap.channel ? "Канал " + ap.channel : "", ap.rate].filter(Boolean).join(" · ");
                }
            }
            StyledText {
                width: parent.width
                wrapMode: Text.Wrap
                text: row.error
                color: Theme.color.error
                visible: text !== ""
            }
            SearchField {
                id: password
                width: parent.width
                placeholder: "Пароль сети"
                secret: !showPassword.checked
                visible: row.needsPassword && !row.modelData.connected
                onAccepted: if (connectButton.enabled)
                    connectButton.clicked()
            }
            Row {
                spacing: 8
                visible: password.visible
                Switch {
                    id: showPassword
                    onToggled: checked = !checked
                }
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Показать пароль"
                    font.pixelSize: Theme.font.caption
                }
            }
            Flow {
                width: parent.width
                spacing: 8
                TextButton {
                    id: connectButton
                    primary: true
                    text: row.modelData.connected ? "Отключиться" : !row.psk && !row.openNetwork && !row.modelData.known ? "Настроить подключение" : "Подключиться"
                    enabled: !row.busy && (!row.needsPassword || (row.modelData.security === WifiSecurityType.Sae ? password.text.length >= 1 : password.text.length >= 8 && password.text.length <= 63 || /^[0-9a-fA-F]{64}$/.test(password.text)))
                    onClicked: {
                        if (!enabled)
                            return;
                        root.errors = Object.assign({}, root.errors, {
                            [row.modelData.name]: ""
                        });
                        if (row.modelData.connected)
                            row.modelData.disconnect();
                        else if (row.needsPassword) {
                            row.modelData.connectWithPsk(password.text);
                            password.text = "";
                        } else if (row.modelData.known || row.openNetwork)
                            row.modelData.connect();
                        else
                            Quickshell.execDetached(["nm-connection-editor"]);
                    }
                }
                TextButton {
                    text: "Изменить пароль"
                    visible: row.modelData.known && row.psk && !row.modelData.connected
                    enabled: !row.busy
                    onClicked: row.retryPassword = !row.retryPassword
                }
                TextButton {
                    text: root.forgetName === row.modelData.name ? "Подтвердить удаление" : "Забыть"
                    visible: row.modelData.known
                    enabled: !row.busy
                    onClicked: {
                        if (root.forgetName === row.modelData.name) {
                            row.modelData.forget();
                            root.forgetName = "";
                        } else
                            root.forgetName = row.modelData.name;
                    }
                }
            }
        }
    }
    TextButton {
        text: "Расширенные параметры сети"
        onClicked: Quickshell.execDetached(["nm-connection-editor"])
    }
}
