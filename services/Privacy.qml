pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root
    readonly property bool enabled: Settings.system.privacyIndicator
    property var microphoneApps: []
    property var cameraApps: []
    property var sharedApps: []
    property bool available: false
    readonly property bool microphone: microphoneApps.length > 0
    readonly property bool camera: cameraApps.length > 0
    readonly property bool sharing: sharedApps.length > 0 || ScreenRecorder.recording
    readonly property bool active: Settings.system.privacyIndicator && (microphone || camera || sharing)
    readonly property string summary: [
        microphone ? "Микрофон: " + microphoneApps.join(", ") : "",
        camera ? "Камера: " + cameraApps.join(", ") : "",
        sharing ? "Экран: " + (sharedApps.concat(ScreenRecorder.recording ? ["KonShell"] : [])).join(", ") : ""
    ].filter(Boolean).join(" · ")
    Component.onCompleted: monitor.running = enabled
    onEnabledChanged: Qt.callLater(() => {
        monitor.running = root.enabled;
        if (!root.enabled) retry.stop();
    })

    Process {
        id: monitor
        command: ["setpriv", "--pdeathsig", "KILL", "python3", "-u", Quickshell.shellDir + "/scripts/privacy-monitor.py"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const data = JSON.parse(line);
                    root.microphoneApps = data.microphone ?? [];
                    root.cameraApps = data.camera ?? [];
                    root.sharedApps = data.screen ?? [];
                    root.available = data.available === true;
                } catch (error) { console.warn("privacy: invalid monitor response"); }
            }
        }
        onExited: {
            root.microphoneApps = [];
            root.cameraApps = [];
            root.sharedApps = [];
            root.available = false;
            if (Settings.system.privacyIndicator)
                retry.restart();
        }
    }
    Timer {
        id: retry
        interval: 5000
        onTriggered: if (Settings.system.privacyIndicator) monitor.running = true
    }
}
