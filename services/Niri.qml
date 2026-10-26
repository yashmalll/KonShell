pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Состояние niri из потока событий IPC и отправка действий.
// После переподключения niri заново присылает полное состояние,
// поэтому отдельная синхронизация не нужна.
Singleton {
    id: root

    readonly property string socketPath: Quickshell.env("NIRI_SOCKET") ?? ""
    readonly property bool available: socketPath !== ""
    readonly property bool connected: eventSocket.connected

    // Рабочие столы отсортированы по монитору и индексу.
    property var workspaces: []
    property var windows: []
    property var keyboardLayouts: []
    property int currentLayoutIndex: 0
    property bool overviewOpen: false

    // Запросы, отправленные до подключения сокета.
    property var pending: []

    readonly property var focusedWorkspace: workspaces.find(ws => ws.is_focused) ?? null
    readonly property var focusedWindow: windows.find(w => w.is_focused) ?? null
    readonly property string currentLayout: keyboardLayouts[currentLayoutIndex] ?? ""

    // Короткая подпись текущей раскладки: shell.layoutLabels («English (US)=EN; Russian=RU»)
    // или две первые буквы названия.
    readonly property var layoutLabels: {
        const map = {};
        for (const pair of Settings.shell.layoutLabels.split(";")) {
            const [name, label] = pair.split("=").map(part => part.trim());
            if (name && label)
                map[name] = label;
        }
        return map;
    }
    readonly property string currentLayoutLabel: layoutLabels[currentLayout] ?? currentLayout.slice(0, 2).toUpperCase()

    function workspacesOn(output) {
        return workspaces.filter(ws => ws.output === output);
    }

    function windowsOn(workspaceId) {
        return windows.filter(w => w.workspace_id === workspaceId);
    }

    // Колонки рабочего стола слева направо для мини-карты в панели:
    // [{ index, width, focused, urgent }]. Ширина — максимальная ширина плитки
    // в колонке, в логических пикселях. Плавающие окна в ленту не входят.
    function columnsOn(workspaceId) {
        const columns = {};
        for (const w of windows) {
            const pos = w.layout?.pos_in_scrolling_layout;
            if (w.workspace_id !== workspaceId || !pos)
                continue;
            const c = columns[pos[0]] ?? (columns[pos[0]] = { index: pos[0], width: 0, focused: false, urgent: false });
            c.width = Math.max(c.width, w.layout.tile_size?.[0] ?? 0);
            c.focused = c.focused || w.is_focused;
            c.urgent = c.urgent || w.is_urgent;
        }
        return Object.values(columns).sort((a, b) => a.index - b.index);
    }

    function focusWorkspaceRelative(down) {
        action(down ? { FocusWorkspaceDown: {} } : { FocusWorkspaceUp: {} });
    }

    function focusWorkspace(id) {
        action({ FocusWorkspace: { reference: { Id: id } } });
    }

    function focusWindow(id) {
        action({ FocusWindow: { id: id } });
    }

    function closeWindow(id) {
        action({ CloseWindow: { id: id } });
    }

    // Время последнего фокуса окна в секундах (для сравнения), 0 — не было.
    function focusTime(window) {
        const t = window.focus_timestamp;
        return t ? t.secs + t.nanos / 1e9 : 0;
    }

    function switchLayout(next = true) {
        action({ SwitchLayout: { layout: next ? "Next" : "Prev" } });
    }

    function action(body) {
        send({ Action: body });
    }

    function send(request) {
        const line = JSON.stringify(request) + "\n";
        if (requestSocket.connected) {
            requestSocket.write(line);
            requestSocket.flush();
        } else {
            pending = pending.concat([line]);
            requestSocket.connected = true;
        }
    }

    function sortWorkspaces(list) {
        return list.slice().sort((a, b) => a.output.localeCompare(b.output) || a.idx - b.idx);
    }

    function updateWorkspaces(fn) {
        workspaces = workspaces.map(ws => fn(Object.assign({}, ws)));
    }

    function updateWindows(fn) {
        windows = windows.map(w => fn(Object.assign({}, w)));
    }

    function handleEvent(line) {
        let msg;
        try {
            msg = JSON.parse(line);
        } catch (e) {
            console.warn("niri: не удалось разобрать событие:", line);
            return;
        }

        if ("Ok" in msg)
            return;
        if ("Err" in msg) {
            console.warn("niri: ошибка потока событий:", msg.Err);
            return;
        }

        const [type, ev] = Object.entries(msg)[0];
        switch (type) {
        case "WorkspacesChanged":
            workspaces = sortWorkspaces(ev.workspaces);
            break;
        case "WorkspaceActivated": {
            const output = workspaces.find(ws => ws.id === ev.id)?.output;
            updateWorkspaces(ws => {
                if (ws.output === output)
                    ws.is_active = ws.id === ev.id;
                if (ev.focused)
                    ws.is_focused = ws.id === ev.id;
                return ws;
            });
            break;
        }
        case "WorkspaceActiveWindowChanged":
            updateWorkspaces(ws => {
                if (ws.id === ev.workspace_id)
                    ws.active_window_id = ev.active_window_id;
                return ws;
            });
            break;
        case "WorkspaceUrgencyChanged":
            updateWorkspaces(ws => {
                if (ws.id === ev.id)
                    ws.is_urgent = ev.urgent;
                return ws;
            });
            break;
        case "WindowsChanged":
            windows = ev.windows;
            break;
        case "WindowOpenedOrChanged": {
            const win = ev.window;
            const rest = windows.filter(w => w.id !== win.id);
            if (win.is_focused)
                rest.forEach((w, i) => {
                    if (w.is_focused)
                        rest[i] = Object.assign({}, w, { is_focused: false });
                });
            windows = rest.concat([win]);
            break;
        }
        case "WindowLayoutsChanged": {
            const changed = {};
            for (const [id, layout] of ev.changes)
                changed[id] = layout;
            updateWindows(w => {
                if (w.id in changed)
                    w.layout = changed[w.id];
                return w;
            });
            break;
        }
        case "WindowClosed":
            windows = windows.filter(w => w.id !== ev.id);
            break;
        case "WindowFocusChanged":
            updateWindows(w => {
                w.is_focused = w.id === ev.id;
                return w;
            });
            break;
        case "WindowFocusTimestampChanged":
            updateWindows(w => {
                if (w.id === ev.id)
                    w.focus_timestamp = ev.focus_timestamp;
                return w;
            });
            break;
        case "WindowUrgencyChanged":
            updateWindows(w => {
                if (w.id === ev.id)
                    w.is_urgent = ev.urgent;
                return w;
            });
            break;
        case "KeyboardLayoutsChanged":
            keyboardLayouts = ev.keyboard_layouts.names;
            currentLayoutIndex = ev.keyboard_layouts.current_idx;
            break;
        case "KeyboardLayoutSwitched":
            currentLayoutIndex = ev.idx;
            break;
        case "OverviewOpenedOrClosed":
            overviewOpen = ev.is_open;
            break;
        }
    }

    Socket {
        id: eventSocket

        path: root.socketPath
        connected: root.available

        onConnectedChanged: {
            if (connected) {
                write('"EventStream"\n');
                flush();
            } else {
                reconnectTimer.start();
            }
        }
        onError: reconnectTimer.start()

        parser: SplitParser {
            onRead: line => root.handleEvent(line)
        }
    }

    Socket {
        id: requestSocket

        path: root.socketPath
        connected: root.available

        onConnectedChanged: {
            if (!connected)
                return;
            for (const line of root.pending)
                write(line);
            root.pending = [];
            flush();
        }

        parser: SplitParser {
            onRead: line => {
                if (line.includes('"Err"'))
                    console.warn("niri: ошибка запроса:", line);
            }
        }
    }

    Timer {
        id: reconnectTimer

        interval: 1000
        onTriggered: {
            if (!root.available)
                return;
            if (!eventSocket.connected)
                eventSocket.connected = true;
            if (!requestSocket.connected)
                requestSocket.connected = true;
        }
    }
}
