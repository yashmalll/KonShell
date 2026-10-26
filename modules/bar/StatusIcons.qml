import QtQuick
import qs.config
import qs.services
import qs.widgets

// Сеть, Bluetooth, громкость и батарея. Клик открывает центр управления,
// колесо меняет громкость.
Rectangle {
    implicitWidth: row.implicitWidth + Theme.spacing.lg
    implicitHeight: 24
    radius: Theme.radius.control
    color: Ui.controlCenterOpen ? Theme.color.surface : area.containsMouse ? Theme.color.hover : "transparent"

    Row {
        id: row

        anchors.centerIn: parent
        spacing: Theme.spacing.sm

        // Идёт запись экрана: мигающая точка и время; клик — остановить.
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: recordRow.implicitWidth + Theme.spacing.sm * 2
            height: 20
            radius: Theme.radius.full
            color: Theme.alpha(Theme.color.error, recordArea.containsMouse ? 0.3 : 0.18)
            visible: ScreenRecorder.recording

            Row {
                id: recordRow

                anchors.centerIn: parent
                spacing: Theme.spacing.xs

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 8
                    height: 8
                    radius: 4
                    color: Theme.color.error

                    SequentialAnimation on opacity {
                        running: ScreenRecorder.recording && !Theme.reduceMotion
                        loops: Animation.Infinite

                        NumberAnimation { to: 0.25; duration: 700; easing.type: Easing.InOutQuad }
                        NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutQuad }
                    }
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: ScreenRecorder.format(ScreenRecorder.elapsed)
                    color: Theme.color.error
                    font.pixelSize: Theme.font.caption
                    font.weight: Theme.font.medium
                    font.features: { "tnum": 1 }
                }
            }

            // Клик по индикатору останавливает запись, а не открывает центр управления.
            MouseArea {
                id: recordArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: ScreenRecorder.stop()
            }
        }

        SymbolIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: NetworkState.icon
        }

        SymbolIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: BluetoothState.icon
            visible: BluetoothState.available && BluetoothState.enabled
        }

        SymbolIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: Audio.icon
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacing.xxs
            visible: Battery.available

            SymbolIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: Battery.icon
                color: Battery.percent < 0.15 && !Battery.charging ? Theme.color.error : Theme.color.text
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: `${Math.round(Battery.percent * 100)}%`
                font.pixelSize: Theme.font.caption
                font.features: { "tnum": 1 }
            }
        }
    }

    MouseArea {
        id: area

        // Под строкой значков: индикатор записи ловит свой клик сам.
        z: -1
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Ui.controlCenterOpen = !Ui.controlCenterOpen
        onWheel: wheel => {
            if (wheel.angleDelta.y > 0)
                Audio.increaseVolume();
            else if (wheel.angleDelta.y < 0)
                Audio.decreaseVolume();
        }
    }
}
