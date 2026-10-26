import QtQuick
import qs.config
import qs.widgets
import "../../config/settings-schema.js" as Schema

// Один параметр из реестра настроек (config/settings-schema.js): название, пояснение,
// элемент управления по типу и кнопка сброса, если значение отличается от умолчания.
// host — окно настроек: чтение и запись значений, действия и встроенные компоненты.
Item {
    id: root

    required property var option
    required property var host

    readonly property var value: option.key ? host.read(option.key) : undefined
    readonly property bool isList: Array.isArray(option.def)
    readonly property var plainValue: isList ? Array.from(value ?? []) : value
    readonly property bool resettable: option.key !== undefined && option.def !== undefined
        && JSON.stringify(plainValue) !== JSON.stringify(option.def)

    function write(v) {
        host.write(option.key, v);
    }

    width: parent?.width ?? 0
    implicitHeight: loader.implicitHeight
    visible: host.shown(option)

    Loader {
        id: loader

        width: parent.width
        sourceComponent: ({
            switch: switchControl,
            choice: choiceControl,
            flags: flagsControl,
            slider: sliderControl,
            text: textControl,
            list: textControl,
            color: colorControl,
            action: actionControl,
            custom: customControl
        })[root.option.type] ?? null
    }

    // Название и пояснение слева, справа — значение (для ползунка) и сброс.
    component Header: Item {
        id: header

        property string valueText: ""
        default property alias trailing: trailingRow.data

        width: parent?.width ?? 0
        implicitHeight: Math.max(texts.implicitHeight, trailingRow.implicitHeight)

        Column {
            id: texts

            anchors.left: parent.left
            anchors.right: trailingRow.left
            anchors.rightMargin: Theme.spacing.md
            anchors.verticalCenter: parent.verticalCenter

            StyledText {
                width: parent.width
                text: root.option.title
            }

            StyledText {
                width: parent.width
                text: root.option.hint ?? ""
                color: Theme.color.textMuted
                font.pixelSize: Theme.font.caption
                wrapMode: Text.Wrap
                visible: text !== ""
            }
        }

        Row {
            id: trailingRow

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacing.sm

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: header.valueText
                color: Theme.color.textMuted
                font.pixelSize: Theme.font.caption
                font.features: { "tnum": 1 }
                visible: text !== ""
            }

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: 24
                implicitHeight: 24
                icon: "edit-undo-symbolic"
                iconSize: 12
                iconColor: Theme.color.textMuted
                visible: root.resettable
                Accessible.name: "Вернуть по умолчанию"
                onClicked: root.write(root.option.def)
            }
        }
    }

    Component {
        id: switchControl

        Header {
            Switch {
                anchors.verticalCenter: parent.verticalCenter
                checked: root.value === true
                Accessible.name: root.option.title
                onToggled: root.write(!root.value)
            }
        }
    }

    Component {
        id: choiceControl

        Column {
            spacing: Theme.spacing.sm

            Header {}

            Flow {
                width: parent.width
                spacing: Theme.spacing.xs

                Repeater {
                    model: root.option.choices

                    Chip {
                        required property var modelData

                        text: modelData[1]
                        checked: root.value === modelData[0]
                        onClicked: root.write(modelData[0])
                    }
                }
            }
        }
    }

    Component {
        id: flagsControl

        Column {
            spacing: Theme.spacing.sm

            Header {}

            Flow {
                width: parent.width
                spacing: Theme.spacing.xs

                Repeater {
                    model: root.option.choices

                    Chip {
                        required property var modelData

                        readonly property bool on: root.plainValue.includes(modelData[0])

                        text: modelData[1]
                        checked: on
                        onClicked: root.write(on ? root.plainValue.filter(v => v !== modelData[0])
                                                 : root.plainValue.concat([modelData[0]]))
                    }
                }
            }
        }
    }

    Component {
        id: sliderControl

        Column {
            spacing: Theme.spacing.sm

            Header {
                valueText: Schema.formatValue(root.option, root.value)
            }

            Slider {
                readonly property real span: root.option.max - root.option.min

                width: parent.width
                value: (root.value - root.option.min) / span
                step: root.option.step / span
                Accessible.name: root.option.title
                onMoved: v => {
                    const raw = root.option.min + v * span;
                    const snapped = Math.round(raw / root.option.step) * root.option.step;
                    // Округление до точности шага: 0.1 + 0.2 не должно стать 0.30000000000000004.
                    root.write(Number(Math.max(root.option.min, Math.min(root.option.max, snapped)).toFixed(4)));
                }
            }
        }
    }

    // Текст и список (через запятую): применяется по Enter или при уходе из поля.
    Component {
        id: textControl

        Column {
            spacing: Theme.spacing.sm

            Header {}

            Rectangle {
                width: parent.width
                height: 32
                radius: Theme.radius.control
                color: Theme.color.surface
                border.width: input.activeFocus ? 2 : 0
                border.color: Theme.color.focus

                TextInput {
                    id: input

                    function shownText() {
                        return root.isList ? root.plainValue.join(", ") : String(root.value ?? "");
                    }

                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacing.md
                    anchors.rightMargin: Theme.spacing.md
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.color.text
                    selectionColor: Theme.color.selection
                    font.family: Theme.font.family
                    font.pixelSize: Theme.font.body
                    clip: true
                    activeFocusOnTab: true
                    text: shownText()

                    onEditingFinished: {
                        if (root.isList)
                            root.write(text.split(",").map(s => s.trim()).filter(s => s !== ""));
                        else
                            root.write(text.trim());
                    }

                    // Значение сменилось снаружи (сброс, другой раздел) — показать новое.
                    Connections {
                        target: root

                        function onValueChanged() {
                            if (!input.activeFocus)
                                input.text = input.shownText();
                        }
                    }

                    StyledText {
                        anchors.fill: parent
                        text: "Не задано"
                        color: Theme.color.textMuted
                        visible: input.text === "" && !input.activeFocus
                    }
                }
            }
        }
    }

    Component {
        id: colorControl

        Column {
            spacing: Theme.spacing.sm

            Header {}

            Row {
                spacing: Theme.spacing.sm

                Rectangle {
                    width: 32
                    height: 32
                    radius: Theme.radius.control
                    color: /^#[0-9a-fA-F]{6}$/.test(root.value ?? "") ? root.value : "transparent"
                    border.width: 1
                    border.color: Theme.color.outline
                }

                Rectangle {
                    width: 140
                    height: 32
                    radius: Theme.radius.control
                    color: Theme.color.surface
                    border.width: hex.activeFocus ? 2 : (hexInvalid ? 2 : 0)
                    border.color: hexInvalid ? Theme.color.error : Theme.color.focus

                    readonly property bool hexInvalid: hex.text !== "" && !/^#?[0-9a-fA-F]{6}$/.test(hex.text)

                    TextInput {
                        id: hex

                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacing.md
                        anchors.rightMargin: Theme.spacing.md
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.color.text
                        font.family: Theme.font.mono
                        font.pixelSize: Theme.font.body
                        maximumLength: 7
                        activeFocusOnTab: true
                        text: root.value ?? ""

                        onEditingFinished: {
                            if (text === "")
                                root.write("");
                            else if (/^#?[0-9a-fA-F]{6}$/.test(text))
                                root.write((text.startsWith("#") ? text : "#" + text).toLowerCase());
                        }

                        Connections {
                            target: root

                            function onValueChanged() {
                                if (!hex.activeFocus)
                                    hex.text = root.value ?? "";
                            }
                        }

                        StyledText {
                            anchors.fill: parent
                            text: "#rrggbb"
                            color: Theme.color.textMuted
                            visible: hex.text === "" && !hex.activeFocus
                        }
                    }
                }
            }
        }
    }

    Component {
        id: actionControl

        TextButton {
            text: root.option.title
            onClicked: root.host.runAction(root.option.action)
        }
    }

    Component {
        id: customControl

        Loader {
            width: parent?.width ?? 0
            sourceComponent: root.host.customComponent(root.option.component)
        }
    }
}
