import QtQuick
import qs.config
import qs.services
import qs.widgets

// PIN экрана блокировки для окна настроек: задать, сменить, убрать.
Column {
    id: root

    property string message: ""
    property bool messageIsError: false

    function save() {
        if (!/^[0-9]{4,12}$/.test(input.text)) {
            message = "PIN — от 4 до 12 цифр";
            messageIsError = true;
            return;
        }
        Lock.setPin(input.text);
        input.text = "";
        message = "PIN сохранён";
        messageIsError = false;
    }

    width: parent?.width ?? 0
    spacing: Theme.spacing.sm

    StyledText {
        width: parent.width
        text: Lock.hasPin
            ? "PIN задан. Экран разблокирует и PIN, и пароль пользователя. После 5 неверных PIN подряд он отключается на 5 минут."
            : "PIN не задан: экран разблокирует только пароль пользователя."
        wrapMode: Text.Wrap
    }

    StyledText {
        width: parent.width
        text: "Короткий PIN удобен, но слабее пароля: хранится не открытым текстом, но четыре цифры легко подобрать по файлу."
        color: Theme.color.textMuted
        font.pixelSize: Theme.font.caption
        wrapMode: Text.Wrap
    }

    Row {
        spacing: Theme.spacing.sm

        Rectangle {
            width: 180
            height: 30
            radius: Theme.radius.control
            color: Theme.color.background
            border.width: input.activeFocus ? 2 : 0
            border.color: Theme.color.focus

            TextInput {
                id: input

                anchors.fill: parent
                anchors.leftMargin: Theme.spacing.md
                anchors.rightMargin: Theme.spacing.md
                verticalAlignment: TextInput.AlignVCenter
                echoMode: TextInput.Password
                passwordCharacter: "•"
                inputMethodHints: Qt.ImhDigitsOnly
                validator: RegularExpressionValidator {
                    regularExpression: /[0-9]{0,12}/
                }
                color: Theme.color.text
                font.family: Theme.font.family
                font.pixelSize: Theme.font.body
                activeFocusOnTab: true
                onAccepted: root.save()

                StyledText {
                    anchors.fill: parent
                    text: Lock.hasPin ? "Новый PIN" : "PIN"
                    color: Theme.color.textMuted
                    visible: input.text === ""
                }
            }
        }

        TextButton {
            primary: true
            text: Lock.hasPin ? "Сменить" : "Задать"
            enabled: input.text.length >= 4
            onClicked: root.save()
        }

        TextButton {
            text: "Убрать PIN"
            visible: Lock.hasPin
            onClicked: {
                Lock.clearPin();
                root.message = "PIN убран";
                root.messageIsError = false;
            }
        }
    }

    StyledText {
        text: root.message
        color: root.messageIsError ? Theme.color.error : Theme.color.textMuted
        font.pixelSize: Theme.font.caption
        visible: text !== ""
    }
}
