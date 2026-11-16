import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.widgets

RowLayout {
    spacing: 6
    StyledText { text: "Профиль"; color: Theme.color.textMuted; font.pixelSize: Theme.font.caption }
    Item { Layout.fillWidth: true }
    Repeater {
        model: [{ id: "custom", name: "Мой" }, { id: "work", name: "Работа" }, { id: "rest", name: "Отдых" }]
        TextButton {
            required property var modelData
            text: modelData.name
            primary: Profiles.current === modelData.id
            onClicked: Profiles.select(modelData.id)
        }
    }
}
