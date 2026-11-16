import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.widgets

Column {
    id: root
    width: parent?.width ?? 0
    spacing: 14
    SectionLabel {
        text: "Доступ к устройствам"
    }
    Grid {
        id: devices
        width: parent.width
        columns: width >= 720 ? 3 : 1
        spacing: 12
        Repeater {
            model: [
                {
                    label: "Микрофон",
                    icon: "microphone-sensitivity-high-symbolic",
                    apps: Privacy.microphoneApps
                },
                {
                    label: "Камера",
                    icon: "camera-web-symbolic",
                    apps: Privacy.cameraApps
                },
                {
                    label: "Демонстрация / запись экрана",
                    icon: "video-display-symbolic",
                    apps: Privacy.sharedApps.concat(ScreenRecorder.recording ? ["KonShell"] : [])
                }
            ]
            Rectangle {
                required property var modelData
                width: (devices.width - devices.spacing * (devices.columns - 1)) / devices.columns
                implicitHeight: Math.max(104, information.implicitHeight + 24)
                radius: 16
                color: Theme.color.surface
                SymbolIcon {
                    x: 14
                    anchors.verticalCenter: parent.verticalCenter
                    name: modelData.icon
                    color: modelData.apps.length ? Theme.color.primary : Theme.color.textMuted
                }
                Column {
                    id: information
                    x: 44
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 58
                    spacing: 5
                    StyledText {
                        width: parent.width
                        text: modelData.label
                        font.weight: Font.Medium
                        wrapMode: Text.Wrap
                    }
                    StyledText {
                        width: parent.width
                        text: modelData.apps.length ? modelData.apps.join(", ") : !Settings.system.privacyIndicator ? "Наблюдение выключено" : !Privacy.available ? "Данные PipeWire недоступны" : "Активное использование не обнаружено"
                        color: modelData.apps.length ? Theme.color.primary : Theme.color.textMuted
                        wrapMode: Text.Wrap
                    }
                }
            }
        }
    }
    StyledText {
        width: parent.width
        text: "Проверяются активные потоки PipeWire и открытые устройства камеры текущего пользователя. Закрытые для чтения процессы и захват вне PipeWire могут быть недоступны. Аудио и видео не читаются."
        font.pixelSize: Theme.font.caption
        color: Theme.color.textMuted
        wrapMode: Text.Wrap
    }
    Flow {
        width: parent.width
        spacing: 10
        TextButton {
            text: Audio.micMuted ? "Включить микрофон" : "Выключить микрофон"
            enabled: Audio.source !== null
            onClicked: Audio.toggleMicMute()
        }
        TextButton {
            text: "Настройки приватности"
            onClicked: Ui.openSettings("privacy")
        }
    }
}
