import QtQuick
import qs.config

// Плитка быстрого переключателя: иконка, название, состояние.
// Включённая — мягкая заливка primaryContainer, а не яркий акцент:
// акцент в оболочке один и отведён фокусу и прогрессу.
// Клик, Enter или пробел переключают; стрелка справа (или →) открывает подробности.
Rectangle {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool active: false
    property bool hasDetails: false

    signal clicked
    signal detailsClicked

    readonly property color foreground: active ? Theme.color.primaryContainerText : Theme.color.text
    readonly property color base: active ? Theme.color.primaryContainer : Theme.color.surface

    implicitHeight: 52
    radius: Theme.radius.control
    color: area.pressed ? Qt.tint(base, Theme.alpha(foreground, 0.12))
        : area.containsMouse ? Qt.tint(base, Theme.alpha(foreground, 0.08))
        : base

    Behavior on color {
        ColorAnimation { duration: Theme.anim.fast }
    }

    activeFocusOnTab: true
    Keys.onReturnPressed: clicked()
    Keys.onEnterPressed: clicked()
    Keys.onSpacePressed: clicked()
    Keys.onRightPressed: if (hasDetails) detailsClicked()

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    Row {
        anchors.left: parent.left
        anchors.right: details.visible ? details.left : parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Theme.spacing.md
        anchors.rightMargin: Theme.spacing.xs
        spacing: Theme.spacing.md

        SymbolIcon {
            anchors.verticalCenter: parent.verticalCenter
            implicitSize: 18
            name: root.icon
            color: root.foreground
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 18 - parent.spacing

            StyledText {
                width: parent.width
                text: root.title
                color: root.foreground
                font.weight: Theme.font.medium
            }

            StyledText {
                width: parent.width
                text: root.subtitle
                color: root.active ? root.foreground : Theme.color.textMuted
                font.pixelSize: Theme.font.caption
                visible: text !== ""
            }
        }
    }

    IconButton {
        id: details

        anchors.right: parent.right
        anchors.rightMargin: Theme.spacing.xs
        anchors.verticalCenter: parent.verticalCenter
        visible: root.hasDetails
        icon: "go-next-symbolic"
        iconSize: 14
        iconColor: root.foreground
        stateColor: root.foreground
        // С клавиатуры подробности открываются стрелкой вправо на самой плитке.
        activeFocusOnTab: false
        onClicked: root.detailsClicked()
    }

    FocusRing {}
}
