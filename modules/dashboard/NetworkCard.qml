import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

// Карточка «Сеть» в панели под часами: скорость и пакеты в секунду на приём
// и отдачу, график за минуту, объём с включения интерфейса, внутренний IP,
// шлюз, VPN и внешний IP. Клик по адресу — скопировать.
Column {
    id: root

    property string copied: ""

    function copy(text) {
        Quickshell.clipboardText = text;
        copied = text;
        copiedTimer.restart();
    }

    spacing: Theme.spacing.sm

    Timer {
        id: copiedTimer

        interval: 1500
        onTriggered: root.copied = ""
    }

    // Заголовок: интерфейс и сеть Wi-Fi.
    Item {
        width: parent.width
        height: 20

        SectionLabel {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Сеть"
        }

        StyledText {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 60
            horizontalAlignment: Text.AlignRight
            text: NetStats.iface === "" ? "нет подключения"
                : [NetworkState.connectionName, NetStats.iface].filter(s => s).join(" · ")
            color: Theme.color.textMuted
            font.pixelSize: Theme.font.caption
        }
    }

    // Приём и отдача: скорость крупно, пакеты мельче.
    Row {
        width: parent.width
        spacing: Theme.spacing.md

        Rate {
            width: (parent.width - parent.spacing) / 2
            arrow: "↓"
            label: "Приём"
            rate: NetStats.rxRate
            packets: NetStats.rxPackets
            accent: Theme.color.primary
        }

        Rate {
            width: (parent.width - parent.spacing) / 2
            arrow: "↑"
            label: "Отдача"
            rate: NetStats.txRate
            packets: NetStats.txPackets
            accent: Theme.color.tertiary
        }
    }

    // График за последнюю минуту: приём и отдача, общий масштаб.
    Rectangle {
        width: parent.width
        height: 56
        radius: Theme.radius.control
        color: Theme.color.surface

        Canvas {
            id: graph

            anchors.fill: parent
            anchors.margins: Theme.spacing.xs

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const rx = NetStats.rxHistory;
                const tx = NetStats.txHistory;
                const max = Math.max(1024, ...rx, ...tx) * 1.15;
                const n = NetStats.historyLength;
                const step = width / (n - 1);

                const line = (values, color) => {
                    if (values.length < 2)
                        return;
                    const start = n - values.length;
                    ctx.beginPath();
                    values.forEach((v, i) => {
                        const x = (start + i) * step;
                        const y = height - (v / max) * height;
                        i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
                    });
                    ctx.lineWidth = 1.5;
                    ctx.lineJoin = "round";
                    ctx.strokeStyle = color;
                    ctx.stroke();
                    // Заливка под линией.
                    ctx.lineTo((start + values.length - 1) * step, height);
                    ctx.lineTo(start * step, height);
                    ctx.closePath();
                    ctx.fillStyle = Qt.rgba(color.r, color.g, color.b, 0.12);
                    ctx.fill();
                };
                line(tx, Theme.color.tertiary);
                line(rx, Theme.color.primary);
            }

            Connections {
                target: NetStats

                function onRxHistoryChanged() {
                    graph.requestPaint();
                }
            }
        }

        StyledText {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.spacing.xs
            text: "60 с"
            color: Theme.color.textDisabled
            font.pixelSize: Theme.font.caption
        }
    }

    StyledText {
        width: parent.width
        text: `С включения: получено ${NetStats.bytes(NetStats.rxTotal)}, отправлено ${NetStats.bytes(NetStats.txTotal)}`
        color: Theme.color.textMuted
        font.pixelSize: Theme.font.caption
        visible: NetStats.iface !== ""
    }

    // Адреса.
    Column {
        width: parent.width
        spacing: Theme.spacing.xxs

        AddressRow {
            label: "Внутренний"
            value: NetStats.localIp
            visible: NetStats.localIp !== ""
        }

        AddressRow {
            label: "Шлюз"
            value: NetStats.gateway
            visible: NetStats.gateway !== ""
        }

        AddressRow {
            label: "VPN"
            value: NetStats.vpnIp
            extra: NetStats.vpnIface
            visible: NetStats.vpnIface !== ""
        }

        AddressRow {
            label: "Внешний"
            value: NetStats.externalState === "loading" && NetStats.externalIp === "" ? "…"
                : NetStats.externalState === "error" && NetStats.externalIp === "" ? "нет ответа"
                : NetStats.externalIp
            extra: [NetStats.externalPlace, NetStats.externalOrg].filter(s => s).join(" · ")
            copyable: NetStats.externalIp !== ""
            refreshable: true
            visible: Settings.network.externalIp
        }
    }

    component Rate: Column {
        id: rate

        property string arrow
        property string label
        property real rate: 0
        property real packets: 0
        property color accent

        spacing: 0

        Row {
            spacing: Theme.spacing.xs

            StyledText {
                anchors.baseline: value.baseline
                text: rate.arrow
                color: rate.accent
                font.weight: Theme.font.medium
            }

            StyledText {
                id: value

                text: NetStats.bytes(rate.rate, true)
                font.pixelSize: Theme.font.title
                font.weight: Theme.font.medium
                font.features: { "tnum": 1 }
            }
        }

        StyledText {
            text: `${rate.label} · ${Math.round(rate.packets)} пак/с`
            color: Theme.color.textMuted
            font.pixelSize: Theme.font.caption
            font.features: { "tnum": 1 }
        }
    }

    component AddressRow: Rectangle {
        id: address

        property string label
        property string value
        property string extra: ""
        property bool copyable: value !== "" && value !== "…"
        property bool refreshable: false

        width: root.width
        height: Math.max(30, values.implicitHeight + Theme.spacing.xs * 2)
        radius: Theme.radius.control
        color: area.containsMouse && copyable ? Theme.color.hover : "transparent"

        Behavior on color {
            ColorAnimation { duration: Theme.anim.fast }
        }

        StyledText {
            id: labelText

            anchors.left: parent.left
            anchors.leftMargin: Theme.spacing.sm
            anchors.verticalCenter: parent.verticalCenter
            width: 84
            text: address.label
            color: Theme.color.textMuted
            font.pixelSize: Theme.font.caption
        }

        Column {
            id: values

            anchors.left: labelText.right
            anchors.right: refresh.visible ? refresh.left : parent.right
            anchors.rightMargin: Theme.spacing.sm
            anchors.verticalCenter: parent.verticalCenter

            StyledText {
                width: parent.width
                text: root.copied !== "" && root.copied === address.value ? "Скопировано" : address.value
                color: root.copied !== "" && root.copied === address.value ? Theme.color.success : Theme.color.text
                font.pixelSize: Theme.font.caption
                font.features: { "tnum": 1 }
            }

            StyledText {
                width: parent.width
                text: address.extra
                color: Theme.color.textMuted
                font.pixelSize: Theme.font.caption - 1
                visible: text !== ""
            }
        }

        MouseArea {
            id: area

            anchors.fill: parent
            hoverEnabled: true
            enabled: address.copyable
            cursorShape: Qt.PointingHandCursor
            onClicked: root.copy(address.value)
        }

        IconButton {
            id: refresh

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: 24
            implicitHeight: 24
            iconSize: 14
            icon: "view-refresh-symbolic"
            visible: address.refreshable
            enabled: NetStats.externalState !== "loading"
            Accessible.name: "Обновить внешний IP"
            onClicked: NetStats.refreshExternal(true)
        }
    }
}
