import QtQuick
import qs.config
import qs.services
import qs.widgets

// Быстрая заметка в Markdown: заголовок и текст → новый .md-файл в папке заметок
// (services/Notes.qml). Ctrl+Enter — сохранить. Ниже — последние заметки,
// клик открывает в редакторе.
Column {
    id: root

    property string savedPath: ""

    function focusInput() {
        titleInput.forceActiveFocus();
    }

    function save() {
        if (Notes.create(titleInput.text, bodyInput.text)) {
            titleInput.text = "";
            bodyInput.text = "";
        }
    }

    spacing: Theme.spacing.sm

    Connections {
        target: Notes

        function onSaved(path) {
            root.savedPath = path;
            savedTimer.restart();
        }
    }

    Timer {
        id: savedTimer

        interval: 4000
        onTriggered: root.savedPath = ""
    }

    // Заголовок блока.
    Item {
        width: parent.width
        height: 28

        SectionLabel {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Заметка"
        }

        IconButton {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            icon: "folder-documents-symbolic"
            Accessible.name: "Открыть папку заметок"
            onClicked: {
                Ui.dashboardOpen = false;
                Notes.openFolder();
            }
        }
    }

    // Поле ввода: заголовок и текст в одной карточке.
    Rectangle {
        width: parent.width
        height: editor.implicitHeight
        radius: Theme.radius.control
        color: Theme.color.surface
        border.width: titleInput.activeFocus || bodyInput.activeFocus ? 2 : 1
        border.color: titleInput.activeFocus || bodyInput.activeFocus ? Theme.color.focus : Theme.color.border

        Behavior on border.color {
            ColorAnimation { duration: Theme.anim.fast }
        }

        Column {
            id: editor

            width: parent.width
            topPadding: Theme.spacing.sm
            bottomPadding: Theme.spacing.sm

            TextInput {
                id: titleInput

                x: Theme.spacing.md
                width: parent.width - Theme.spacing.md * 2
                height: 26
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.color.text
                selectionColor: Theme.color.selection
                selectedTextColor: Theme.color.text
                font.family: Theme.font.family
                font.pixelSize: Theme.font.body
                font.weight: Theme.font.medium
                clip: true
                activeFocusOnTab: true

                // Enter — к тексту, Ctrl+Enter — сохранить.
                function onEnter(event) {
                    if (event.modifiers & Qt.ControlModifier)
                        root.save();
                    else
                        bodyInput.forceActiveFocus();
                }
                Keys.onReturnPressed: event => onEnter(event)
                Keys.onEnterPressed: event => onEnter(event)

                StyledText {
                    anchors.fill: parent
                    text: "Заголовок"
                    color: Theme.color.textMuted
                    font.weight: Theme.font.medium
                    visible: titleInput.text === ""
                }
            }

            Rectangle {
                x: Theme.spacing.md
                width: parent.width - Theme.spacing.md * 2
                height: 1
                color: Theme.color.border
            }

            Flickable {
                id: bodyScroll

                x: Theme.spacing.md
                width: parent.width - Theme.spacing.md * 2
                height: 96
                contentWidth: width
                contentHeight: bodyInput.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                // Курсор всегда в видимой части.
                function ensureVisible(r) {
                    if (contentY >= r.y)
                        contentY = r.y;
                    else if (contentY + height <= r.y + r.height)
                        contentY = r.y + r.height - height;
                }

                TextEdit {
                    id: bodyInput

                    width: bodyScroll.width
                    topPadding: Theme.spacing.sm
                    bottomPadding: Theme.spacing.sm
                    wrapMode: TextEdit.Wrap
                    color: Theme.color.text
                    selectionColor: Theme.color.selection
                    selectedTextColor: Theme.color.text
                    font.family: Theme.font.family
                    font.pixelSize: Theme.font.body
                    activeFocusOnTab: true
                    onCursorRectangleChanged: bodyScroll.ensureVisible(cursorRectangle)

                    // Ctrl+Enter — сохранить, просто Enter — новая строка.
                    function onEnter(event) {
                        if (event.modifiers & Qt.ControlModifier)
                            root.save();
                        else
                            event.accepted = false;
                    }
                    Keys.onReturnPressed: event => onEnter(event)
                    Keys.onEnterPressed: event => onEnter(event)

                    StyledText {
                        y: bodyInput.topPadding
                        width: parent.width
                        text: "Текст в Markdown: списки, **жирный**, ссылки…"
                        color: Theme.color.textMuted
                        visible: bodyInput.text === ""
                    }
                }
            }
        }
    }

    // Действия и состояние сохранения.
    Item {
        width: parent.width
        height: 30

        StyledText {
            anchors.left: parent.left
            anchors.right: saveButton.left
            anchors.rightMargin: Theme.spacing.sm
            anchors.verticalCenter: parent.verticalCenter
            text: Notes.lastError !== "" ? Notes.lastError
                : root.savedPath !== "" ? "Сохранено: " + root.savedPath.split("/").pop()
                : "Ctrl+Enter — сохранить"
            color: Notes.lastError !== "" ? Theme.color.error
                : root.savedPath !== "" ? Theme.color.success
                : Theme.color.textMuted
            font.pixelSize: Theme.font.caption
        }

        TextButton {
            id: saveButton

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            primary: true
            text: Notes.saving ? "Сохраняю…" : "Сохранить"
            enabled: !Notes.saving && (titleInput.text.trim() !== "" || bodyInput.text.trim() !== "")
            onClicked: root.save()
        }
    }

    // Последние заметки.
    Column {
        width: parent.width
        spacing: Theme.spacing.xxs
        visible: Notes.exists && Notes.recent.count > 0 && Settings.notes.recentCount > 0

        SectionLabel {
            topPadding: Theme.spacing.sm
            bottomPadding: Theme.spacing.xxs
            text: "Последние"
        }

        Repeater {
            model: Notes.exists ? Notes.recent : null

            Rectangle {
                id: noteRow

                required property int index
                required property string fileBaseName
                required property string filePath
                required property date fileModified

                width: parent.width
                height: visible ? 34 : 0
                visible: index < Settings.notes.recentCount
                radius: Theme.radius.control
                color: noteArea.pressed ? Theme.color.pressed
                    : noteArea.containsMouse ? Theme.color.hover
                    : "transparent"

                Behavior on color {
                    ColorAnimation { duration: Theme.anim.fast }
                }

                SymbolIcon {
                    id: noteIcon

                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacing.sm
                    anchors.verticalCenter: parent.verticalCenter
                    implicitSize: 14
                    name: "text-x-generic-symbolic"
                    color: Theme.color.textMuted
                }

                StyledText {
                    anchors.left: noteIcon.right
                    anchors.right: noteTime.left
                    anchors.leftMargin: Theme.spacing.sm
                    anchors.rightMargin: Theme.spacing.sm
                    anchors.verticalCenter: parent.verticalCenter
                    text: noteRow.fileBaseName
                }

                StyledText {
                    id: noteTime

                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacing.sm
                    anchors.verticalCenter: parent.verticalCenter
                    text: Notes.ago(noteRow.fileModified)
                    color: Theme.color.textMuted
                    font.pixelSize: Theme.font.caption
                }

                MouseArea {
                    id: noteArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Ui.dashboardOpen = false;
                        Notes.open(noteRow.filePath);
                    }
                }
            }
        }
    }
}
