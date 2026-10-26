import QtQuick
import Quickshell.Widgets
import qs.config
import qs.services
import qs.widgets

// Вход на страницу «Оформление»: миниатюра текущих обоев и текущий режим.
Rectangle {
    id: appearance

    signal clicked

    implicitHeight: 52
    radius: Theme.radius.panel
    color: area.pressed ? Qt.tint(Theme.color.surface, Theme.color.pressed)
        : area.containsMouse ? Qt.tint(Theme.color.surface, Theme.color.hover)
        : Theme.color.surface

    activeFocusOnTab: true
    Keys.onReturnPressed: clicked()
    Keys.onEnterPressed: clicked()
    Keys.onSpacePressed: clicked()
    Keys.onRightPressed: clicked()

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: appearance.clicked()
    }

    ClippingRectangle {
        id: thumb

        anchors.left: parent.left
        anchors.leftMargin: Theme.spacing.sm
        anchors.verticalCenter: parent.verticalCenter
        width: 64
        height: 36
        radius: Theme.radius.control - 2
        color: Theme.color.surfaceVariant

        Image {
            anchors.fill: parent
            source: Wallpaper.path ? "file://" + Wallpaper.path : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(128, 72)
            asynchronous: true
        }
    }

    Column {
        anchors.left: thumb.right
        anchors.right: chevron.left
        anchors.leftMargin: Theme.spacing.md
        anchors.rightMargin: Theme.spacing.sm
        anchors.verticalCenter: parent.verticalCenter

        StyledText {
            width: parent.width
            text: "Оформление"
            font.weight: Theme.font.medium
        }

        StyledText {
            width: parent.width
            text: Theme.mode === "dark" ? "Тёмная тема, цвета из обоев" : "Светлая тема, цвета из обоев"
            color: Theme.color.textMuted
            font.pixelSize: Theme.font.caption
        }
    }

    SymbolIcon {
        id: chevron

        anchors.right: parent.right
        anchors.rightMargin: Theme.spacing.md
        anchors.verticalCenter: parent.verticalCenter
        implicitSize: 14
        name: "go-next-symbolic"
    }

    FocusRing {}
}
