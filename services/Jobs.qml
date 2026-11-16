pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property var jobs: []
    property bool available: false
    Process {
        id: monitor
        running: true
        stdinEnabled: true
        command: ["setpriv", "--pdeathsig", "KILL", "python3", "-u", Quickshell.shellDir + "/scripts/job-monitor.py"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const data = JSON.parse(line);
                    root.jobs = data.jobs || [];
                    root.available = true;
                } catch (e) {
                    console.warn("Jobs: invalid progress response");
                }
            }
        }
        onExited: {
            root.available = false;
            root.jobs = [];
            retry.restart();
        }
    }
    Timer {
        id: retry
        interval: 10000
        onTriggered: monitor.running = true
    }
}
