import QtQuick
import qs.config

// Кнопка с текстом. По умолчанию — заливка поверхностью (второстепенное действие),
// primary — заливка акцентом (одно главное действие в группе).
Rectangle {
    id: root

    property alias text: label.text
    property bool primary: false

    signal clicked

    readonly property color foreground: primary ? Theme.color.primaryText : Theme.color.text
    readonly property color base: primary ? Theme.color.primary : Theme.color.surface

    implicitWidth: label.implicitWidth + Theme.spacing.lg * 2
    implicitHeight: 30
    radius: Theme.radius.control
    opacity: enabled ? 1 : 0.38
    color: area.pressed ? Qt.tint(base, Theme.alpha(foreground, 0.12))
        : area.containsMouse && enabled ? Qt.tint(base, Theme.alpha(foreground, 0.08))
        : base

    activeFocusOnTab: enabled
    Keys.onReturnPressed: clicked()
    Keys.onEnterPressed: clicked()
    Keys.onSpacePressed: clicked()

    StyledText {
        id: label

        anchors.centerIn: parent
        color: root.foreground
        font.pixelSize: Theme.font.caption
        font.weight: Theme.font.medium
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    FocusRing {}
}
