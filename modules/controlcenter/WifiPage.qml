import QtQuick
import Quickshell
import Quickshell.Networking
import qs.config
import qs.services
import qs.widgets

// Список сетей Wi-Fi. Клик по сети раскрывает действия: подключиться
// (с паролем для незнакомых защищённых сетей), отключиться, забыть.
Column {
    id: root

    property real maxListHeight: 400
    property string expandedName: ""

    signal back

    spacing: Theme.spacing.sm

    Component.onCompleted: NetworkState.scanRequested = true
    Component.onDestruction: NetworkState.scanRequested = false

    PageHeader {
        title: "Wi-Fi"
        onBack: root.back()

        Switch {
            checked: NetworkState.wifiEnabled
            onToggled: NetworkState.setWifiEnabled(!NetworkState.wifiEnabled)
        }
    }

    StyledText {
        width: parent.width
        height: 60
        horizontalAlignment: Text.AlignHCenter
        text: NetworkState.wifiEnabled ? "Поиск сетей…" : "Wi-Fi выключен"
        color: Theme.color.textMuted
        visible: !NetworkState.wifiEnabled || NetworkState.wifiNetworks.length === 0
    }

    ListView {
        width: parent.width
        height: Math.min(contentHeight, root.maxListHeight)
        visible: NetworkState.wifiEnabled && count > 0
        clip: true
        spacing: Theme.spacing.xxs
        boundsBehavior: Flickable.StopAtBounds

        model: ScriptModel {
            values: NetworkState.wifiNetworks
        }

        delegate: ListRow {
            id: row

            required property WifiNetwork modelData

            readonly property bool secured: modelData.security !== WifiSecurityType.Open
            readonly property bool needsPassword: secured && !modelData.known
            readonly property bool busy: modelData.stateChanging

            width: ListView.view.width
            icon: NetworkState.signalIcon(modelData.signalStrength)
            title: modelData.name
            subtitle: busy ? (modelData.connected ? "Отключение…" : "Подключение…")
                : modelData.connected ? "Подключено"
                : modelData.known ? "Сохранена"
                : secured ? "Защищена" : "Открытая"
            checked: modelData.connected
            expanded: root.expandedName === modelData.name
            onClicked: root.expandedName = expanded ? "" : modelData.name

            // Пароль только для незнакомых защищённых сетей.
            Rectangle {
                width: parent.width
                height: 32
                radius: Theme.radius.control
                color: Theme.color.background
                border.width: 2
                border.color: password.activeFocus ? Theme.color.focus : Theme.color.border
                visible: row.needsPassword && !row.modelData.connected

                TextInput {
                    id: password

                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacing.sm
                    anchors.rightMargin: Theme.spacing.sm
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    color: Theme.color.text
                    selectionColor: Theme.color.selection
                    selectedTextColor: Theme.color.text
                    font.family: Theme.font.family
                    font.pixelSize: Theme.font.body
                    focus: row.expanded
                    onAccepted: connectButton.clicked()

                    StyledText {
                        anchors.fill: parent
                        text: "Пароль"
                        color: Theme.color.textMuted
                        visible: password.text === ""
                    }
                }
            }

            Row {
                spacing: Theme.spacing.xs

                TextButton {
                    id: connectButton

                    primary: true
                    text: row.modelData.connected ? "Отключиться" : "Подключиться"
                    enabled: !row.busy && (row.modelData.connected || !row.needsPassword || password.text.length >= 8)
                    onClicked: {
                        if (!enabled)
                            return;
                        if (row.modelData.connected)
                            row.modelData.disconnect();
                        else if (row.needsPassword)
                            row.modelData.connectWithPsk(password.text);
                        else
                            row.modelData.connect();
                        root.expandedName = "";
                    }
                }

                TextButton {
                    text: "Забыть"
                    visible: row.modelData.known
                    onClicked: {
                        row.modelData.forget();
                        root.expandedName = "";
                    }
                }
            }
        }
    }

    TextButton {
        text: "Параметры сети…"
        onClicked: {
            Quickshell.execDetached(["nm-connection-editor"]);
            Ui.controlCenterOpen = false;
        }
    }
}
