pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Погода с Open-Meteo (бесплатно, без ключа): текущая и на 5 дней для города
// из настроек (weather.city). Город переводится в координаты их же геокодером.
// Обновление — раз в weather.refreshMinutes; последний ответ хранится в
// ~/.cache/konshell/weather.json, поэтому после запуска погода видна сразу.
Singleton {
    id: root

    readonly property bool enabled: Settings.weather.enabled
    readonly property string city: Settings.weather.city.trim()
    readonly property bool fahrenheit: Settings.weather.units === "fahrenheit"

    // idle — город не указан; loading | ok | error.
    property string loadState: "idle"
    property string error: ""

    // Найденное место.
    property string place: ""
    property real latitude: 0
    property real longitude: 0
    property string placeFor: ""

    // Сейчас.
    property real temperature: 0
    property real feelsLike: 0
    property int code: -1
    property bool isDay: true
    property real wind: 0
    property int humidity: 0
    property date sunrise
    property date sunset
    // По дням: [{ date, code, max, min, precipitation }].
    property var days: []
    property real fetchedAt: 0

    readonly property bool available: code >= 0
    readonly property string description: describe(code)
    readonly property string icon: iconFor(code, isDay)
    readonly property string unit: fahrenheit ? "°F" : "°C"

    // «7°», «−3°».
    function degrees(value) {
        return `${Math.round(value)}°`.replace("-", "−");
    }

    function describe(c) {
        if (c === 0) return "Ясно";
        if (c === 1) return "Почти ясно";
        if (c === 2) return "Переменная облачность";
        if (c === 3) return "Пасмурно";
        if (c === 45 || c === 48) return "Туман";
        if (c >= 51 && c <= 55) return "Морось";
        if (c === 56 || c === 57) return "Ледяная морось";
        if (c === 61) return "Небольшой дождь";
        if (c === 63) return "Дождь";
        if (c === 65) return "Сильный дождь";
        if (c === 66 || c === 67) return "Ледяной дождь";
        if (c === 71) return "Небольшой снег";
        if (c === 73) return "Снег";
        if (c === 75) return "Сильный снег";
        if (c === 77) return "Снежная крупа";
        if (c >= 80 && c <= 82) return "Ливень";
        if (c === 85 || c === 86) return "Снегопад";
        if (c === 95) return "Гроза";
        if (c === 96 || c === 99) return "Гроза с градом";
        return "";
    }

    function iconFor(c, day) {
        if (c === 0) return day ? "weather-clear-symbolic" : "weather-clear-night-symbolic";
        if (c === 1 || c === 2) return day ? "weather-few-clouds-symbolic" : "weather-few-clouds-night-symbolic";
        if (c === 3) return "weather-overcast-symbolic";
        if (c === 45 || c === 48) return "weather-fog-symbolic";
        if (c >= 51 && c <= 57) return "weather-showers-scattered-symbolic";
        if ((c >= 61 && c <= 67) || (c >= 80 && c <= 82)) return "weather-showers-symbolic";
        if ((c >= 71 && c <= 77) || c === 85 || c === 86) return "weather-snow-symbolic";
        if (c >= 95) return "weather-storm-symbolic";
        return "weather-severe-alert-symbolic";
    }

    function refresh() {
        if (!enabled || city === "") {
            loadState = "idle";
            return;
        }
        if (geocoder.running || forecast.running)
            return;
        loadState = "loading";
        error = "";
        // Координаты ищутся заново, только если сменился город.
        if (placeFor !== city || (latitude === 0 && longitude === 0)) {
            geocoder.command = ["curl", "-fsS", "--max-time", "8",
                "https://geocoding-api.open-meteo.com/v1/search?count=1&language=ru&name=" + encodeURIComponent(city)];
            geocoder.running = true;
        } else {
            fetchForecast();
        }
    }

    function fetchForecast() {
        const params = [
            `latitude=${latitude}`, `longitude=${longitude}`, "timezone=auto", "forecast_days=5",
            "current=temperature_2m,apparent_temperature,weather_code,is_day,wind_speed_10m,relative_humidity_2m",
            "daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,sunrise,sunset",
            "wind_speed_unit=ms"
        ];
        if (fahrenheit)
            params.push("temperature_unit=fahrenheit");
        forecast.command = ["curl", "-fsS", "--max-time", "8", "https://api.open-meteo.com/v1/forecast?" + params.join("&")];
        forecast.running = true;
    }

    function apply(data) {
        const c = data.current;
        temperature = c.temperature_2m;
        feelsLike = c.apparent_temperature;
        code = c.weather_code;
        isDay = c.is_day === 1;
        wind = c.wind_speed_10m;
        humidity = c.relative_humidity_2m;
        const d = data.daily;
        days = d.time.map((t, i) => ({
            date: new Date(t + "T12:00:00"),
            code: d.weather_code[i],
            max: d.temperature_2m_max[i],
            min: d.temperature_2m_min[i],
            precipitation: d.precipitation_probability_max?.[i] ?? 0
        }));
        if (d.sunrise?.[0])
            sunrise = new Date(d.sunrise[0]);
        if (d.sunset?.[0])
            sunset = new Date(d.sunset[0]);
    }

    function fail(message) {
        loadState = "error";
        error = message;
        console.warn("weather:", message);
    }

    // Смена города — с паузой, пока его печатают в настройках.
    onCityChanged: cityDebounce.restart()
    onEnabledChanged: refresh()
    // Координаты те же — только новый прогноз в других единицах.
    onFahrenheitChanged: refresh()

    Timer {
        id: cityDebounce

        interval: 1500
        onTriggered: root.refresh()
    }

    Timer {
        interval: Math.max(10, Settings.weather.refreshMinutes) * 60000
        repeat: true
        running: root.enabled && root.city !== ""
        onTriggered: root.refresh()
    }

    Process {
        id: geocoder

        stdout: StdioCollector {
            id: geoOut
        }
        onExited: code => {
            try {
                if (code !== 0)
                    throw new Error("нет связи с Open-Meteo");
                const found = JSON.parse(geoOut.text).results?.[0];
                if (!found)
                    throw new Error(`город «${root.city}» не найден`);
                root.latitude = found.latitude;
                root.longitude = found.longitude;
                root.place = [found.name, found.country].filter(s => s).join(", ");
                root.placeFor = root.city;
                root.fetchForecast();
            } catch (e) {
                root.fail(e.message);
            }
        }
    }

    Process {
        id: forecast

        stdout: StdioCollector {
            id: forecastOut
        }
        onExited: code => {
            try {
                if (code !== 0)
                    throw new Error("нет связи с Open-Meteo");
                const data = JSON.parse(forecastOut.text);
                root.apply(data);
                root.fetchedAt = Date.now();
                root.loadState = "ok";
                cache.setText(JSON.stringify({
                    city: root.city, fahrenheit: root.fahrenheit, place: root.place,
                    latitude: root.latitude, longitude: root.longitude, fetchedAt: root.fetchedAt, data: data
                }));
            } catch (e) {
                root.fail(e.message);
            }
        }
    }

    // Кэш последнего ответа: показать сразу, а обновить, если устарел.
    FileView {
        id: cache

        path: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/konshell/weather.json"
        printErrors: false
        atomicWrites: true
        blockLoading: true

        onLoaded: {
            try {
                const saved = JSON.parse(text());
                if (saved.city === root.city && saved.fahrenheit === root.fahrenheit) {
                    root.place = saved.place;
                    root.latitude = saved.latitude;
                    root.longitude = saved.longitude;
                    root.placeFor = saved.city;
                    root.apply(saved.data);
                    root.fetchedAt = saved.fetchedAt;
                    root.loadState = "ok";
                }
            } catch (e) {
                // Повреждённый кэш — просто запросим заново.
            }
            const age = Date.now() - root.fetchedAt;
            if (root.loadState !== "ok" || age > Math.max(10, Settings.weather.refreshMinutes) * 60000)
                Qt.callLater(root.refresh);
        }
        onLoadFailed: Qt.callLater(root.refresh)
    }
}
