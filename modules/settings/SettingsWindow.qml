import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.widgets
import "../../config/settings-schema.js" as Schema

// Окно «Настройки KonShell» — обычное окно приложения с разделами слева.
// Открывается из лаунчера (пункт «Настройки KonShell»: оболочка сама держит
// ~/.local/share/applications/konshell-settings.desktop), из центра управления
// (строка «Оформление») или через IPC:
//   qs -c konshell ipc call settings open <раздел>: appearance, interface, wallpaper, apps, bar, clock, notes, dock, launcher,
//     clipboard, recorder, notifications, osd, controlCenter, media, sound, keyboard, power, lock
//
// Разделы и параметры описаны в реестре config/settings-schema.js; окно строит
// их само (SettingControl.qml) и ищет по ним. Здесь — только особые блоки и действия.
Scope {
    id: root

    readonly property var sections: Schema.sections

    // ---------- Доступ к значениям для SettingControl ----------

    function read(key) {
        const [group, field] = key.split(".");
        return Settings[group][field];
    }

    function write(key, value) {
        const [group, field] = key.split(".");
        Settings[group][field] = value;
    }

    // Условие when: [ключ, значение] или [ключ, [значения]].
    function shown(option) {
        if (!option.when)
            return true;
        const current = read(option.when[0]);
        return Array.isArray(option.when[1]) ? option.when[1].includes(current) : current === option.when[1];
    }

    // Списки для choicesFrom в реестре настроек.
    function dynamicChoices(name) {
        switch (name) {
        case "cursorThemes":
            return Cursor.themes.map(t => [t, t]);
        }
        return [];
    }

    function runAction(name) {
        switch (name) {
        case "testNotification":
            Quickshell.execDetached(["notify-send", "-a", "KonShell", "Пробное уведомление",
                "Так выглядят уведомления с текущими настройками."]);
            break;
        case "clearNotifications":
            Notifications.clearAll();
            break;
        case "previewLock":
            Lock.preview();
            break;
        case "lockNow":
            Ui.settingsOpen = false;
            Lock.lock("manual");
            break;
        case "newNote":
            Ui.openDashboard(true);
            break;
        case "openNotesFolder":
            Notes.openFolder();
            break;
        case "sessionMenu":
            Ui.sessionOpen = true;
            break;
        case "openClipboard":
            Ui.settingsOpen = false;
            Ui.clipboardOpen = true;
            break;
        case "wipeClipboard":
            Clipboard.wipe();
            break;
        case "recordScreen":
        case "recordRegion":
            // Окно настроек закрывается, иначе оно попало бы в запись.
            Ui.settingsOpen = false;
            ScreenRecorder.start(name === "recordRegion" ? "region" : "screen", 500);
            break;
        }
    }

    // Строка раздела в боковом меню: компактнее ListRow, выбранная — с акцентной меткой слева.
    component NavRow: Rectangle {
        id: row

        property string icon
        property string title
        property bool selected: false

        signal clicked

        implicitHeight: 34
        radius: Theme.radius.control
        color: selected ? Theme.color.surfaceVariant
            : rowArea.pressed ? Theme.color.pressed
            : rowArea.containsMouse ? Theme.color.hover
            : "transparent"

        Behavior on color {
            ColorAnimation { duration: Theme.anim.fast }
        }

        activeFocusOnTab: true
        Keys.onReturnPressed: clicked()
        Keys.onEnterPressed: clicked()
        Keys.onSpacePressed: clicked()

        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 3
            height: row.selected ? 16 : 0
            radius: 2
            color: Theme.color.primary

            Behavior on height {
                NumberAnimation { duration: Theme.anim.normal; easing.type: Theme.anim.enter }
            }
        }

        SymbolIcon {
            id: rowIcon

            anchors.left: parent.left
            anchors.leftMargin: Theme.spacing.md
            anchors.verticalCenter: parent.verticalCenter
            implicitSize: 16
            name: row.icon
            color: row.selected ? Theme.color.primary : Theme.color.text
        }

        StyledText {
            anchors.left: rowIcon.right
            anchors.right: parent.right
            anchors.leftMargin: Theme.spacing.md
            anchors.rightMargin: Theme.spacing.sm
            anchors.verticalCenter: parent.verticalCenter
            text: row.title
            font.weight: row.selected ? Theme.font.medium : Theme.font.regular
        }

        MouseArea {
            id: rowArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.clicked()
        }

        FocusRing {}
    }

    function customComponent(name) {
        return ({ wallpaperGrid: wallpaperGrid, barLayout: barLayout, dashboardLayout: dashboardLayout,
            pin: pinEditor, trayItems: trayEditor })[name] ?? null;
    }

    Component {
        id: wallpaperGrid

        WallpaperGrid {}
    }

    Component {
        id: barLayout

        BarLayoutEditor {}
    }

    Component {
        id: dashboardLayout

        DashboardLayoutEditor {}
    }

    Component {
        id: trayEditor

        TrayEditor {}
    }

    Component {
        id: pinEditor

        PinEditor {}
    }

    readonly property string desktopPath:
        (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/applications/konshell-settings.desktop"
    readonly property string desktopEntry: [
        "[Desktop Entry]",
        "Type=Application",
        "Name=Настройки KonShell",
        "Name[en]=KonShell Settings",
        "Comment=Оформление, обои, панель, уведомления, блокировка",
        `Exec=qs -p ${Quickshell.shellDir} ipc call settings launch`,
        "Icon=preferences-desktop-appearance",
        "Terminal=false",
        "Categories=Settings;DesktopSettings;",
        "Keywords=konshell;настройки;оформление;обои;тема;панель;бар;виджеты;уведомления;блокировка;док;часы;календарь;заметки;",
        "StartupNotify=false",
        ""
    ].join("\n")

    IpcHandler {
        target: "settings"

        // section — id раздела из реестра; пусто — последний открытый раздел.
        function open(section: string): void {
            Ui.openSettings(section);
        }
        // Без аргументов — для пункта лаунчера: Quickshell, разбирая Exec, выбрасывает
        // пустой аргумент "", и open() получил бы на один аргумент меньше.
        // Не show: «qs ipc call <цель> show» печатает описание цели вместо вызова.
        function launch(): void {
            Ui.openSettings("");
        }
        function toggle(): void {
            Ui.settingsOpen = !Ui.settingsOpen;
        }
        function close(): void {
            Ui.settingsOpen = false;
        }
    }

    // Повторное открытие: окно могло остаться на другом рабочем столе — фокусируем его.
    Connections {
        target: Ui

        function onSettingsRaiseRequested() {
            const w = Niri.windows.find(w => w.app_id === "org.quickshell" && w.title === "Настройки KonShell");
            if (w)
                Niri.focusWindow(w.id);
        }
    }

    // Пункт в лаунчере и других меню приложений; переписывается, только если изменился.
    FileView {
        id: desktopFile

        path: root.desktopPath
        printErrors: false
        blockLoading: true
        atomicWrites: true

        Component.onCompleted: {
            if (text() !== root.desktopEntry)
                setText(root.desktopEntry);
        }
    }

    LazyLoader {
        active: Ui.settingsOpen

        FloatingWindow {
            id: window

            property string query: ""

            // Группы для показа: раздел целиком или найденное по всем разделам.
            readonly property var groups: {
                const list = query.trim() !== ""
                    ? Schema.options.filter(o => Schema.matches(o, query) && root.shown(o))
                    : Schema.options.filter(o => o.section === Ui.settingsSection);
                const out = [];
                for (const option of list) {
                    const key = option.section + "/" + option.group;
                    let group = out.find(g => g.key === key);
                    if (!group) {
                        group = { key: key, section: option.section, name: option.group, options: [] };
                        out.push(group);
                    }
                    group.options.push(option);
                }
                return out;
            }

            title: "Настройки KonShell"
            implicitWidth: 960
            implicitHeight: 700
            minimumSize: Qt.size(720, 460)
            color: Theme.color.background

            onVisibleChanged: {
                if (!visible)
                    Ui.settingsOpen = false;
            }

            // Esc: сначала очищает поиск, потом закрывает окно.
            Item {
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: {
                    if (window.query !== "")
                        search.text = "";
                    else
                        Ui.settingsOpen = false;
                }

                Rectangle {
                    id: sidebar

                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 230
                    color: Theme.color.surface

                    Column {
                        anchors.fill: parent
                        anchors.margins: Theme.spacing.md
                        spacing: Theme.spacing.xxs

                        StyledText {
                            leftPadding: Theme.spacing.md
                            bottomPadding: Theme.spacing.sm
                            topPadding: Theme.spacing.xs
                            text: "Настройки"
                            font.pixelSize: Theme.font.title
                            font.weight: Theme.font.medium
                        }

                        // Поиск по всем параметрам всех разделов.
                        Rectangle {
                            width: parent.width
                            height: 34
                            radius: Theme.radius.control
                            color: Theme.color.background
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
                                onTextChanged: window.query = text

                                StyledText {
                                    anchors.fill: parent
                                    text: "Поиск настроек"
                                    color: Theme.color.textMuted
                                    visible: search.text === ""
                                }
                            }
                        }

                        Item {
                            width: 1
                            height: Theme.spacing.xs
                        }

                        // Разделы по категориям; длинный список прокручивается.
                        Flickable {
                            id: nav

                            width: parent.width
                            height: sidebar.height - y - Theme.spacing.md * 2
                            contentWidth: width
                            contentHeight: navColumn.implicitHeight
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            Column {
                                id: navColumn

                                width: nav.width

                                Repeater {
                                    model: Schema.categories

                                    Column {
                                        id: category

                                        required property var modelData
                                        required property int index

                                        width: navColumn.width
                                        spacing: Theme.spacing.xxs

                                        SectionLabel {
                                            leftPadding: Theme.spacing.md
                                            topPadding: category.index > 0 ? Theme.spacing.lg : Theme.spacing.xs
                                            bottomPadding: Theme.spacing.xs
                                            text: category.modelData.name
                                        }

                                        Repeater {
                                            model: root.sections.filter(s => s.category === category.modelData.id)

                                            NavRow {
                                                required property var modelData

                                                width: category.width
                                                icon: modelData.icon
                                                title: modelData.name
                                                selected: window.query === "" && Ui.settingsSection === modelData.id
                                                onClicked: {
                                                    search.text = "";
                                                    Ui.settingsSection = modelData.id;
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Шапка раздела не прокручивается: название и «Закрыть» всегда на месте.
                Item {
                    id: header

                    anchors.left: sidebar.right
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 84

                    readonly property var section: root.sections.find(s => s.id === Ui.settingsSection) ?? null

                    // Название раздела и строка о том, что в нём.
                    Column {
                        x: content.x
                        width: content.width - Theme.spacing.xl
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacing.xxs

                        StyledText {
                            width: parent.width
                            text: window.query !== "" ? "Результаты поиска" : header.section?.name ?? ""
                            font.pixelSize: Theme.font.display
                            font.weight: Theme.font.medium
                            elide: Text.ElideRight
                        }

                        StyledText {
                            width: parent.width
                            text: window.query !== "" ? `По запросу «${window.query}»` : header.section?.desc ?? ""
                            color: Theme.color.textMuted
                            elide: Text.ElideRight
                            visible: text !== ""
                        }
                    }

                    // Заголовка окна нет (декорации Qt отключены), поэтому закрыть — здесь, или Esc.
                    IconButton {
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacing.md
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "window-close-symbolic"
                        Accessible.name: "Закрыть настройки"
                        onClicked: Ui.settingsOpen = false
                    }
                }

                Flickable {
                    id: page

                    anchors.left: sidebar.right
                    anchors.right: parent.right
                    anchors.top: header.bottom
                    anchors.bottom: parent.bottom
                    contentWidth: width
                    contentHeight: content.implicitHeight + Theme.spacing.xl
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: content

                        // Ширина строки ограничена: длинные строки на широком окне читаются хуже.
                        width: Math.min(page.width - Theme.spacing.xl * 2, 680)
                        x: Math.max(Theme.spacing.xl, (page.width - width) / 2)
                        spacing: Theme.spacing.xl
                        bottomPadding: Theme.spacing.lg

                        StyledText {
                            width: parent.width
                            text: `Ничего не нашлось по запросу «${window.query}»`
                            color: Theme.color.textMuted
                            visible: window.query !== "" && window.groups.length === 0
                        }

                        Repeater {
                            model: window.groups

                            Column {
                                id: groupColumn

                                required property var modelData
                                required property int index

                                // В поиске перед первой группой раздела — его название.
                                readonly property bool firstOfSection: index === 0
                                    || window.groups[index - 1].section !== modelData.section

                                width: content.width
                                spacing: Theme.spacing.sm
                                // Группа, все параметры которой скрыты условием when, не показывается.
                                visible: modelData.options.some(o => root.shown(o))

                                StyledText {
                                    text: root.sections.find(s => s.id === groupColumn.modelData.section)?.name ?? ""
                                    font.pixelSize: Theme.font.title
                                    font.weight: Theme.font.medium
                                    visible: window.query !== "" && groupColumn.firstOfSection
                                }

                                // Группа — заголовок и карточка с параметрами, между ними — линии.
                                StyledText {
                                    leftPadding: Theme.spacing.xxs
                                    text: groupColumn.modelData.name
                                    font.weight: Theme.font.medium
                                }

                                Rectangle {
                                    width: parent.width
                                    implicitHeight: groupOptions.implicitHeight + Theme.spacing.md * 2
                                    radius: Theme.radius.panel
                                    color: Theme.color.surface
                                    border.width: Theme.borders ? 1 : 0
                                    border.color: Theme.color.border

                                    Column {
                                        id: groupOptions

                                        x: Theme.spacing.lg
                                        y: Theme.spacing.md
                                        width: parent.width - Theme.spacing.lg * 2

                                        Repeater {
                                            model: groupColumn.modelData.options

                                            Column {
                                                id: optionItem

                                                required property var modelData
                                                required property int index

                                                // Линия — над каждым видимым параметром, кроме первого видимого.
                                                readonly property bool firstShown: !groupColumn.modelData.options
                                                    .slice(0, index).some(o => root.shown(o))

                                                width: groupOptions.width
                                                visible: root.shown(modelData)
                                                topPadding: firstShown ? 0 : Theme.spacing.md
                                                bottomPadding: Theme.spacing.xxs
                                                spacing: Theme.spacing.md

                                                Rectangle {
                                                    width: parent.width
                                                    height: 1
                                                    color: Theme.color.border
                                                    visible: !optionItem.firstShown
                                                }

                                                SettingControl {
                                                    option: optionItem.modelData
                                                    host: root
                                                    width: optionItem.width
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Смена раздела или запроса — к началу страницы.
            Connections {
                target: Ui

                function onSettingsSectionChanged() {
                    Qt.callLater(() => page.contentY = 0);
                }
            }
            onQueryChanged: Qt.callLater(() => page.contentY = 0)
        }
    }
}
