pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs.config

// Батарея ноутбука и профили питания через UPower и power-profiles-daemon.
Singleton {
    id: root

    readonly property UPowerDevice device: UPower.displayDevice
    readonly property bool available: device?.isLaptopBattery ?? false

    // UPower отдаёт 0..1.
    readonly property real percent: device?.percentage ?? 0
    readonly property bool charging: device?.state === UPowerDeviceState.Charging
        || device?.state === UPowerDeviceState.PendingCharge
    readonly property bool full: device?.state === UPowerDeviceState.FullyCharged
    readonly property bool pluggedIn: !UPower.onBattery

    // Секунды; 0, если UPower не знает.
    readonly property real timeLeft: charging ? (device?.timeToFull ?? 0) : (device?.timeToEmpty ?? 0)

    // Имена из UPower устарели для Adwaita, поэтому собираем свои:
    // battery-level-<0..100 с шагом 10>[-charging|-plugged-in|-charged]-symbolic.
    // У уровня 100 нет варианта -charging, вместо него -plugged-in.
    readonly property string icon: {
        if (!available)
            return "battery-missing-symbolic";
        const level = Math.round(percent * 10) * 10;
        let suffix = full ? "-charged" : charging ? "-charging" : pluggedIn ? "-plugged-in" : "";
        if (level === 100 && suffix === "-charging")
            suffix = "-plugged-in";
        else if (level < 100 && suffix === "-charged")
            suffix = "-plugged-in";
        return `battery-level-${level}${suffix}-symbolic`;
    }

    readonly property int profile: PowerProfiles.profile
    readonly property bool hasPerformance: PowerProfiles.hasPerformanceProfile

    readonly property var profiles: hasPerformance
        ? [PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance]
        : [PowerProfile.PowerSaver, PowerProfile.Balanced]

    function setProfile(value) {
        PowerProfiles.profile = value;
    }

    function cycleProfile() {
        const i = profiles.indexOf(profile);
        setProfile(profiles[(i + 1) % profiles.length]);
    }

    function profileName(value) {
        switch (value) {
        case PowerProfile.PowerSaver:
            return "Энергосбережение";
        case PowerProfile.Performance:
            return "Производительность";
        default:
            return "Баланс";
        }
    }

    function profileIcon(value) {
        switch (value) {
        case PowerProfile.PowerSaver:
            return "power-profile-power-saver-symbolic";
        case PowerProfile.Performance:
            return "power-profile-performance-symbolic";
        default:
            return "power-profile-balanced-symbolic";
        }
    }

    // «1 ч 25 мин»; пустая строка, если время неизвестно.
    function formatTime(seconds) {
        if (seconds <= 0)
            return "";
        const h = Math.floor(seconds / 3600);
        const m = Math.round((seconds % 3600) / 60);
        return h > 0 ? `${h} ч ${m} мин` : `${m} мин`;
    }

    // Предупреждения о низком заряде (system.batteryWarning / batteryCritical, %):
    // по одному за разряд; подключение зарядки сбрасывает их.
    property bool warned: false
    property bool criticalWarned: false
    readonly property int percentInt: Math.round(percent * 100)

    function checkLevel() {
        if (!available)
            return;
        if (charging || pluggedIn) {
            warned = false;
            criticalWarned = false;
            return;
        }
        const critical = Settings.system.batteryCritical;
        const warning = Settings.system.batteryWarning;
        if (critical > 0 && percentInt <= critical && !criticalWarned) {
            criticalWarned = true;
            warned = true;
            Quickshell.execDetached(["notify-send", "-a", "KonShell", "-u", "critical", "-i", "battery-level-0-symbolic",
                `Батарея почти разряжена: ${percentInt}%`, "Подключите зарядку, иначе ноутбук скоро выключится."]);
        } else if (warning > 0 && percentInt <= warning && !warned) {
            warned = true;
            Quickshell.execDetached(["notify-send", "-a", "KonShell", "-i", "battery-level-10-symbolic",
                `Низкий заряд: ${percentInt}%`, "Пора подключить зарядку."]);
        }
    }

    onPercentIntChanged: checkLevel()
    onChargingChanged: checkLevel()
    onPluggedInChanged: checkLevel()
}
