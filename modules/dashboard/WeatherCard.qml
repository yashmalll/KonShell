import QtQuick
import qs.config
import qs.services
import qs.widgets

// Погода в панели под часами: сейчас и на 5 дней (services/Weather.qml).
// Пока город не указан — подсказка и кнопка в настройки.
Column {
    id: root

    spacing: Theme.spacing.md

    // Город не указан.
    Rectangle {
        width: parent.width
        height: 44
        radius: Theme.radius.control
        color: Theme.color.surface
        visible: Weather.loadState === "idle"

        Row {
            anchors.left: parent.left
            anchors.leftMargin: Theme.spacing.md
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacing.sm

            SymbolIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: "weather-few-clouds-symbolic"
                color: Theme.color.textMuted
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: "Погода: укажите город"
                color: Theme.color.textMuted
            }
        }

        TextButton {
            anchors.right: parent.right
            anchors.rightMargin: Theme.spacing.sm
            anchors.verticalCenter: parent.verticalCenter
            text: "Указать"
            onClicked: {
                Ui.dashboardOpen = false;
                Ui.openSettings("clock");
            }
        }
    }

    // Ошибка без сохранённых данных.
    StyledText {
        width: parent.width
        text: `Погода: ${Weather.error}`
        color: Theme.color.textMuted
        font.pixelSize: Theme.font.caption
        visible: Weather.loadState === "error" && !Weather.available
    }

    // Сейчас.
    Row {
        width: parent.width
        spacing: Theme.spacing.md
        visible: Weather.available && Weather.loadState !== "idle"

        SymbolIcon {
            anchors.verticalCenter: parent.verticalCenter
            implicitSize: 36
            name: Weather.icon
            color: Theme.color.primary
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: Weather.degrees(Weather.temperature)
            font.pixelSize: Math.round(Theme.font.display * 1.6)
            font.weight: Theme.font.medium
            font.features: { "tnum": 1 }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x
            spacing: 1

            StyledText {
                width: parent.width
                text: Weather.description
                font.weight: Theme.font.medium
            }

            StyledText {
                width: parent.width
                text: `ощущается ${Weather.degrees(Weather.feelsLike)} · ветер ${Math.round(Weather.wind)} м/с · ${Weather.humidity}%`
                color: Theme.color.textMuted
                font.pixelSize: Theme.font.caption
            }

            StyledText {
                width: parent.width
                text: Weather.loadState === "error" ? `${Weather.place} · не обновилось` : Weather.place
                color: Weather.loadState === "error" ? Theme.color.warning : Theme.color.textDisabled
                font.pixelSize: Theme.font.caption
            }
        }
    }

    // На 5 дней.
    Row {
        width: parent.width
        visible: Weather.available && Weather.days.length > 0 && Weather.loadState !== "idle"

        Repeater {
            model: Weather.days

            Column {
                required property var modelData
                required property int index

                width: root.width / Math.max(1, Weather.days.length)
                spacing: Theme.spacing.xxs

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: {
                        if (parent.index === 0)
                            return "Сегодня";
                        const name = Qt.locale().dayName(parent.modelData.date.getDay(), Locale.ShortFormat);
                        return name.charAt(0).toUpperCase() + name.slice(1);
                    }
                    color: parent.index === 0 ? Theme.color.text : Theme.color.textMuted
                    font.pixelSize: Theme.font.caption
                }

                SymbolIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    implicitSize: 20
                    name: Weather.iconFor(parent.modelData.code, true)
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Weather.degrees(parent.modelData.max)
                    font.pixelSize: Theme.font.caption
                    font.weight: Theme.font.medium
                    font.features: { "tnum": 1 }
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Weather.degrees(parent.modelData.min)
                    color: Theme.color.textMuted
                    font.pixelSize: Theme.font.caption
                    font.features: { "tnum": 1 }
                }

                // Вероятность осадков — только если заметная.
                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: `${parent.modelData.precipitation}%`
                    color: Theme.color.primary
                    font.pixelSize: Theme.font.caption - 1
                    opacity: parent.modelData.precipitation >= 30 ? 1 : 0
                }
            }
        }
    }
}
