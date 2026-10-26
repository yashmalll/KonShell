import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.config
import qs.widgets

// Меню значка трея в стиле оболочки. Подменю открываются в том же окне
// со строкой «Назад». Клик мимо меню закрывает его (grabFocus).
PopupWindow {
    id: root

    required property QsMenuHandle menu

    // Стек открытых подменю; последний элемент показывается.
    property var stack: [menu]

    signal dismissed

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

    implicitWidth: Settings.tray.menuWidth
    implicitHeight: content.implicitHeight + Theme.spacing.sm
    color: "transparent"

    QsMenuOpener {
        id: opener

        menu: root.stack[root.stack.length - 1]
    }

    // Без тени: окно меню ровно по размеру, тень обрезал бы его край.
    PopupSurface {
        id: surface

        anchors.fill: parent
        elevated: false

        Column {
            id: content

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.spacing.xs

            MenuRow {
                visible: root.stack.length > 1
                text: "Назад"
                prefix: "‹"
                onClicked: root.stack = root.stack.slice(0, -1)
            }

            Repeater {
                model: opener.children

                Loader {
                    id: entryLoader

                    required property QsMenuEntry modelData

                    width: content.width
                    sourceComponent: modelData.isSeparator ? separator : entry

                    Component {
                        id: separator

                        Item {
                            implicitHeight: Theme.spacing.sm + 1

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                height: 1
                                color: Theme.color.border
                            }
                        }
                    }

                    Component {
                        id: entry

                        MenuRow {
                            readonly property QsMenuEntry entryData: entryLoader.modelData

                            text: entryData.text
                            iconSource: entryData.icon
                            enabled: entryData.enabled
                            prefix: entryData.buttonType === QsMenuButtonType.None ? ""
                                : entryData.checkState === Qt.Checked ? (entryData.buttonType === QsMenuButtonType.RadioButton ? "●" : "✓")
                                : entryData.buttonType === QsMenuButtonType.RadioButton ? "○" : " "
                            suffix: entryData.hasChildren ? "›" : ""

                            onClicked: {
                                if (entryData.hasChildren) {
                                    root.stack = root.stack.concat([entryData]);
                                } else {
                                    entryData.triggered();
                                    root.close();
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component MenuRow: Rectangle {
        id: row

        property alias text: label.text
        property string iconSource: ""
        property string prefix: ""
        property string suffix: ""

        signal clicked

        width: parent?.width ?? 0
        implicitHeight: 30
        radius: Theme.radius.control
        color: area.containsMouse && enabled ? Theme.color.hover : "transparent"
        opacity: enabled ? 1 : 0.5

        Row {
            anchors.fill: parent
            anchors.leftMargin: Theme.spacing.sm
            anchors.rightMargin: Theme.spacing.sm
            spacing: Theme.spacing.sm

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                width: 12
                text: row.prefix
                visible: row.prefix !== ""
            }

            IconImage {
                anchors.verticalCenter: parent.verticalCenter
                implicitSize: 16
                source: row.iconSource
                visible: row.iconSource !== ""
            }

            StyledText {
                id: label

                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - x - (row.suffix ? 12 + parent.spacing : 0)
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: row.suffix
                color: Theme.color.textMuted
                visible: row.suffix !== ""
            }
        }

        MouseArea {
            id: area

            anchors.fill: parent
            hoverEnabled: true
            enabled: row.enabled
            onClicked: row.clicked()
        }
    }
}
