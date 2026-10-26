import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// Окно заметки поверх затемнённого экрана (Ui.noteOpen, Ui.notePath).
//   Новая (notePath пуст): заголовок и текст в Markdown → новый .md-файл
//     (как быстрая заметка под часами). Закрыли, не сохранив, — черновик остаётся.
//   Существующая: просмотр с оформлением Markdown; «Изменить» — правка исходного
//     текста и сохранение в тот же файл; открыть во внешнем редакторе; удалить в корзину.
// Ctrl+Enter или Ctrl+S — сохранить; Esc — из правки к просмотру, из просмотра — закрыть.
Scope {
    id: root

    PopupLoader {
        id: popup

        open: Ui.noteOpen
        keepLoaded: false

        PanelWindow {
            id: window

            readonly property string path: Ui.notePath
            readonly property bool isNew: path === ""
            property bool editing: false
            property bool confirmDelete: false
            readonly property string baseName: path.split("/").pop().replace(/\.md$/, "")

            function close() {
                if (isNew) {
                    Notes.draftTitle = titleInput.text;
                    Notes.draftBody = bodyInput.text;
                }
                Ui.noteOpen = false;
            }

            function save() {
                if (isNew) {
                    Notes.create(titleInput.text, bodyInput.text);
                } else if (editing) {
                    Notes.write(path, bodyInput.text);
                }
            }

            function startEditing() {
                bodyInput.text = file.text();
                editing = true;
                Qt.callLater(() => bodyInput.forceActiveFocus());
            }

            visible: popup.windowVisible
            screen: Quickshell.screens.find(s => s.name === Niri.focusedWorkspace?.output) ?? null
            WlrLayershell.namespace: "konshell-note"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: popup.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: "transparent"

            // Сохранено: новая заметка открывается на просмотр, правка — возвращается к нему.
            Connections {
                target: Notes

                function onSaved(path) {
                    if (window.isNew) {
                        Notes.draftTitle = "";
                        Notes.draftBody = "";
                        Ui.notePath = path;
                    }
                    window.editing = false;
                    file.reload();
                }
            }

            FileView {
                id: file

                path: window.path
                printErrors: false
                watchChanges: true
                onFileChanged: reload()
            }

            // Затемнение; клик по нему закрывает окно.
            Rectangle {
                anchors.fill: parent
                color: Theme.color.scrim
                opacity: popup.open ? 1 : 0

                Behavior on opacity {
                    NumberAnimation { duration: Theme.anim.normal }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: window.close()
                }
            }

            PopupSurface {
                id: card

                shown: popup.open
                anchors.centerIn: parent
                width: Math.min(720, window.width - 80)
                height: Math.min(620, window.height - 120)
                elevated: true
                color: Theme.color.popup
                focus: true

                Component.onCompleted: {
                    if (window.isNew) {
                        titleInput.text = Notes.draftTitle;
                        bodyInput.text = Notes.draftBody;
                        titleInput.forceActiveFocus();
                    } else {
                        card.forceActiveFocus();
                    }
                }

                Keys.onEscapePressed: {
                    if (window.editing && !window.isNew)
                        window.editing = false;
                    else
                        window.close();
                }
                Keys.onPressed: event => {
                    if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_S) {
                        window.save();
                        event.accepted = true;
                    }
                }

                // Клики внутри карточки не закрывают окно.
                MouseArea {
                    anchors.fill: parent
                }

                // Шапка: название и действия.
                Item {
                    id: header

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.spacing.lg
                    height: 34

                    StyledText {
                        anchors.left: parent.left
                        anchors.right: actions.left
                        anchors.rightMargin: Theme.spacing.md
                        anchors.verticalCenter: parent.verticalCenter
                        text: window.isNew ? "Новая заметка" : Notes.displayName(window.baseName)
                        font.pixelSize: Theme.font.title
                        font.weight: Theme.font.medium
                        elide: Text.ElideRight
                    }

                    Row {
                        id: actions

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacing.xxs

                        TextButton {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !window.isNew
                            text: window.editing ? "Просмотр" : "Изменить"
                            onClicked: window.editing ? window.editing = false : window.startEditing()
                        }

                        IconButton {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !window.isNew
                            icon: "document-edit-symbolic"
                            Accessible.name: "Открыть во внешнем редакторе"
                            onClicked: {
                                Notes.open(window.path);
                                window.close();
                            }
                        }

                        // Удаление — в два нажатия: первое спрашивает.
                        TextButton {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !window.isNew && window.confirmDelete
                            text: "Удалить?"
                            primary: true
                            onClicked: {
                                Notes.remove(window.path);
                                window.confirmDelete = false;
                                Ui.noteOpen = false;
                            }
                        }

                        IconButton {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !window.isNew && !window.confirmDelete
                            icon: "user-trash-symbolic"
                            Accessible.name: "Удалить заметку"
                            onClicked: {
                                window.confirmDelete = true;
                                deleteTimer.restart();
                            }
                        }

                        IconButton {
                            anchors.verticalCenter: parent.verticalCenter
                            icon: "window-close-symbolic"
                            Accessible.name: "Закрыть"
                            onClicked: window.close()
                        }
                    }

                    Timer {
                        id: deleteTimer

                        interval: 4000
                        onTriggered: window.confirmDelete = false
                    }
                }

                // Заголовок новой заметки.
                TextInput {
                    id: titleInput

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: header.bottom
                    anchors.leftMargin: Theme.spacing.lg
                    anchors.rightMargin: Theme.spacing.lg
                    anchors.topMargin: Theme.spacing.md
                    height: visible ? 32 : 0
                    visible: window.isNew
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.color.text
                    selectionColor: Theme.color.selection
                    selectedTextColor: Theme.color.text
                    font.family: Theme.font.family
                    font.pixelSize: Theme.font.title
                    font.weight: Theme.font.medium
                    clip: true
                    activeFocusOnTab: true

                    // Enter — к тексту, Ctrl+Enter — сохранить.
                    function onEnter(event) {
                        if (event.modifiers & Qt.ControlModifier)
                            window.save();
                        else
                            bodyInput.forceActiveFocus();
                    }
                    Keys.onReturnPressed: event => onEnter(event)
                    Keys.onEnterPressed: event => onEnter(event)

                    StyledText {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        text: "Заголовок"
                        color: Theme.color.textMuted
                        font.pixelSize: Theme.font.title
                        font.weight: Theme.font.medium
                        visible: titleInput.text === ""
                    }
                }

                // Поле текста (правка) или оформленный Markdown (просмотр).
                Rectangle {
                    id: body

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: titleInput.bottom
                    anchors.bottom: footer.top
                    anchors.margins: Theme.spacing.lg
                    anchors.topMargin: Theme.spacing.sm
                    radius: Theme.radius.control
                    color: window.isNew || window.editing ? Theme.color.surface : "transparent"
                    border.width: bodyInput.activeFocus ? 2 : 0
                    border.color: Theme.color.focus

                    Flickable {
                        id: scroll

                        anchors.fill: parent
                        anchors.margins: Theme.spacing.md
                        contentWidth: width
                        contentHeight: (window.isNew || window.editing ? bodyInput : preview).implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        function ensureVisible(r) {
                            if (contentY >= r.y)
                                contentY = r.y;
                            else if (contentY + height <= r.y + r.height)
                                contentY = r.y + r.height - height;
                        }

                        TextEdit {
                            id: bodyInput

                            width: scroll.width
                            visible: window.isNew || window.editing
                            wrapMode: TextEdit.Wrap
                            color: Theme.color.text
                            selectionColor: Theme.color.selection
                            selectedTextColor: Theme.color.text
                            font.family: Theme.font.family
                            font.pixelSize: Theme.font.body
                            selectByMouse: true
                            activeFocusOnTab: true
                            onCursorRectangleChanged: scroll.ensureVisible(cursorRectangle)

                            // Ctrl+Enter — сохранить, просто Enter — новая строка.
                            function onEnter(event) {
                                if (event.modifiers & Qt.ControlModifier)
                                    window.save();
                                else
                                    event.accepted = false;
                            }
                            Keys.onReturnPressed: event => onEnter(event)
                            Keys.onEnterPressed: event => onEnter(event)

                            StyledText {
                                width: parent.width
                                text: window.isNew ? "Текст в Markdown: списки, **жирный**, ссылки…" : ""
                                color: Theme.color.textMuted
                                visible: bodyInput.text === ""
                            }
                        }

                        TextEdit {
                            id: preview

                            width: scroll.width
                            visible: !window.isNew && !window.editing
                            readOnly: true
                            selectByMouse: true
                            textFormat: TextEdit.MarkdownText
                            wrapMode: TextEdit.Wrap
                            text: file.text()
                            color: Theme.color.text
                            selectionColor: Theme.color.selection
                            selectedTextColor: Theme.color.text
                            font.family: Theme.font.family
                            font.pixelSize: Theme.font.body
                            onLinkActivated: link => Qt.openUrlExternally(link)

                            HoverHandler {
                                cursorShape: preview.hoveredLink !== "" ? Qt.PointingHandCursor : Qt.IBeamCursor
                            }
                        }
                    }
                }

                // Подсказка, ошибка и «Сохранить».
                Item {
                    id: footer

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: Theme.spacing.lg
                    height: 30

                    StyledText {
                        anchors.left: parent.left
                        anchors.right: saveButton.left
                        anchors.rightMargin: Theme.spacing.sm
                        anchors.verticalCenter: parent.verticalCenter
                        text: Notes.lastError !== "" ? Notes.lastError
                            : window.isNew || window.editing ? "Ctrl+Enter — сохранить · Esc — " + (window.isNew ? "закрыть (черновик останется)" : "отменить")
                            : "Esc — закрыть · ссылки открываются по клику"
                        color: Notes.lastError !== "" ? Theme.color.error : Theme.color.textMuted
                        font.pixelSize: Theme.font.caption
                        elide: Text.ElideRight
                    }

                    TextButton {
                        id: saveButton

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        visible: window.isNew || window.editing
                        primary: true
                        text: Notes.saving ? "Сохраняю…" : "Сохранить"
                        enabled: !Notes.saving && (!window.isNew || titleInput.text.trim() !== "" || bodyInput.text.trim() !== "")
                        onClicked: window.save()
                    }
                }
            }
        }
    }
}
