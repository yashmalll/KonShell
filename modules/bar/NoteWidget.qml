import QtQuick
import qs.config
import qs.services
import qs.widgets

// Виджет панели «note»: кнопка быстрой заметки — открывает панель под часами
// с курсором в поле новой заметки (как IPC dashboard note).
Rectangle {
    id: root

    implicitWidth: implicitHeight
    implicitHeight: Math.max(24, Settings.bar.height - 8)
    radius: Theme.radius.control
    color: area.containsMouse ? Theme.color.hover : "transparent"

    Behavior on color {
        ColorAnimation { duration: Theme.anim.fast }
    }

    SymbolIcon {
        anchors.centerIn: parent
        name: "accessories-text-editor-symbolic"
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Ui.openDashboard(true)
    }
}
