import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.services
import qs.widgets

// Сетка обоев с миниатюрами для окна настроек: выбор, «Открыть папку»,
// сообщение об ошибке палитры. Встраивается в раздел «Обои» реестром настроек.
Column {
    width: parent?.width ?? 0
    spacing: Theme.spacing.sm

    Item {
        width: parent.width
        implicitHeight: 28

        SectionLabel {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Обои"
        }

        TextButton {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "Открыть папку"
            onClicked: {
                Qt.openUrlExternally("file://" + Wallpaper.directory);
            }
        }
    }

    StyledText {
        width: parent.width
        text: `В папке ${Wallpaper.directory} нет картинок. Положите туда изображения, и они появятся здесь.`
        color: Theme.color.textMuted
        wrapMode: Text.Wrap
        visible: Wallpaper.images.length === 0
    }

    GridView {
        id: grid

        readonly property int columns: 4

        width: parent.width
        // Сетка целиком: прокручивается вся страница окна настроек.
        height: contentHeight
        interactive: false
        cellWidth: width / columns
        cellHeight: Math.round(cellWidth * 9 / 16)
        visible: count > 0
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        keyNavigationWraps: true
        activeFocusOnTab: true
        currentIndex: Math.max(0, Wallpaper.images.indexOf(Wallpaper.path))

        Keys.onReturnPressed: Wallpaper.set(Wallpaper.images[currentIndex])
        Keys.onEnterPressed: Wallpaper.set(Wallpaper.images[currentIndex])
        Keys.onSpacePressed: Wallpaper.set(Wallpaper.images[currentIndex])

        model: Wallpaper.images

        delegate: Item {
            id: cell

            required property string modelData
            required property int index

            readonly property bool selected: Wallpaper.path === modelData

            width: grid.cellWidth
            height: grid.cellHeight

            Rectangle {
                id: frame

                anchors.fill: parent
                anchors.margins: Theme.spacing.xxs
                radius: Theme.radius.control
                color: Theme.color.background
                // Выбранные обои — рамка акцентом и галочка, не только цвет.
                border.width: cell.selected ? 2 : 0
                border.color: Theme.color.primary

                ClippingRectangle {
                    anchors.fill: parent
                    anchors.margins: cell.selected ? 3 : 0
                    radius: cell.selected ? Theme.radius.control - 3 : Theme.radius.control
                    color: "transparent"

                    Image {
                        // Миниатюры ещё нет (первый запуск) — показываем оригинал в малом размере.
                        property bool useOriginal: false

                        anchors.fill: parent
                        source: useOriginal ? "file://" + cell.modelData : Wallpaper.thumbnail(cell.modelData)
                        onStatusChanged: {
                            if (status === Image.Error && !useOriginal)
                                useOriginal = true;
                        }

                        // Готова новая партия миниатюр — пробуем снова их, а не оригинал.
                        Connections {
                            target: Wallpaper

                            function onThumbnailRevisionChanged() {
                                parent.useOriginal = false;
                            }
                        }
                        fillMode: Image.PreserveAspectCrop
                        sourceSize: Qt.size(240, 135)
                        asynchronous: true
                        opacity: status === Image.Ready ? (thumbArea.containsMouse || cell.selected ? 1 : 0.85) : 0

                        Behavior on opacity {
                            NumberAnimation { duration: Theme.anim.fast }
                        }
                    }
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: Theme.spacing.xs + 2
                    width: 18
                    height: 18
                    radius: Theme.radius.full
                    color: Theme.color.primary
                    visible: cell.selected

                    SymbolIcon {
                        anchors.centerIn: parent
                        implicitSize: 12
                        name: "object-select-symbolic"
                        color: Theme.color.primaryText
                    }
                }

                // Клавиатурный фокус на текущей ячейке.
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -2
                    radius: Theme.radius.control + 2
                    color: "transparent"
                    border.width: 2
                    border.color: Theme.color.focus
                    visible: grid.activeFocus && grid.currentIndex === cell.index
                }
            }

            MouseArea {
                id: thumbArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Wallpaper.set(cell.modelData)
            }
        }
    }

    // Ошибка генерации палитры: обои сменились, а цвета остались прежними.
    Row {
        width: parent.width
        spacing: Theme.spacing.xs
        visible: ColorScheme.status === "error"

        SymbolIcon {
            anchors.verticalCenter: parent.verticalCenter
            implicitSize: 14
            name: "dialog-warning-symbolic"
            color: Theme.color.error
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 14 - parent.spacing
            text: `Цвета не обновились: ${ColorScheme.lastError}`
            color: Theme.color.error
            font.pixelSize: Theme.font.caption
            wrapMode: Text.Wrap
        }
    }
}
