import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.config

// Один обработчик на оболочку: состояние общее для всех мониторов.
Scope {
    IpcHandler {
        target: "connectivity"
        function status(): string {
            return JSON.stringify({bluetooth: {available: BluetoothState.available, enabled: BluetoothState.enabled, agentReady: BluetoothState.agentReady, error: BluetoothState.agentError, prompt: BluetoothState.prompt?.kind || "", devices: BluetoothState.devices.length}, wifi: {available: NetworkState.wifiDevice !== null, enabled: NetworkState.wifiEnabled, networks: NetworkState.wifiNetworks.length, detailError: NetworkState.details.error || ""}, jobs: {available: Jobs.available, count: Jobs.jobs.length}});
        }
    }
    IpcHandler {
        target: "timer"
        function open(): void { Ui.openTimer(); }
        function start(seconds: int): bool { return Countdown.start(seconds); }
        function pomodoro(): bool { return Countdown.startPomodoro(); }
        function pause(): void { Countdown.pause(); }
        function resume(): void { Countdown.resume(); }
        function stop(): void { Countdown.stop(); }
        function status(): string {
            return JSON.stringify({ phase: Countdown.state.phase, mode: Countdown.state.mode,
                running: Countdown.running, remaining: Math.ceil(Countdown.remaining / 1000),
                completed: Countdown.state.completed, activity: IslandActivity.kind,
                alerts: Notifications.history.filter(item => item.appName === "KonShell Timer").length });
        }
    }
    IpcHandler {
        target: "profile"
        function apply(id: string): bool { return Profiles.select(id); }
        function status(): string { return JSON.stringify({ current: Profiles.current, dnd: Notifications.dnd }); }
    }
    IpcHandler {
        target: "search"
        function query(text: string): string {
            return JSON.stringify(GlobalSearch.search(text, "all").slice(0, 20).map(result => ({
                name: result.name, kind: result.kind, description: result.description
            })));
        }
    }
    IpcHandler {
        target: "focus"
        function toggle(): void { FocusMode.toggle(); }
        function start(minutes: int): bool { return FocusMode.start(minutes); }
        function stop(): void { FocusMode.stop(); }
        function status(): string { return JSON.stringify({ active: FocusMode.active, minutesLeft: FocusMode.minutesLeft, dnd: Notifications.dnd, baseDnd: Settings.notifications.dnd }); }
    }
    IpcHandler {
        target: "privacy"
        function open(): void { Ui.openPrivacy(); }
        function status(): string { return JSON.stringify({ available: Privacy.available, microphone: Privacy.microphoneApps, camera: Privacy.cameraApps, screen: Privacy.sharedApps, recording: ScreenRecorder.recording }); }
    }
    IpcHandler {
        target: "island"
        function openAt(origin: string): bool { return Ui.openIslandAt(origin); }
        function open(): void { Ui.islandPinned = true; }
        function close(): void { Ui.closeIslandPanels(); }
        function toggle(): void { Ui.islandPinned = !Ui.islandPinned; }
        function status(): string {
            return JSON.stringify({
                pinned: Ui.islandPinned,
                origin: Ui.islandOrigin,
                dashboard: Ui.dashboardOpen,
                history: Notifications.centerOpen,
                control: Ui.controlCenterOpen,
                privacy: Ui.privacyOpen,
                focus: FocusMode.active,
                timer: Countdown.state.phase,
                profile: Profiles.current,
                historyCount: Notifications.count,
                osd: Ui.islandOsdShown,
                pendingNotifications: Notifications.popups.length,
                activeOutput: Niri.focusedWorkspace?.output ?? ""
            });
        }
    }
}
