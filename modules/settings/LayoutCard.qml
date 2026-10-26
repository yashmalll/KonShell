import QtQuick
import qs.config
import qs.widgets

// Карточка элемента для LayoutEditor: иконка и название; в зонах — во всю ширину
// с крестиком «скрыть», в скрытых — компактная. Перетаскивается мышью.
Item {
    id: card

    // Редактор (LayoutEditor): его функции и состояние перетаскивания.
    required property Item editor
    property string itemId
    property bool compact: false
    readonly property var widget: card.editor.find(itemId)
    readonly property bool dragging: cardArea.drag.active

    implicitWidth: compact ? body.implicitWidth : 120
    implicitHeight: 36

    // Пока карточку несут, на её месте — пустая рамка: видно, откуда её взяли.
    Rectangle {
        anchors.fill: parent
        radius: Theme.radius.control
        color: "transparent"
        border.width: 1
        border.color: Theme.color.border
        visible: card.dragging
    }

    Rectangle {
        id: body

        readonly property real naturalWidth: icon.implicitWidth + label.implicitWidth + Theme.spacing.sm * 3
            + (card.compact ? 0 : closeButton.width)

        implicitWidth: naturalWidth
        width: card.width
        height: card.height
        radius: Theme.radius.control
        color: card.dragging ? Theme.color.surfaceVariant
            : cardArea.containsMouse ? Theme.color.hover
            : card.compact ? "transparent" : Theme.color.surface
        border.width: card.compact || card.dragging ? 1 : 0
        border.color: card.dragging ? Theme.color.primary : Theme.color.border

        Drag.active: card.dragging
        Drag.keys: ["konshell-layout"]
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2

        states: State {
            when: card.dragging

            ParentChange {
                target: body
                parent: card.editor.dragLayer
            }
        }

        SymbolIcon {
            id: icon

            anchors.left: parent.left
            anchors.leftMargin: Theme.spacing.sm
            anchors.verticalCenter: parent.verticalCenter
            implicitSize: 16
            name: card.widget?.icon ?? ""
            color: card.compact ? Theme.color.textMuted : Theme.color.text
        }

        StyledText {
            id: label

            anchors.left: icon.right
            anchors.right: card.compact ? undefined : closeButton.left
            anchors.leftMargin: Theme.spacing.sm
            anchors.rightMargin: Theme.spacing.xxs
            anchors.verticalCenter: parent.verticalCenter
            text: card.widget?.name ?? card.itemId
            color: card.compact ? Theme.color.textMuted : Theme.color.text
            elide: Text.ElideRight
        }

        MouseArea {
            id: cardArea

            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true
            cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            drag.target: body
            drag.threshold: 4

            onPressed: card.editor.dragId = card.itemId
            onReleased: card.editor.finishDrag()
            onClicked: {
                if (card.compact)
                    card.editor.show(card.itemId);
            }
        }

        IconButton {
            id: closeButton

            anchors.right: parent.right
            anchors.rightMargin: Theme.spacing.xxs
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: card.compact ? 0 : 24
            implicitHeight: 24
            visible: !card.compact && !card.dragging && (cardArea.containsMouse || closeButton.hovered)
            icon: "window-close-symbolic"
            iconSize: 12
            iconColor: Theme.color.textMuted
            Accessible.name: "Скрыть"
            onClicked: card.editor.hide(card.itemId)
        }
    }
}
