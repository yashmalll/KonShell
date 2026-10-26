import QtQuick
import Quickshell
import qs.config
import qs.services

// Рабочие столы монитора. Активный показан мини-картой своей ленты niri:
// каждая колонка — полоска пропорциональной ширины, сфокусированная выделена
// акцентом. Видно, сколько колонок на ленте и где вы на ней.
// Остальные столы — точки: заполненная, если на столе есть окна, контур — если пуст,
// крупнее и цветом ошибки — если окно требует внимания.
// Клик переключает стол, колесо листает столы вверх и вниз, как в niri.
Item {
    id: root

    required property string output

    // Логическая ширина монитора для масштаба мини-карты.
    readonly property real outputWidth: Quickshell.screens.find(s => s.name === output)?.width ?? 1536

    implicitWidth: row.implicitWidth
    implicitHeight: 24

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: wheel => {
            if (wheel.angleDelta.y !== 0)
                Niri.focusWorkspaceRelative(wheel.angleDelta.y < 0);
        }
    }

    Row {
        id: row

        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacing.xxs

        Repeater {
            // Модель из id, чтобы ScriptModel сохранял делегаты между событиями.
            model: ScriptModel {
                values: Niri.workspacesOn(root.output).map(ws => ws.id)
            }

            Item {
                id: slot

                required property int modelData

                readonly property var workspace: Niri.workspaces.find(ws => ws.id === modelData) ?? {}
                readonly property bool active: workspace.is_active ?? false
                readonly property bool urgent: workspace.is_urgent ?? false
                readonly property bool occupied: (workspace.active_window_id ?? null) !== null
                readonly property var columns: active ? Niri.columnsOn(modelData) : []

                // Слот шире своей отметки: в него удобно попасть мышью.
                implicitWidth: Math.max(18, (active ? minimap.implicitWidth : dot.width) + Theme.spacing.sm)
                implicitHeight: root.implicitHeight

                Behavior on implicitWidth {
                    NumberAnimation { duration: Theme.anim.normal; easing.type: Theme.anim.enter }
                }

                // Неактивный стол.
                Rectangle {
                    id: dot

                    anchors.centerIn: parent
                    width: slot.urgent ? 8 : 6
                    height: width
                    radius: Theme.radius.full
                    color: slot.urgent ? Theme.color.error : slot.occupied ? Theme.color.textMuted : "transparent"
                    border.width: slot.occupied || slot.urgent ? 0 : 1.5
                    border.color: Theme.color.outline
                    opacity: slot.active ? 0 : 1
                    visible: opacity > 0

                    Behavior on opacity {
                        NumberAnimation { duration: Theme.anim.fast }
                    }
                }

                // Активный стол: мини-карта ленты.
                Row {
                    id: minimap

                    anchors.centerIn: parent
                    spacing: 2
                    opacity: slot.active ? 1 : 0
                    visible: opacity > 0

                    Behavior on opacity {
                        NumberAnimation { duration: Theme.anim.fast }
                    }

                    // Пустой активный стол — одна короткая полоска.
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: slot.columns.length === 0
                        width: 12
                        height: 6
                        radius: Theme.radius.full
                        color: Theme.color.primary
                    }

                    Repeater {
                        model: slot.columns

                        Rectangle {
                            required property var modelData

                            anchors.verticalCenter: parent.verticalCenter
                            // Ширина колонки относительно ширины монитора: 24 px — колонка во весь экран.
                            width: Math.round(Math.max(5, Math.min(28, modelData.width / Math.max(1, root.outputWidth) * 24)))
                            height: modelData.focused ? 8 : 6
                            radius: Theme.radius.full
                            color: modelData.urgent ? Theme.color.error
                                : modelData.focused ? Theme.color.primary
                                : Theme.color.outline
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Niri.focusWorkspace(slot.modelData)
                }
            }
        }
    }
}
