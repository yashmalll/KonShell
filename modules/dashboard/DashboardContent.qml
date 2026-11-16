import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

// Карточки панели часов встроены в островок; колонки переносятся по ширине.
Item {
    id: root
    implicitHeight: grid.implicitHeight
    readonly property int columnCount: Math.max(1, Math.min(cardColumns.length, Math.floor((width + 16) / 316)))

    function focusNoteIfRequested() {
        if (Ui.noteRequested && noteItem)
            Qt.callLater(() => noteItem?.focusInput());
    }
    Component.onCompleted: {
        calendarItem?.goToday();
        Notes.checkDirectory();
        focusNoteIfRequested();
    }
    Connections {
        target: Ui
        function onNoteRequestedChanged() {
            root.focusNoteIfRequested();
        }
    }
    onNoteItemChanged: focusNoteIfRequested()
    property Item noteItem: null
    property Item calendarItem: null
    readonly property var cardComponents: ({
            clock: clockCard,
            weather: weatherCard,
            calendar: calendarCard,
            system: systemCard,
            media: mediaCard,
            notes: notesCard,
            network: networkCard
        })
    // До четырёх колонок слева направо — панель широкая, но невысокая. Карточка из нескольких
    // колонок — только в первой; колонка, в которой нечего показать (пустая
    // или только с выключенной погодой), не занимает места.
    readonly property var cardColumns: {
        const seen = new Set();
        return [
            {
                key: "left",
                width: 300
            },
            {
                key: "middle",
                width: 300
            },
            {
                key: "right",
                width: 340
            },
            {
                key: "extra",
                width: 320
            }
        ].map(c => ({
                    key: c.key,
                    width: c.width,
                    cards: Settings.dashboard[c.key].filter(id => {
                        if (cardComponents[id] === undefined || seen.has(id) || !Profiles.cardVisible(id)
                            || (id === "weather" && !Settings.weather.enabled)
                            || (id === "media" && Media.player === null))
                            return false;
                        seen.add(id);
                        return true;
                    })
                })).filter(c => c.cards.length > 0);
    }

    Component {
        id: clockCard

        Column {
            spacing: Theme.spacing.xxs

            StyledText {
                text: Qt.formatTime(clock.date, "HH:mm")
                font.pixelSize: Math.round(Theme.font.display * 2.2)
                font.weight: Theme.font.medium
                font.features: {
                    "tnum": 1
                }
            }

            StyledText {
                width: parent.width
                wrapMode: Text.Wrap
                text: {
                    const s = Qt.locale().toString(clock.date, "dddd, d MMMM yyyy");
                    return s.charAt(0).toUpperCase() + s.slice(1);
                }
                color: Theme.color.textMuted
            }

            SystemClock {
                id: clock
                precision: SystemClock.Minutes
            }
        }
    }

    Component {
        id: weatherCard

        WeatherCard {}
    }

    Component {
        id: calendarCard

        Calendar {
            Component.onCompleted: root.calendarItem = this
            Component.onDestruction: if (root.calendarItem === this)
                root.calendarItem = null
        }
    }

    Component {
        id: systemCard

        SystemCard {}
    }

    Component {
        id: mediaCard

        MediaPlayer {}
    }

    Component {
        id: notesCard

        QuickNote {
            Component.onCompleted: root.noteItem = this
            Component.onDestruction: if (root.noteItem === this)
                root.noteItem = null
        }
    }

    Component {
        id: networkCard

        NetworkCard {}
    }

    Grid {
        id: grid
        width: parent.width
        columns: root.columnCount
        spacing: 16
        Repeater {
            model: root.cardColumns
            Column {
                id: cardColumn
                required property var modelData
                width: (grid.width - grid.spacing * (grid.columns - 1)) / grid.columns
                spacing: 16
                Repeater {
                    model: cardColumn.modelData.cards
                    Rectangle {
                        id: card
                        required property string modelData
                        readonly property bool framed: !["media", "notes"].includes(modelData)
                        readonly property int padding: framed ? 12 : 0
                        width: parent.width
                        implicitHeight: (cardLoader.item?.implicitHeight ?? 0) + padding * 2
                        radius: 18
                        color: framed ? Theme.color.surface : "transparent"
                        visible: (cardLoader.item?.implicitHeight ?? 0) > 0
                        Loader {
                            id: cardLoader
                            x: card.padding
                            y: card.padding
                            width: parent.width - card.padding * 2
                            sourceComponent: root.cardComponents[card.modelData]
                        }
                    }
                }
            }
        }
    }
}
