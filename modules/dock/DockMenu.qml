import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// Меню значка дока: окна приложения, новое окно, закрепление и порядок,
// закрыть все окна. Открывается над значком; клик мимо закрывает (grabFocus).
PopupWindow {
    id: root

    required property var item

    signal dismissed

    function close() {
        visible = false;
    }

    // Сначала действие, потом закрытие: после закрытия меню удаляется вместе с item.
    function run(fn) {
        fn();
        close();
    }

    readonly property int pinnedIndex: DockApps.pinnedKeys.indexOf(item.key)

    anchor.edges: Edges.Top
    anchor.gravity: Edges.Top
    anchor.adjustment: PopupAdjustment.Slide | PopupAdjustment.FlipY
    anchor.margins.bottom: Theme.spacing.md

    grabFocus: true
    visible: true
    onVisibleChanged: {
        if (!visible)
            dismissed();
    }

    BackgroundEffect.blurRegion: Region {
        item: surface.blurItem
        radius: Theme.radius.panel
    }


    implicitWidth: 260
    implicitHeight: content.implicitHeight + Theme.spacing.xs * 2
    color: "transparent"

    PopupSurface {
        id: surface

        anchors.fill: parent
        elevated: false
        enterFrom: 1

        Column {
            id: content

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.spacing.xs

            StyledText {
                width: parent.width
                leftPadding: Theme.spacing.sm
                rightPadding: Theme.spacing.sm
                height: 30
                text: root.item.name
                font.weight: Theme.font.medium
            }

            Repeater {
                model: root.item.windows

                MenuRow {
                    required property var modelData

                    text: modelData.title || root.item.name
                    prefix: modelData.is_focused ? "●" : ""
                    onClicked: root.run(() => Niri.focusWindow(modelData.id))
                }
            }

            Separator {}

            MenuRow {
                text: root.item.windows.length > 0 ? "Новое окно" : "Запустить"
                visible: root.item.entry !== null
                onClicked: root.run(() => DockApps.launch(root.item))
            }

            MenuRow {
                text: root.item.pinned ? "Открепить" : "Закрепить в доке"
                onClicked: root.run(() => root.item.pinned ? DockApps.unpin(root.item.key) : DockApps.pin(root.item.key))
            }

            MenuRow {
                text: "Сдвинуть левее"
                visible: root.pinnedIndex > 0
                onClicked: root.run(() => DockApps.move(root.item.key, -1))
            }

            MenuRow {
                text: "Сдвинуть правее"
                visible: root.pinnedIndex >= 0 && root.pinnedIndex < DockApps.pinnedKeys.length - 1
                onClicked: root.run(() => DockApps.move(root.item.key, 1))
            }

            Separator {
                visible: root.item.windows.length > 0
            }

            MenuRow {
                text: root.item.windows.length > 1 ? `Закрыть все окна (${root.item.windows.length})` : "Закрыть"
                visible: root.item.windows.length > 0
                danger: true
                onClicked: root.run(() => DockApps.closeAll(root.item))
            }
        }
    }

    component Separator: Item {
        width: parent?.width ?? 0
        implicitHeight: visible ? Theme.spacing.sm + 1 : 0

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 1
            color: Theme.color.border
        }
    }

    component MenuRow: Rectangle {
        id: row

        property alias text: label.text
        property string prefix: ""
        property bool danger: false

        signal clicked

        width: parent?.width ?? 0
        implicitHeight: visible ? 30 : 0
        radius: Theme.radius.control
        color: area.containsMouse ? Theme.color.hover : "transparent"

        Behavior on color {
            ColorAnimation { duration: Theme.anim.fast }
        }

        Row {
            anchors.fill: parent
            anchors.leftMargin: Theme.spacing.sm
            anchors.rightMargin: Theme.spacing.sm
            spacing: Theme.spacing.sm

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                width: 10
                text: row.prefix
                color: Theme.color.primary
                font.pixelSize: Theme.font.caption
                visible: row.prefix !== ""
            }

            StyledText {
                id: label

                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - x
                color: row.danger ? Theme.color.error : Theme.color.text
            }
        }

        MouseArea {
            id: area

            anchors.fill: parent
            hoverEnabled: true
            onClicked: row.clicked()
        }
    }
}
