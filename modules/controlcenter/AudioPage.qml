import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.config
import qs.services
import qs.widgets

// Выбор устройств вывода и ввода звука по умолчанию.
Column {
    id: root

    property real maxListHeight: 400

    signal back

    spacing: Theme.spacing.sm

    PageHeader {
        title: "Звук"
        onBack: root.back()
    }

    Flickable {
        width: parent.width
        height: Math.min(content.implicitHeight, root.maxListHeight)
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: content

            width: parent.width
            spacing: Theme.spacing.xxs

            Section {
                text: "Выход"
            }

            Repeater {
                model: ScriptModel {
                    values: Audio.outputs
                }

                ListRow {
                    required property PwNode modelData

                    width: content.width
                    icon: "audio-speakers-symbolic"
                    title: Audio.deviceName(modelData)
                    checked: Audio.sink === modelData
                    onClicked: Audio.setOutput(modelData)
                }
            }

            Section {
                text: "Вход"
                topPadding: Theme.spacing.sm
            }

            Repeater {
                model: ScriptModel {
                    values: Audio.inputs
                }

                ListRow {
                    required property PwNode modelData

                    width: content.width
                    icon: "audio-input-microphone-symbolic"
                    title: Audio.deviceName(modelData)
                    checked: Audio.source === modelData
                    onClicked: Audio.setInput(modelData)
                }
            }
        }
    }

    component Section: StyledText {
        leftPadding: Theme.spacing.sm
        color: Theme.color.textMuted
        font.pixelSize: Theme.font.caption
        font.weight: Font.Medium
    }
}
