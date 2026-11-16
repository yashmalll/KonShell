pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth

Singleton {
    id: root
    property string selectedAdapter: ""
    readonly property var adapters: Bluetooth.adapters.values
    readonly property BluetoothAdapter adapter: adapters.find(a => a.adapterId === selectedAdapter) ?? Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool enabled: adapter?.enabled ?? false
    readonly property bool blocked: adapter?.state === BluetoothAdapterState.Blocked
    readonly property var devices: (adapter?.devices.values ?? []).slice().sort((a, b) => b.connected - a.connected || b.paired - a.paired || (a.name || a.address).localeCompare(b.name || b.address))
    readonly property var connectedDevices: devices.filter(d => d.connected)
    readonly property string icon: !available || !enabled ? "bluetooth-disabled-symbolic" : connectedDevices.length ? "bluetooth-active-symbolic" : "bluetooth-symbolic"
    readonly property string summary: !available ? "Нет адаптера" : blocked ? "Заблокирован" : !enabled ? "Выключен" : connectedDevices.length === 1 ? connectedDevices[0].name : connectedDevices.length ? `Устройств: ${connectedDevices.length}` : "Включён"
    property bool agentReady: false
    property string agentError: ""
    property var prompt: null
    property string inputError: ""
    property var operations: ({})
    readonly property bool interactionPending: prompt !== null
    function setEnabled(value) {
        if (adapter)
            adapter.enabled = value;
    }
    function stateFor(device) {
        return operations[device.dbusPath] ?? {
            stage: "",
            error: ""
        };
    }
    function busy(device) {
        return stateFor(device).stage !== "" || device.pairing || device.state === BluetoothDeviceState.Connecting || device.state === BluetoothDeviceState.Disconnecting;
    }
    function send(data) {
        if (agent.running)
            agent.write(JSON.stringify(data) + "\n");
    }
    function act(device, action) {
        send({
            device: device.dbusPath,
            action: action
        });
    }
    function respond(accept, value) {
        if (prompt)
            send({
                action: "respond",
                id: prompt.id,
                accept: accept,
                value: value || ""
            });
    }
    function cancelPrompt() {
        if (!prompt)
            return;
        send({
            action: "cancel",
            device: prompt.device
        });
        prompt = null;
    }
    function openPrompt(data) {
        const device = Bluetooth.devices.values.find(d => d.dbusPath === data.device);
        if (device?.adapter)
            selectedAdapter = device.adapter.adapterId;
        prompt = data;
        inputError = "";
        Ui.controlCenterPage = "bluetooth";
        Ui.controlCenterOpen = true;
    }
    property bool discoveryRequested: false
    readonly property bool shouldDiscover: discoveryRequested && enabled && !interactionPending && !Object.values(operations).some(o => o.stage !== "")
    property var discoveringAdapter: null
    function syncDiscovery() {
        if (discoveringAdapter && discoveringAdapter !== adapter)
            discoveringAdapter.discovering = false;
        discoveringAdapter = adapter;
        if (adapter)
            adapter.discovering = shouldDiscover;
    }
    onShouldDiscoverChanged: syncDiscovery()
    onAdapterChanged: syncDiscovery()
    Component.onCompleted: syncDiscovery()
    Process {
        id: agent
        running: true
        stdinEnabled: true
        command: ["setpriv", "--pdeathsig", "KILL", "python3", "-u", Quickshell.shellDir + "/scripts/bluetooth-agent.py"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const data = JSON.parse(line);
                    if (data.event === "ready") {
                        root.agentReady = data.ready;
                        root.agentError = data.error || "";
                    } else if (data.event === "prompt" || data.event === "display")
                        root.openPrompt(data);
                    else if (data.event === "promptClosed")
                        root.prompt = null;
                    else if (data.event === "inputError")
                        root.inputError = data.message;
                    else if (data.event === "operation")
                        root.operations = Object.assign({}, root.operations, {
                            [data.device]: {
                                stage: data.stage,
                                error: data.error
                            }
                        });
                    else if (data.event === "error")
                        root.agentError = data.error;
                } catch (e) {
                    console.warn("Bluetooth: invalid agent response");
                }
            }
        }
        onExited: {
            root.agentReady = false;
            root.prompt = null;
            root.operations = ({});
            root.agentError = "Bluetooth-агент недоступен. Повторная попытка через 5 секунд.";
            retry.restart();
        }
    }
    Timer {
        id: retry
        interval: 5000
        onTriggered: agent.running = true
    }
}
