import QtQuick
import qs.config

// Строка списка: иконка, заголовок, подпись, отметка справа.
// Дочерние элементы показываются под строкой, когда expanded.
// Клик, Enter или пробел вызывают clicked().
Rectangle {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool checked: false
    property bool expanded: false
    property bool highlighted: false

    default property alias extra: extraColumn.data

    signal clicked

    implicitHeight: column.implicitHeight
    radius: Theme.radius.control
    color: expanded || highlighted ? Theme.color.surface
        : area.pressed ? Theme.color.pressed
        : area.containsMouse ? Theme.color.hover
        : "transparent"

    activeFocusOnTab: true
    Keys.onReturnPressed: clicked()
    Keys.onEnterPressed: clicked()
    Keys.onSpacePressed: clicked()

    Column {
        id: column

        width: parent.width

        Item {
            width: parent.width
            implicitHeight: 44

            MouseArea {
                id: area

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.clicked()
            }

            SymbolIcon {
                id: icon

                anchors.left: parent.left
                anchors.leftMargin: Theme.spacing.md
                anchors.verticalCenter: parent.verticalCenter
                implicitSize: 16
                name: root.icon
                color: root.checked ? Theme.color.primary : Theme.color.text
                visible: root.icon !== ""
            }

            Column {
                anchors.left: icon.visible ? icon.right : parent.left
                anchors.right: check.visible ? check.left : parent.right
                anchors.leftMargin: Theme.spacing.md
                anchors.rightMargin: Theme.spacing.sm
                anchors.verticalCenter: parent.verticalCenter

                StyledText {
                    width: parent.width
                    text: root.title
                    font.weight: root.checked ? Theme.font.medium : Theme.font.regular
                }

                StyledText {
                    width: parent.width
                    text: root.subtitle
                    color: Theme.color.textMuted
                    font.pixelSize: Theme.font.caption
                    visible: text !== ""
                }
            }

            // Выбранное отмечено и цветом, и формой (галочкой), не только цветом.
            SymbolIcon {
                id: check

                anchors.right: parent.right
                anchors.rightMargin: Theme.spacing.md
                anchors.verticalCenter: parent.verticalCenter
                name: "object-select-symbolic"
                color: Theme.color.primary
                visible: root.checked
            }
        }

        Column {
            id: extraColumn

            x: Theme.spacing.md
            width: parent.width - Theme.spacing.md * 2
            spacing: Theme.spacing.sm
            bottomPadding: Theme.spacing.md
            visible: root.expanded
        }
    }

    FocusRing {}
}
