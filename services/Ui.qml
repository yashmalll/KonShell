pragma Singleton

import QtQuick
import Quickshell

// Общее состояние интерфейса: какие панели открыты.
Singleton {
    id: root

    signal islandDismissRequested
    signal searchRequested

    property bool controlCenterOpen: false
    property bool timerOpen: false
    function openTimer() { timerOpen = true; }
    onTimerOpenChanged: {
        if (timerOpen) {
            privacyOpen = false;
            dashboardOpen = false;
            controlCenterOpen = false;
            Notifications.centerOpen = false;
            sidebarOpen = false;
        }
    }
    property bool privacyOpen: false
    function openPrivacy() { privacyOpen = true; }
    onPrivacyOpenChanged: {
        if (privacyOpen) {
            timerOpen = false;
            dashboardOpen = false;
            controlCenterOpen = false;
            Notifications.centerOpen = false;
            sidebarOpen = false;
        }
    }
    function closeIslandPanels() {
        timerOpen = false;
        privacyOpen = false;
        dashboardOpen = false;
        controlCenterOpen = false;
        Notifications.centerOpen = false;
        islandPinned = false;
    }
    // Индикаторы используют общий островок на активном мониторе.
    property bool islandOsdShown: false
    property string islandOsdKind: "volume"
    property string islandOrigin: "center"
    function openIslandAt(origin) {
        if (!["left", "right", "center"].includes(origin)) return false;
        islandOrigin = origin;
        if (origin === "left") openDashboard(false);
        else if (origin === "right") { controlCenterPage = "main"; controlCenterOpen = true; }
        else islandPinned = true;
        return true;
    }
    property bool islandPinned: false

    // История буфера обмена (modules/clipboard).
    property bool clipboardOpen: false

    // Меню сеанса (modules/session): поверх всего, закрывает остальные панели.
    property bool sessionOpen: false

    onSessionOpenChanged: {
        if (sessionOpen) {
            timerOpen = false;
            islandPinned = false;
            privacyOpen = false;
            controlCenterOpen = false;
            dashboardOpen = false;
            sidebarOpen = false;
            Notifications.centerOpen = false;
        }
    }

    // Панель под часами: календарь, плеер, заметки. noteRequested — открыть
    // сразу с курсором в поле новой заметки (IPC dashboard note).
    property bool dashboardOpen: false
    property bool noteRequested: false

    function openDashboard(withNote) {
        // Сброс, чтобы повторная просьба о заметке снова вызвала сигнал изменения.
        noteRequested = false;
        noteRequested = withNote === true;
        dashboardOpen = true;
    }

    // Одновременно открыта одна панель с клавиатурным фокусом.
    onDashboardOpenChanged: {
        if (dashboardOpen) {
            timerOpen = false;
            privacyOpen = false;
            controlCenterOpen = false;
            sidebarOpen = false;
            Notifications.centerOpen = false;
        } else {
            noteRequested = false;
        }
    }

    // Боковая панель (modules/sidebar): заметки, скриншот, запись экрана.
    // Открывается у края экрана sidebarEdge ("left" | "right") на мониторе sidebarScreen.
    property bool sidebarOpen: false
    property string sidebarEdge: "right"
    property string sidebarScreen: ""

    function openSidebar(screenName, edge) {
        sidebarScreen = screenName || "";
        sidebarEdge = edge || sidebarEdge;
        sidebarOpen = true;
    }

    // Окно заметки поверх всего (modules/sidebar/NoteWindow.qml): notePath — открытая
    // заметка; пусто — новая.
    property bool noteOpen: false
    property string notePath: ""

    function openNote(path) {
        closeIslandPanels();
        notePath = path || "";
        noteOpen = true;
        sidebarOpen = false;
        dashboardOpen = false;
    }

    // main | wifi | bluetooth | audio; при закрытии сбрасывается на main.
    property string controlCenterPage: "main"

    // Окно «Настройки KonShell» и открытый в нём раздел — id из config/settings-schema.js.
    property bool settingsOpen: false
    property string settingsSection: "appearance"
    property string settingsQuery: ""
    signal settingsSearchRequested(string query)
    onSettingsOpenChanged: if (!settingsOpen) settingsQuery = ""

    // Окно уже открыто (возможно, на другом рабочем столе) — окно настроек
    // по этому сигналу переводит на себя фокус.
    signal settingsRaiseRequested

    function openSettings(section, query) {
        closeIslandPanels();
        settingsSection = section || settingsSection;
        settingsQuery = query || "";
        settingsSearchRequested(settingsQuery);
        controlCenterOpen = false;
        if (settingsOpen)
            settingsRaiseRequested();
        else
            settingsOpen = true;
    }

    // Обзор niri: панели с клавиатурным фокусом мешали бы управлять им — закрываем.
    // Лаунчер закрывается сам по этому же сигналу (modules/launcher/Launcher.qml).
    Connections {
        target: Niri

        function onOverviewOpenChanged() {
            if (!Niri.overviewOpen)
                return;
            root.timerOpen = false;
            root.privacyOpen = false;
            root.controlCenterOpen = false;
            root.dashboardOpen = false;
            root.sidebarOpen = false;
            root.islandPinned = false;
            Notifications.centerOpen = false;
        }
    }

    Connections {
        target: Notifications

        function onCenterOpenChanged() {
            if (Notifications.centerOpen) {
                root.timerOpen = false;
                root.privacyOpen = false;
                root.dashboardOpen = false;
                root.controlCenterOpen = false;
                root.sidebarOpen = false;
            }
        }
    }

    onSidebarOpenChanged: {
        if (sidebarOpen) {
            timerOpen = false;
            privacyOpen = false;
            controlCenterOpen = false;
            dashboardOpen = false;
        }
    }

    onControlCenterOpenChanged: {
        if (controlCenterOpen) {
            timerOpen = false;
            privacyOpen = false;
            Notifications.centerOpen = false;
            dashboardOpen = false;
            sidebarOpen = false;
        } else {
            controlCenterPage = "main";
        }
    }
}
