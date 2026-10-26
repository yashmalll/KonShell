import QtQuick
import Quickshell
import Quickshell.Services.Polkit
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// Polkit-агент: окно ввода пароля, когда программе нужны права
// администратора (pkexec, монтирование дисков, установка пакетов из графических
// программ). Регистрируется агентом сессии при запуске оболочки; другой агент
// (polkit-gnome и т. п.) запускать не нужно.
Scope {
    id: root

    readonly property AuthFlow flow: agent.flow
    property string error: ""

    signal failed

    function submit(password) {
        if (!flow || !flow.isResponseRequired)
            return;
        error = "";
        flow.submit(password);
    }

    function cancel() {
        flow?.cancelAuthenticationRequest();
    }

    PolkitAgent {
        id: agent

        onIsRegisteredChanged: {
            if (isRegistered)
                console.info("polkit: агент зарегистрирован");
        }
    }

    Connections {
        target: root.flow

        function onAuthenticationFailed() {
            root.error = "Неверный пароль";
            root.failed();
        }
        // polkit сам сообщает подробности (например, «Попробуйте ещё раз»).
        function onSupplementaryMessageChanged() {
            if (root.flow.supplementaryIsError && root.flow.supplementaryMessage !== "")
                root.error = root.flow.supplementaryMessage;
        }
    }

    // Новый запрос — с чистого листа.
    onFlowChanged: error = ""

    LazyLoader {
        active: agent.isActive && root.flow !== null

        PanelWindow {
            screen: Quickshell.screens.find(s => s.name === Niri.focusedWorkspace?.output) ?? null
            WlrLayershell.namespace: "konshell-polkit"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            exclusionMode: ExclusionMode.Ignore
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            // Затемнение всего экрана: запрос прав важнее всего остального.
            color: Theme.color.scrim

            PopupSurface {
                id: card

                anchors.centerIn: parent
                width: 420
                height: content.implicitHeight + Theme.spacing.xl * 2
                // Окно на весь экран — поля под тень есть.
                elevated: true
                color: Theme.color.popup
                focus: true

                Keys.onEscapePressed: root.cancel()

                Column {
                    id: content

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.spacing.xl
                    spacing: Theme.spacing.lg

                    Row {
                        width: parent.width
                        spacing: Theme.spacing.md

                        SymbolIcon {
                            id: shield

                            anchors.verticalCenter: parent.verticalCenter
                            implicitSize: 24
                            name: "security-high-symbolic"
                            color: Theme.color.primary
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - shield.width - parent.spacing
                            text: "Требуются права администратора"
                            font.pixelSize: Theme.font.title
                            font.weight: Theme.font.medium
                            wrapMode: Text.Wrap
                        }
                    }

                    // Что именно просит программа — текст polkit.
                    StyledText {
                        width: parent.width
                        text: root.flow?.message ?? ""
                        wrapMode: Text.Wrap
                        lineHeight: 1.2
                        visible: text !== ""
                    }

                    StyledText {
                        width: parent.width
                        text: root.flow?.selectedIdentity?.displayName
                            ? `От имени: ${root.flow.selectedIdentity.displayName}` : ""
                        color: Theme.color.textMuted
                        font.pixelSize: Theme.font.caption
                        visible: text !== ""
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacing.xs

                        Rectangle {
                            id: field

                            width: parent.width
                            height: 40
                            radius: Theme.radius.control
                            color: Theme.color.surface
                            border.width: 2
                            border.color: root.error !== "" ? Theme.color.error
                                : input.activeFocus ? Theme.color.focus
                                : "transparent"

                            transform: Translate {
                                id: shake
                            }

                            TextInput {
                                id: input

                                anchors.fill: parent
                                anchors.leftMargin: Theme.spacing.md
                                anchors.rightMargin: Theme.spacing.md
                                verticalAlignment: TextInput.AlignVCenter
                                echoMode: root.flow?.responseVisible ? TextInput.Normal : TextInput.Password
                                passwordCharacter: "•"
                                color: Theme.color.text
                                selectionColor: Theme.color.selection
                                font.family: Theme.font.family
                                font.pixelSize: Theme.font.body
                                readOnly: !(root.flow?.isResponseRequired ?? false)
                                focus: true
                                clip: true

                                onAccepted: {
                                    root.submit(text);
                                    text = "";
                                }
                                Keys.onEscapePressed: root.cancel()

                                StyledText {
                                    anchors.fill: parent
                                    // Подсказка polkit обычно «Password:» — показываем по-русски.
                                    text: "Пароль"
                                    color: Theme.color.textMuted
                                    visible: input.text === ""
                                }

                                Component.onCompleted: forceActiveFocus()
                            }
                        }

                        Row {
                            spacing: Theme.spacing.xs
                            visible: root.error !== ""

                            SymbolIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                implicitSize: 14
                                name: "dialog-warning-symbolic"
                                color: Theme.color.error
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.error
                                color: Theme.color.error
                                font.pixelSize: Theme.font.caption
                            }
                        }
                    }

                    // Идентификатор действия — мелко: пригодится, если запрос неожиданный.
                    StyledText {
                        width: parent.width
                        text: root.flow?.actionId ?? ""
                        color: Theme.color.textMuted
                        font.family: Theme.font.mono
                        font.pixelSize: Theme.font.caption
                        elide: Text.ElideMiddle
                        visible: text !== ""
                    }

                    Row {
                        anchors.right: parent.right
                        spacing: Theme.spacing.sm

                        TextButton {
                            text: "Отмена"
                            onClicked: root.cancel()
                        }

                        TextButton {
                            primary: true
                            text: "Подтвердить"
                            enabled: input.text !== "" && (root.flow?.isResponseRequired ?? false)
                            onClicked: input.accepted()
                        }
                    }
                }
            }

            Connections {
                target: root

                function onFailed() {
                    input.text = "";
                    input.forceActiveFocus();
                    shakeAnimation.restart();
                }
            }

            SequentialAnimation {
                id: shakeAnimation

                NumberAnimation { target: shake; property: "x"; to: -10; duration: Theme.anim.fast / 3 }
                NumberAnimation { target: shake; property: "x"; to: 10; duration: Theme.anim.fast / 2 }
                NumberAnimation { target: shake; property: "x"; to: -6; duration: Theme.anim.fast / 2 }
                NumberAnimation { target: shake; property: "x"; to: 0; duration: Theme.anim.fast / 3 }
            }
        }
    }
}
