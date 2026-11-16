import QtQuick
import QtQuick.Layouts
import qs.config
import qs.widgets

Rectangle {
    id: destination
    property string icon
    property string label
    signal triggered
    width: (parent.width - parent.spacing * (parent.columns - 1)) / parent.columns
    implicitHeight: 54
    radius: 14
    color: hover.hovered ? Theme.alpha(Theme.color.primary, 0.16) : Theme.color.surface
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: label
    Keys.onReturnPressed: triggered()
    Keys.onEnterPressed: triggered()
    Keys.onSpacePressed: triggered()
    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8
        SymbolIcon { name: destination.icon; color: Theme.color.primary; implicitSize: 16 }
        StyledText { text: destination.label; Layout.fillWidth: true; font.pixelSize: Theme.font.caption }
    }
    HoverHandler { id: hover }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: destination.triggered() }
    FocusRing {}
}

