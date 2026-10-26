import QtQuick
import qs.config

// Рамка клавиатурного фокуса вокруг родителя. Видна только при фокусе
// с клавиатуры (activeFocus), мышь её не показывает.
Rectangle {
    readonly property Item target: parent

    anchors.fill: parent
    anchors.margins: -3
    radius: (target?.radius ?? Theme.radius.control) + 3
    color: "transparent"
    border.width: 2
    border.color: Theme.color.focus
    visible: target?.activeFocus ?? false
}
