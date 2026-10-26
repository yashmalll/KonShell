import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.config
import qs.services
import qs.widgets

// Лаунчер приложений. Открывается через IPC:
//   qs -c konshell ipc call launcher toggle
// Окно создаётся заново при каждом открытии, поэтому поиск всегда пустой.
Scope {
    id: root

    property bool shown: false

    // Обзор niri открыт — лаунчер с захватом клавиатуры мешал бы им управлять.
    Connections {
        target: Niri

        function onOverviewOpenChanged() {
            if (Niri.overviewOpen)
                root.shown = false;
        }
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            root.shown = !root.shown;
        }
        function open(): void {
            root.shown = true;
        }
        function close(): void {
            root.shown = false;
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
                    search.forceActiveFocus();
                }
            }

            // Открываем на мониторе со сфокусированным рабочим столом.
            screen: Quickshell.screens.find(s => s.name === Niri.focusedWorkspace?.output) ?? null
            WlrLayershell.namespace: "konshell-launcher"
            // Размытие только под панелью, а не под всем прозрачным окном.
            BackgroundEffect.blurRegion: Region {
                item: box.blurItem
                radius: Theme.radius.panel
            }

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

            // Клик мимо окна закрывает лаунчер.
            MouseArea {
                anchors.fill: parent
                onClicked: root.shown = false
            }

            PopupSurface {
                id: box

                shown: popup.open

                readonly property int itemHeight: 44

                anchors.horizontalCenter: parent.horizontalCenter
                // Чуть выше центра по правилу третей: взгляд сразу попадает в поле.
                y: parent.height * 0.22
                width: Settings.launcher.width
                height: content.implicitHeight + Theme.spacing.sm * 2

                // Поглощает клики внутри окна, чтобы они не закрывали лаунчер.
                MouseArea {
                    anchors.fill: parent
                }

                Column {
                    id: content

                    anchors.fill: parent
                    anchors.margins: Theme.spacing.sm
                    spacing: Theme.spacing.sm

                    // Поле поиска без заливки: фокус в нём всегда, пока лаунчер открыт,
                    // поэтому вместо рамки — иконка и линия под полем.
                    Item {
                        width: parent.width
                        height: 48

                        SymbolIcon {
                            id: searchIcon

                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacing.md
                            anchors.verticalCenter: parent.verticalCenter
                            implicitSize: 18
                            name: "system-search-symbolic"
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

                            anchors.fill: parent
                            anchors.leftMargin: searchIcon.x + searchIcon.width + Theme.spacing.md
                            anchors.rightMargin: Theme.spacing.md
                            verticalAlignment: TextInput.AlignVCenter
                            color: Theme.color.text
                            selectionColor: Theme.color.selection
                            selectedTextColor: Theme.color.text
                            font.family: Theme.font.family
                            font.pixelSize: Theme.font.title
                            focus: true

                            onTextChanged: list.currentIndex = 0

                            Keys.onPressed: event => {
                                switch (event.key) {
                                case Qt.Key_Escape:
                                    root.shown = false;
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
                                    list.launch(list.currentIndex);
                                    break;
                                default:
                                    return;
                                }
                                event.accepted = true;
                            }

                            StyledText {
                                anchors.fill: parent
                                text: "Поиск приложений"
                                color: Theme.color.textMuted
                                font.pixelSize: Theme.font.title
                                visible: search.text === ""
                            }
                        }
                    }

                    ListView {
                        id: list

                        function launch(index) {
                            const app = model.values[index];
                            if (!app)
                                return;
                            Apps.recordLaunch(app);
                            app.execute();
                            root.shown = false;
                        }

                        width: parent.width
                        height: Math.min(count, Settings.launcher.maxVisible) * box.itemHeight
                        visible: count > 0
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        highlightMoveDuration: Theme.anim.fast
                        keyNavigationWraps: true

                        model: ScriptModel {
                            values: Apps.search(search.text)
                        }

                        highlight: Rectangle {
                            radius: Theme.radius.control
                            color: Theme.color.active
                        }

                        delegate: Item {
                            id: entry

                            required property DesktopEntry modelData
                            required property int index

                            readonly property bool current: ListView.isCurrentItem

                            width: ListView.view.width
                            height: box.itemHeight

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.spacing.sm
                                anchors.rightMargin: Theme.spacing.sm
                                spacing: Theme.spacing.md

                                IconImage {
                                    anchors.verticalCenter: parent.verticalCenter
                                    implicitSize: 28
                                    visible: Settings.launcher.showIcons
                                    source: Quickshell.iconPath(entry.modelData.icon, "application-x-executable")
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - (Settings.launcher.showIcons ? 28 + Theme.spacing.md : 0)

                                    StyledText {
                                        width: parent.width
                                        text: entry.modelData.name
                                        color: entry.current ? Theme.color.activeText : Theme.color.text
                                    }

                                    StyledText {
                                        width: parent.width
                                        text: entry.modelData.comment || entry.modelData.genericName
                                        // textMuted проверен по контрасту только на поверхностях, не на active.
                                        color: entry.current ? Theme.color.activeText : Theme.color.textMuted
                                        font.pixelSize: Theme.font.caption
                                        visible: text !== "" && Settings.launcher.showDescriptions
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                // Только при движении мыши: окно открывается под неподвижным
                                // курсором, и onEntered увёл бы выделение с первого результата.
                                onPositionChanged: list.currentIndex = entry.index
                                onClicked: list.launch(entry.index)
                            }
                        }
                    }

                    StyledText {
                        width: parent.width
                        height: box.itemHeight
                        horizontalAlignment: Text.AlignHCenter
                        text: "Ничего не найдено"
                        color: Theme.color.textMuted
                        visible: list.count === 0
                    }
                }
            }
        }
    }
}
