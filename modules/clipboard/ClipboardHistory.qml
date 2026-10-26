import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// История буфера обмена (services/Clipboard.qml). Открывается через IPC:
//   qs -c konshell ipc call clipboard toggle
// ↑/↓ — выбор, Enter или клик — скопировать и закрыть, Delete — удалить запись,
// Esc — закрыть. Поиск — по тексту записей.
Scope {
    id: root

    // Открыто ли окно — в Ui, чтобы открывать из настроек и других модулей.
    readonly property bool shown: Ui.clipboardOpen

    // Наблюдатели буфера обмена должны работать с запуска оболочки,
    // а синглтон создаётся при первом обращении — обращаемся сразу.
    readonly property bool watching: Clipboard.enabled

    onShownChanged: {
        if (shown)
            Clipboard.reload();
    }

    Connections {
        target: Niri

        function onOverviewOpenChanged() {
            if (Niri.overviewOpen)
                Ui.clipboardOpen = false;
        }
    }

    IpcHandler {
        target: "clipboard"

        function toggle(): void {
            Ui.clipboardOpen = !Ui.clipboardOpen;
        }
        function open(): void {
            Ui.clipboardOpen = true;
        }
        function close(): void {
            Ui.clipboardOpen = false;
        }
        function wipe(): void {
            Clipboard.wipe();
        }
    }

    PopupLoader {
        id: popup

        open: root.shown

        PanelWindow {

            // Скрытое окно (PopupLoader.keepLoaded) не показывается, но и не удаляется.

            visible: popup.windowVisible

            // Показ скрытого окна — как новое: пустой поиск, первый пункт, курсор в поле.
            onVisibleChanged: {
                if (visible) {
                    search.text = "";
                    list.currentIndex = 0;
                    list.positionViewAtBeginning();
                    wipeButton.armed = false;
                    search.forceActiveFocus();
                }
            }

            screen: Quickshell.screens.find(s => s.name === Niri.focusedWorkspace?.output) ?? null
            WlrLayershell.namespace: "konshell-clipboard"
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
            // Пока сворачивается — клики и клавиатура уже не перехватываются.
            mask: popup.open ? null : closedMask

            Region {
                id: closedMask
            }

            BackgroundEffect.blurRegion: Region {
                item: box.blurItem
                radius: Theme.radius.panel
            }

            MouseArea {
                anchors.fill: parent
                onClicked: Ui.clipboardOpen = false
            }

            PopupSurface {
                id: box

                shown: popup.open

                readonly property int textHeight: 44
                readonly property int imageHeight: 88
                readonly property int maxListHeight: 8 * textHeight

                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height * 0.18
                width: Math.max(Settings.launcher.width, 560)
                height: content.implicitHeight + Theme.spacing.sm * 2

                MouseArea {
                    anchors.fill: parent
                }

                Column {
                    id: content

                    anchors.fill: parent
                    anchors.margins: Theme.spacing.sm
                    spacing: Theme.spacing.sm

                    // Поиск и действия.
                    Item {
                        width: parent.width
                        height: 48

                        SymbolIcon {
                            id: searchIcon

                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacing.md
                            anchors.verticalCenter: parent.verticalCenter
                            implicitSize: 18
                            name: "edit-paste-symbolic"
                            color: Theme.color.textMuted
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: -Theme.spacing.sm
                            anchors.rightMargin: -Theme.spacing.sm
                            height: 1
                            color: Theme.color.border
                        }

                        TextInput {
                            id: search

                            anchors.left: searchIcon.right
                            anchors.right: wipeButton.left
                            anchors.leftMargin: Theme.spacing.md
                            anchors.rightMargin: Theme.spacing.sm
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            verticalAlignment: TextInput.AlignVCenter
                            color: Theme.color.text
                            selectionColor: Theme.color.selection
                            selectedTextColor: Theme.color.text
                            font.family: Theme.font.family
                            font.pixelSize: Theme.font.title
                            clip: true
                            focus: true

                            onTextChanged: list.currentIndex = 0

                            Keys.onPressed: event => {
                                switch (event.key) {
                                case Qt.Key_Escape:
                                    Ui.clipboardOpen = false;
                                    break;
                                case Qt.Key_Down:
                                case Qt.Key_Tab:
                                    list.incrementCurrentIndex();
                                    break;
                                case Qt.Key_Up:
                                case Qt.Key_Backtab:
                                    list.decrementCurrentIndex();
                                    break;
                                case Qt.Key_Return:
                                case Qt.Key_Enter:
                                    list.choose(list.currentIndex);
                                    break;
                                case Qt.Key_Delete:
                                    // Delete в поле с текстом — обычное удаление символа.
                                    if (search.text !== "" && search.cursorPosition < search.text.length)
                                        return;
                                    list.removeAt(list.currentIndex);
                                    break;
                                default:
                                    return;
                                }
                                event.accepted = true;
                            }

                            StyledText {
                                anchors.fill: parent
                                text: "Поиск в истории буфера обмена"
                                color: Theme.color.textMuted
                                font.pixelSize: Theme.font.title
                                visible: search.text === ""
                            }
                        }

                        // Очистить всё — со вторым нажатием для подтверждения.
                        TextButton {
                            id: wipeButton

                            property bool armed: false

                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spacing.xs
                            anchors.verticalCenter: parent.verticalCenter
                            text: armed ? "Точно очистить?" : "Очистить"
                            visible: Clipboard.entries.length > 0
                            onClicked: {
                                if (armed) {
                                    Clipboard.wipe();
                                    armed = false;
                                } else {
                                    armed = true;
                                    disarm.restart();
                                }
                            }

                            Timer {
                                id: disarm

                                interval: 3000
                                onTriggered: wipeButton.armed = false
                            }
                        }
                    }

                    ListView {
                        id: list

                        function choose(index) {
                            const entry = model.values[index];
                            if (!entry)
                                return;
                            Clipboard.copy(entry);
                            Ui.clipboardOpen = false;
                        }

                        function removeAt(index) {
                            const entry = model.values[index];
                            if (entry)
                                Clipboard.remove(entry);
                        }

                        width: parent.width
                        height: Math.min(contentHeight, box.maxListHeight)
                        visible: count > 0
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        highlightMoveDuration: Theme.anim.fast
                        keyNavigationWraps: true

                        model: ScriptModel {
                            values: Clipboard.search(search.text)
                            objectProp: "id"
                        }

                        highlight: Rectangle {
                            radius: Theme.radius.control
                            color: Theme.color.active
                        }

                        delegate: Item {
                            id: entry

                            required property var modelData
                            required property int index

                            readonly property bool current: ListView.isCurrentItem
                            readonly property color foreground: current ? Theme.color.activeText : Theme.color.text
                            readonly property color muted: current ? Theme.color.activeText : Theme.color.textMuted

                            // «[[ binary data 123 KiB png 1920x1080 ]]» → «PNG 1920×1080 · 123 КиБ».
                            readonly property string imageInfo: {
                                const m = modelData.preview.match(/binary data ([\d.]+) (\w+) (\w+)(?: (\d+)x(\d+))?/);
                                if (!m)
                                    return "Картинка";
                                const size = `${m[1]} ${m[2].replace("KiB", "КиБ").replace("MiB", "МиБ").replace("B", "Б")}`;
                                const dims = m[4] ? ` ${m[4]}×${m[5]}` : "";
                                return `${m[3].toUpperCase()}${dims} · ${size}`;
                            }

                            width: ListView.view.width
                            height: modelData.image ? box.imageHeight : box.textHeight

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.spacing.sm
                                anchors.rightMargin: Theme.spacing.sm
                                spacing: Theme.spacing.md

                                // Миниатюра картинки: файл создаётся, только когда строка видна.
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 112
                                    height: box.imageHeight - Theme.spacing.md
                                    radius: Theme.radius.control
                                    color: Theme.color.surface
                                    clip: true
                                    visible: entry.modelData.image

                                    Image {
                                        id: thumb

                                        anchors.fill: parent
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        sourceSize.width: 224
                                        sourceSize.height: 152
                                    }

                                    Process {
                                        running: entry.modelData.image
                                        command: Clipboard.imageCommand(entry.modelData)
                                        stdout: StdioCollector {
                                            onStreamFinished: {
                                                if (text !== "")
                                                    thumb.source = "file://" + text;
                                            }
                                        }
                                    }

                                    SymbolIcon {
                                        anchors.centerIn: parent
                                        name: "image-x-generic-symbolic"
                                        color: Theme.color.textMuted
                                        visible: thumb.status !== Image.Ready
                                    }
                                }

                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - (entry.modelData.image ? 112 + parent.spacing : 0) - removeButton.width - parent.spacing
                                    text: entry.modelData.image ? entry.imageInfo : entry.modelData.preview.trim()
                                    color: entry.modelData.image ? entry.muted : entry.foreground
                                    font.pixelSize: entry.modelData.image ? Theme.font.caption : Theme.font.body
                                    maximumLineCount: 2
                                    wrapMode: Text.Wrap
                                }

                                IconButton {
                                    id: removeButton

                                    anchors.verticalCenter: parent.verticalCenter
                                    icon: "edit-delete-symbolic"
                                    iconColor: entry.muted
                                    stateColor: entry.foreground
                                    opacity: entryArea.containsMouse || entry.current ? 1 : 0
                                    Accessible.name: "Удалить из истории"
                                    onClicked: Clipboard.remove(entry.modelData)
                                }
                            }

                            MouseArea {
                                id: entryArea

                                anchors.fill: parent
                                anchors.rightMargin: removeButton.width + Theme.spacing.sm
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPositionChanged: list.currentIndex = entry.index
                                onClicked: list.choose(entry.index)
                            }
                        }
                    }

                    // Пусто или нет пакетов.
                    StyledText {
                        width: parent.width
                        height: box.textHeight
                        horizontalAlignment: Text.AlignHCenter
                        text: !Clipboard.available ? "Нужны пакеты cliphist и wl-clipboard"
                            : !Clipboard.enabled ? "История выключена: «Настройки KonShell» → «Буфер обмена»"
                            : Clipboard.loading ? "Загрузка…"
                            : search.text !== "" ? "Ничего не найдено"
                            : "История пуста — скопируйте что-нибудь"
                        color: Theme.color.textMuted
                        visible: list.count === 0
                    }

                    StyledText {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: "Enter — скопировать · Delete — удалить · Esc — закрыть"
                        color: Theme.color.textDisabled
                        font.pixelSize: Theme.font.caption
                        visible: list.count > 0
                    }
                }
            }
        }
    }
}
