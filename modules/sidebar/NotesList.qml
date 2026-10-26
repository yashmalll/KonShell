import QtQuick
import qs.config
import qs.services
import qs.widgets

// Заметки в боковой панели: поиск по имени и все .md-файлы папки заметок, новые
// сверху. Клик — окно заметки (просмотр и правка); «+» — новая заметка.
Item {
    id: root

    property alias query: search.text

    function focusSearch() {
        search.forceActiveFocus();
    }

    // Сколько заметок подходит под поиск — для пустого состояния.
    readonly property int matches: {
        // Пока папки нет, модель смотрит в текущий каталог — не считаем.
        if (!Notes.exists)
            return 0;
        let n = 0;
        for (let i = 0; i < Notes.recent.count; i++) {
            if (matchesQuery(Notes.recent.get(i, "fileBaseName")))
                n++;
        }
        return n;
    }

    function matchesQuery(name) {
        const q = search.text.trim().toLowerCase();
        return q === "" || name.toLowerCase().includes(q);
    }

    // Заголовок блока: название и действия.
    Item {
        id: header

        width: parent.width
        height: 32

        StyledText {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Заметки"
            font.pixelSize: Theme.font.title
            font.weight: Theme.font.medium
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacing.xxs

            IconButton {
                icon: "folder-documents-symbolic"
                Accessible.name: "Открыть папку заметок"
                onClicked: {
                    Ui.sidebarOpen = false;
                    Notes.openFolder();
                }
            }

            IconButton {
                implicitWidth: 30
                implicitHeight: 30
                baseColor: Theme.color.primary
                stateColor: Theme.color.primaryText
                iconColor: Theme.color.primaryText
                icon: "list-add-symbolic"
                Accessible.name: "Новая заметка"
                onClicked: Ui.openNote("")
            }
        }
    }

    // Поиск по именам заметок.
    Rectangle {
        id: searchBox

        anchors.top: header.bottom
        anchors.topMargin: Theme.spacing.sm
        width: parent.width
        height: 34
        radius: Theme.radius.control
        color: Theme.color.surface
        border.width: search.activeFocus ? 2 : 0
        border.color: Theme.color.focus

        SymbolIcon {
            id: searchIcon

            anchors.left: parent.left
            anchors.leftMargin: Theme.spacing.sm
            anchors.verticalCenter: parent.verticalCenter
            implicitSize: 14
            name: "system-search-symbolic"
            color: Theme.color.textMuted
        }

        TextInput {
            id: search

            anchors.left: searchIcon.right
            anchors.right: parent.right
            anchors.leftMargin: Theme.spacing.sm
            anchors.rightMargin: Theme.spacing.sm
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.color.text
            selectionColor: Theme.color.selection
            font.family: Theme.font.family
            font.pixelSize: Theme.font.body
            clip: true
            activeFocusOnTab: true

            StyledText {
                anchors.fill: parent
                text: "Поиск заметок"
                color: Theme.color.textMuted
                visible: search.text === ""
            }
        }
    }

    // Пусто: заметок нет или ничего не нашлось. Поверх области списка — иначе
    // список (Flickable) перехватывал бы клики по кнопке.
    Column {
        anchors.top: searchBox.bottom
        anchors.topMargin: Theme.spacing.xl
        width: parent.width
        spacing: Theme.spacing.md
        visible: root.matches === 0
        z: 1

        StyledText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: search.text !== "" ? "Ничего не нашлось" : "Заметок пока нет"
            color: Theme.color.textMuted
        }

        TextButton {
            anchors.horizontalCenter: parent.horizontalCenter
            primary: true
            text: "Новая заметка"
            visible: search.text === ""
            onClicked: Ui.openNote("")
        }
    }

    Flickable {
        id: list

        anchors.top: searchBox.bottom
        anchors.topMargin: Theme.spacing.sm
        anchors.bottom: parent.bottom
        width: parent.width
        contentWidth: width
        contentHeight: rows.implicitHeight
        visible: root.matches > 0
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: rows

            width: list.width
            spacing: Theme.spacing.xxs

            Repeater {
                model: Notes.exists ? Notes.recent : null

                Rectangle {
                    id: noteRow

                    required property string fileBaseName
                    required property string filePath
                    required property date fileModified

                    width: rows.width
                    height: visible ? 44 : 0
                    visible: root.matchesQuery(fileBaseName)
                    radius: Theme.radius.control
                    color: noteArea.pressed ? Theme.color.pressed
                        : noteArea.containsMouse ? Theme.color.hover
                        : "transparent"

                    Behavior on color {
                        ColorAnimation { duration: Theme.anim.fast }
                    }

                    Rectangle {
                        id: noteBadge

                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacing.sm
                        anchors.verticalCenter: parent.verticalCenter
                        width: 28
                        height: 28
                        radius: Theme.radius.control
                        color: Theme.color.surfaceVariant

                        SymbolIcon {
                            anchors.centerIn: parent
                            implicitSize: 14
                            name: "text-x-generic-symbolic"
                            color: Theme.color.textMuted
                        }
                    }

                    Column {
                        anchors.left: noteBadge.right
                        anchors.right: parent.right
                        anchors.leftMargin: Theme.spacing.sm
                        anchors.rightMargin: Theme.spacing.sm
                        anchors.verticalCenter: parent.verticalCenter

                        StyledText {
                            width: parent.width
                            text: Notes.displayName(noteRow.fileBaseName)
                            elide: Text.ElideRight
                        }

                        StyledText {
                            width: parent.width
                            text: Notes.ago(noteRow.fileModified)
                            color: Theme.color.textMuted
                            font.pixelSize: Theme.font.caption
                        }
                    }

                    MouseArea {
                        id: noteArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Ui.openNote(noteRow.filePath)
                    }
                }
            }
        }
    }
}
