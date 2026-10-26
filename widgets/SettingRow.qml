import QtQuick
import qs.config

// Строка настройки: название и пояснение слева, элемент управления справа
// (переключатель, кнопка). Без элемента — просто текст.
Item {
    id: root

    property string title
    property string hint
    default property alias control: controlSlot.data

    width: parent?.width ?? 0
    implicitHeight: Math.max(texts.implicitHeight, controlSlot.childrenRect.height)

    Column {
        id: texts

        anchors.left: parent.left
        anchors.right: controlSlot.left
        anchors.rightMargin: Theme.spacing.md
        anchors.verticalCenter: parent.verticalCenter

        StyledText {
            width: parent.width
            text: root.title
        }

        StyledText {
            width: parent.width
            text: root.hint
            color: Theme.color.textMuted
            font.pixelSize: Theme.font.caption
            wrapMode: Text.Wrap
            visible: text !== ""
        }
    }

    Item {
        id: controlSlot

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: childrenRect.width
        height: childrenRect.height
    }
}
