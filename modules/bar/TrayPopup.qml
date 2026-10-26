import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import qs.config
import qs.widgets

// Всплывающее окно трея: значки, не закреплённые на панели, компактной сеткой
// без заголовка. Клик мимо закрывает окно (grabFocus). Правый клик по значку —
// меню с «Показывать на панели».
PopupWindow {
    id: root

    property var items: []

    signal dismissed

    readonly property int cell: 30
    readonly property int columns: Math.max(1, Math.min(6, items.length))

    function close() {
        visible = false;
    }

    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    anchor.adjustment: PopupAdjustment.Slide | PopupAdjustment.FlipY
    anchor.margins.top: Theme.spacing.sm

    grabFocus: true
    BackgroundEffect.blurRegion: Region {
        item: surface.blurItem
        radius: Theme.radius.panel
    }

    visible: true
    onVisibleChanged: {
        if (!visible)
            dismissed();
    }

    // Последний значок ушёл на панель или закрылся — окно больше не нужно.
    onItemsChanged: {
        if (items.length === 0)
            close();
    }

    implicitWidth: grid.implicitWidth + Theme.spacing.xs * 2
    implicitHeight: grid.implicitHeight + Theme.spacing.xs * 2
    color: "transparent"

    // Без тени: окно ровно по размеру, тень обрезал бы его край.
    PopupSurface {
        id: surface

        anchors.fill: parent
        elevated: false

        Grid {
            id: grid

            anchors.centerIn: parent
            columns: root.columns
            spacing: 0

            Repeater {
                model: ScriptModel {
                    values: root.items
                }

                Rectangle {
                    id: cellItem

                    required property SystemTrayItem modelData

                    width: root.cell
                    height: root.cell
                    radius: Theme.radius.control
                    color: icon.hovered || icon.menuOpen ? Theme.color.hover : "transparent"

                    Behavior on color {
                        ColorAnimation { duration: Theme.anim.fast }
                    }

                    TrayIcon {
                        id: icon

                        anchors.centerIn: parent
                        item: cellItem.modelData
                        onActivated: root.close()
                    }
                }
            }
        }
    }
}
