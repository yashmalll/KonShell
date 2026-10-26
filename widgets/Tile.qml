import QtQuick
import qs.config

// Плитка быстрого переключателя: значок в круге, название, состояние.
// Включённая — мягкая заливка primaryContainer и акцентный круг под значком:
// состояние видно и по форме, а не только по оттенку фона.
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

    implicitHeight: 60
    radius: Theme.radius.panel
    opacity: enabled ? 1 : 0.5
    color: area.pressed ? Qt.tint(base, Theme.alpha(foreground, 0.12))
        : area.containsMouse ? Qt.tint(base, Theme.alpha(foreground, 0.08))
        : base

    Behavior on color {
        ColorAnimation { duration: Theme.anim.fast }
    }

    activeFocusOnTab: enabled
    Keys.onReturnPressed: clicked()
    Keys.onEnterPressed: clicked()
    Keys.onSpacePressed: clicked()
    Keys.onRightPressed: if (hasDetails) detailsClicked()

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    // Значок в круге: у включённой плитки круг акцентный.
    Rectangle {
        id: badge

        anchors.left: parent.left
        anchors.leftMargin: Theme.spacing.sm + 2
        anchors.verticalCenter: parent.verticalCenter
        width: 36
        height: 36
        radius: Theme.radius.full
        color: root.active ? Theme.color.primary : Theme.color.surfaceVariant

        Behavior on color {
            ColorAnimation { duration: Theme.anim.fast }
        }

        SymbolIcon {
            anchors.centerIn: parent
            implicitSize: 18
            name: root.icon
            color: root.active ? Theme.color.primaryText : Theme.color.text
        }
    }

    Column {
        anchors.left: badge.right
        anchors.right: details.visible ? details.left : parent.right
        anchors.leftMargin: Theme.spacing.sm
        anchors.rightMargin: details.visible ? 0 : Theme.spacing.sm
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        StyledText {
            width: parent.width
            text: root.title
            color: root.foreground
            font.weight: Theme.font.medium
            elide: Text.ElideRight
        }

        StyledText {
            width: parent.width
            text: root.subtitle
            color: root.active ? Theme.alpha(root.foreground, 0.8) : Theme.color.textMuted
            font.pixelSize: Theme.font.caption
            elide: Text.ElideRight
            visible: text !== ""
        }
    }

    IconButton {
        id: details

        anchors.right: parent.right
        anchors.rightMargin: Theme.spacing.xxs
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
