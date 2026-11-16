import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets
import qs.modules.dashboard
import qs.modules.notifications
import qs.modules.controlcenter

// Панель на каждом мониторе; Variants сам создаёт и удаляет
// окна при подключении и отключении мониторов.
// Dynamic Island: компактные часы и активность, при наведении — все три зоны.
// Какие виджеты где — bar.left/center/right в настройках (окно «Настройки» → «Панель»);
// изменения применяются сразу.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: bar

        required property ShellScreen modelData

        // id виджета → компонент; монитору нужны рабочие столы своего экрана.
        readonly property var widgets: ({
                workspaces: workspacesComponent,
                windowTitle: windowTitleComponent,
                tray: trayComponent,
                keyboard: keyboardComponent,
                status: statusComponent,
                notifications: notificationsComponent,
                sysmon: sysmonComponent,
                weather: weatherComponent,
                media: mediaComponent,
                network: networkComponent,
                note: noteComponent,
                date: dateComponent,
                clock: clockComponent
            })

        function ownerOf(id) {
            return [leftZone, centerZone, rightZone].find(z => z.ids.includes(id)) ?? null;
        }

        function showWidget(id) {
            if (FocusMode.active && !["clock", "date", "workspaces", "keyboard", "status", "notifications"].includes(id))
                return false;
            if (id === "media")
                return Media.player !== null;
            if (id === "weather")
                return Settings.weather.enabled && Weather.available && Weather.loadState !== "idle";
            if (id === "keyboard")
                return Niri.keyboardLayouts.length > 1;
            if (id === "windowTitle")
                return (Niri.focusedWindow?.title ?? "") !== "";
            return true;
        }

        screen: modelData
        WlrLayershell.namespace: "konshell-bar"
        WlrLayershell.layer: WlrLayer.Overlay
        // Островок поверх окон, без зарезервированной полосы рабочего стола.
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        anchors {
            top: true
            left: true
            right: true
        }
        readonly property bool activeScreen: modelData.name === (Niri.focusedWorkspace?.output ?? Quickshell.screens[0]?.name) && !Lock.locked
        readonly property bool panelOpen: activeScreen && (Ui.dashboardOpen || Notifications.centerOpen || Ui.privacyOpen || Ui.controlCenterOpen || Ui.timerOpen)
        readonly property bool showingDashboard: panelOpen && Ui.dashboardOpen
        readonly property var incoming: Settings.bar.islandNotifications && activeScreen && !panelOpen ? Notifications.popups[0] ?? null : null
        readonly property bool toastMode: incoming !== null && !panelOpen
        onToastModeChanged: {
            hoverReady = false;
            hoverDelay.stop();
            collapseDelay.stop();
            if (!toastMode) suppressHover = pointerInside;
        }
        readonly property bool levelVisible: Settings.bar.islandOsd && activeScreen && Ui.islandOsdShown
        readonly property bool glanceVisible: Settings.bar.islandGlance && !toastMode && expanded && !Ui.dashboardOpen && !Ui.controlCenterOpen && !Notifications.centerOpen && !Ui.privacyOpen && !Ui.timerOpen
        readonly property bool hasDetails: panelOpen || incoming !== null || levelVisible || glanceVisible
        readonly property string contentMode: panelOpen ? (showingDashboard ? "dashboard" : Ui.timerOpen ? "timer" : Ui.privacyOpen ? "privacy" : Ui.controlCenterOpen ? "control:" + Ui.controlCenterPage : "history") : incoming !== null ? "notification" : levelVisible ? "level" : glanceVisible ? "glance" : "rest"
        // Отрисованная страница меняется после ухода прежней, а при закрытии
        // сохраняется до возвращения поверхности в маркер.
        property string displayMode: "rest"
        property string pendingMode: "rest"
        property real pagePhase: 1
        property int pageDirection: 1
        readonly property bool displayPanelOpen: ["dashboard", "history", "privacy", "timer"].includes(displayMode) || displayMode.startsWith("control:")
        readonly property bool closing: !revealed && revealProgress > 0
        readonly property bool displayExpanded: expanded || closing
        property real closingWidth: 192
        property real closingHeight: 4
        readonly property real detailHeight: displayPanelOpen ? (panelContent.item?.implicitHeight ?? 0) : eventDetails.hasContent ? eventDetails.implicitHeight : 0
        function modeOrder(mode) {
            if (mode === "dashboard") return 0;
            if (mode.startsWith("control:")) return 1;
            if (mode === "history") return 2;
            return -1;
        }
        function commitContent() {
            displayMode = pendingMode;
            detailViewport.contentY = 0;
            detailViewport.returnToBounds();
        }
        function queueContent() {
            pendingMode = contentMode;
            if (!revealed) return;
            if (motionScale === 0 || !revealReady || revealAmount < 0.8) {
                pageOut.stop();
                pageIn.stop();
                commitContent();
                pagePhase = 1;
                return;
            }
            if (pendingMode === displayMode) {
                if (!pageOut.running && pagePhase < 1) pageIn.restart();
                return;
            }
            if (pageOut.running) return;
            pageIn.stop();
            const from = modeOrder(displayMode), to = modeOrder(pendingMode);
            pageDirection = from >= 0 && to >= 0 && from !== to ? (to > from ? 1 : -1) : 0;
            pageOut.restart();
        }
        onContentModeChanged: Qt.callLater(queueContent)
        NumberAnimation {
            id: pageOut
            target: bar
            property: "pagePhase"
            to: 0
            duration: Math.round(170 * bar.motionScale)
            easing.type: Easing.InOutSine
            onFinished: {
                bar.commitContent();
                pageIn.restart();
            }
        }
        NumberAnimation {
            id: pageIn
            target: bar
            property: "pagePhase"
            to: 1
            duration: Math.round(340 * bar.motionScale)
            easing.type: Easing.OutQuart
        }
        readonly property real bodyTop: displayMode === "notification" ? 12 : Settings.panelHeight - 8 + (displayPanelOpen ? 48 : 0)
        readonly property real maximumBodyHeight: Math.max(100, modelData.height * (displayPanelOpen ? 0.84 : 0.5) - bodyTop - 20)
        readonly property real surfaceHeight: displayExpanded && (displayPanelOpen || displayMode !== "rest") ? bodyTop + detailViewport.height + 32 : Settings.panelHeight
        readonly property string panelTitle: displayMode === "dashboard" ? "Обзор дня" : displayMode === "timer" ? "Таймер и Pomodoro" : displayMode.startsWith("control:") ? "Управление" : displayMode === "privacy" ? "Приватность" : "Уведомления"
        // Размер Wayland-окна не меняется каждый кадр; ввод ограничивает mask.
        readonly property bool motionRunning: revealMotion.running || widthMotion.running || heightMotion.running || radiusMotion.running
        implicitHeight: panelOpen || motionRunning ? modelData.height : Math.max(surfaceHeight, island.y + island.height + 14)
        WlrLayershell.keyboardFocus: panelOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        onPanelOpenChanged: {
            if (panelOpen)
                Qt.callLater(() => island.forceActiveFocus());
        }
        function closePanel() {
            if (BluetoothState.interactionPending) BluetoothState.cancelPrompt();
            Ui.closeIslandPanels();
            suppressHover = pointerInside;
            hoverReady = false;
            hoverDelay.stop();
            collapseDelay.stop();
        }
        color: "transparent"
        property bool hoverReady: false
        property bool suppressHover: false
        readonly property bool fullscreen: Niri.fullscreenOn(modelData.name, modelData.width, modelData.height)
        readonly property bool revealed: expanded || (!fullscreen && (!Settings.bar.autoHide || Privacy.active))
        property real markerPresence: fullscreen ? 0 : 1
        Behavior on markerPresence { NumberAnimation { duration: bar.motion.normal; easing.type: Easing.InOutSine } }
        readonly property real markerTextReveal: Math.max(0, Math.min(1, (markerPresence - 0.55) / 0.45))
        readonly property real markerWidth: Math.min(bar.width - 24, 192 + 108 * markerPresence)
        readonly property bool pointerInside: islandHover.hovered || (centralHover.hovered && (!revealed || closing || layoutOrigin === "center")) || leftMarker.hovered || rightMarker.hovered
        // Закрытие следует за общим состоянием, даже если скрывшийся боковой
        // маркер не прислал leave или страница открылась без входа в центр.
        readonly property bool shouldAutoClose: expanded && !pointerInside && !statusLine.trayOpen && !BluetoothState.interactionPending && !toastMode
        function syncAutoClose() {
            if (shouldAutoClose) {
                if (!collapseDelay.running) collapseDelay.restart();
            } else collapseDelay.stop();
        }
        onShouldAutoCloseChanged: Qt.callLater(syncAutoClose)
        property string surfaceOrigin: "center"
        readonly property string layoutOrigin: revealed || closing ? surfaceOrigin : "center"
        readonly property real collapsedWidth: markerWidth - markerCurve * (layoutOrigin === "center" ? 2 : 1)
        function openSection(section) {
            Ui.islandOrigin = section === "dashboard" ? "left" : "right";
            surfaceOrigin = Ui.islandOrigin;
            suppressHover = false;
            hoverDelay.stop();
            collapseDelay.stop();
            hoverReady = true;
            Ui.openIslandAt(surfaceOrigin);
        }
        function openFromMarker() {
            Ui.islandOrigin = "center";
            surfaceOrigin = "center";
            suppressHover = false;
            hoverDelay.stop();
            collapseDelay.stop();
            hoverReady = true;
            if (Countdown.active && !fullscreen) Ui.openTimer();
            else Ui.openDashboard(false);
        }
        // Экономия батареи отключает фоновые эффекты, но оставляет переход
        // открытия. Явное «Без анимаций» имеет приоритет.
        readonly property real motionScale: Settings.theme.reduceMotion ? 0
            : 1 / Math.max(0.25, Math.min(4, Settings.theme.animationSpeed))
        readonly property QtObject motion: QtObject {
            readonly property int fast: Math.round(220 * bar.motionScale)
            readonly property int normal: Math.round(360 * bar.motionScale)
            readonly property int slow: Math.round(560 * bar.motionScale)
        }
        property bool revealReady: false
        property real revealProgress: revealReady ? 1 : 0
        readonly property real revealAmount: Math.max(0, Math.min(1, revealProgress))
        readonly property real markerCorner: Math.min(2 + 5 * markerPresence, (2 + 5 * markerPresence) * Theme.cornerScale)
        readonly property real markerCurve: Math.min(32, 32 * Theme.cornerScale)
        readonly property real markerHeight: 4 + 10 * markerPresence
        readonly property real edgeFillet: Math.min(markerCurve + (24 * Theme.cornerScale - markerCurve) * revealAmount,
            Math.max(0, (bar.width - island.width) / 2))
        readonly property real edgeFilletHeight: Math.min(markerCorner + (24 * Theme.cornerScale - markerCorner) * revealAmount,
            island.height)
        function prepareReveal() {
            entryWarmup.frames = 0;
            if (!revealed && revealProgress === 0) {
                pendingMode = contentMode;
                commitContent();
                pagePhase = 1;
            }
            revealReady = revealed && (motionScale === 0 || revealProgress > 0);
            if (revealed && !revealReady)
                entryFallback.restart();
            else
                entryFallback.stop();
        }
        onRevealedChanged: {
            if (!revealed) {
                closingWidth = island.shapeWidth;
                closingHeight = island.shapeHeight;
                pageOut.stop();
                pageIn.stop();
            } else {
                surfaceOrigin = Ui.islandOrigin;
                queueContent();
            }
            Qt.callLater(prepareReveal);
        }
        Component.onCompleted: prepareReveal()
        // Отсчёт начинается после подготовки поверхности, а не за время,
        // пока Qt создаёт карточки и композитор ещё не показал первый кадр.
        FrameAnimation {
            id: entryWarmup
            property int frames: 0
            running: bar.revealed && !bar.revealReady
            onTriggered: {
                if (++frames >= 2) {
                    bar.revealReady = true;
                    entryFallback.stop();
                    contentEntrance.restart();
                }
            }
        }
        Timer {
            id: entryFallback
            interval: 160
            onTriggered: {
                if (bar.revealed) {
                    bar.revealReady = true;
                    contentEntrance.restart();
                }
            }
        }
        Behavior on revealProgress {
            NumberAnimation {
                id: revealMotion
                duration: Math.round((bar.revealed ? 760 : 680) * bar.motionScale)
                easing.type: Easing.InOutSine
                onFinished: {
                    if (!bar.revealed) {
                        bar.pendingMode = bar.contentMode;
                        bar.commitContent();
                        bar.pagePhase = 1;
                        if (bar.activeScreen) Ui.islandOrigin = "center";
                        bar.surfaceOrigin = "center";
                    }
                }
            }
        }
        NumberAnimation {
            id: contentEntrance
            target: island
            property: "contentPhase"
            from: 0
            to: 1
            duration: bar.motion.normal
            easing.type: Easing.OutQuart
        }
        readonly property bool expanded: (hoverReady && !suppressHover && !compactContent.activityHovered) || collapseDelay.running || statusLine.trayOpen || panelOpen || (activeScreen && Ui.controlCenterOpen) || incoming !== null || levelVisible || (Ui.islandPinned && activeScreen)

        // Полноэкранный ввод только у открытых панелей: клик снаружи закрывает их.
        mask: panelOpen ? null : inputMask
        BackgroundEffect.blurRegion: Region {}
        Region {
            id: inputMask
            item: inputArea
            Region { item: centralHit }
            Region { item: leftMarker }
            Region { item: rightMarker }
        }

        MouseArea {
            anchors.fill: parent
            enabled: bar.panelOpen
            onClicked: bar.closePanel()
        }

        Item {
            id: inputArea
            anchors.top: parent.top
            x: bar.layoutOrigin === "left" ? 0 : bar.layoutOrigin === "right" ? bar.width - width : (bar.width - width) / 2
            width: bar.revealed ? Math.max(bar.markerWidth, island.width + bar.edgeFillet * 2) : Math.min(bar.markerWidth + 48, bar.width)
            height: bar.revealed ? Math.max(bar.markerHeight + 4, island.y + island.height) : Settings.bar.islandHint || Countdown.active ? bar.markerHeight + 6 : 3
            HoverHandler {
                id: islandHover
                enabled: bar.revealed || bar.closing
                onHoveredChanged: {
                    if (hovered && !bar.toastMode) {
                        // Новый вход всегда снимает запрет, оставшийся от закрытия.
                        bar.suppressHover = false;
                        // Возврат во время задержки не должен сворачивать островок
                        // на время повторного ожидания hoverDelay.
                        if (collapseDelay.running || bar.closing || bar.expanded) {
                            bar.hoverReady = true;
                            collapseDelay.stop();
                            hoverDelay.stop();
                        } else if (!bar.hoverReady) {
                            hoverDelay.restart();
                        }
                    } else if (!hovered) {
                        if (bar.expanded && !bar.pointerInside && !bar.suppressHover)
                            collapseDelay.restart();
                        hoverDelay.stop();
                        bar.hoverReady = false;
                        bar.suppressHover = false;
                    }
                }
            }
            // Островок — потомок области наведения, поэтому переход на дату,
            // кнопки и другие виджеты не считается уходом с островка.
            Timer {
                id: hoverDelay
                interval: 180
                onTriggered: {
                    if ((islandHover.hovered || centralHover.hovered) && !bar.suppressHover && !bar.toastMode)
                        bar.hoverReady = true;
                }
            }
            Timer {
                id: collapseDelay
                interval: Math.max(100, Settings.bar.islandCollapseDelay)
                onTriggered: {
                    if (!bar.pointerInside && !statusLine.trayOpen && !BluetoothState.interactionPending)
                        bar.closePanel();
                }
            }

            // Тихая подсказка на обоих типах обоев, без постоянной анимации.
            Rectangle {
                anchors.top: parent.top
                x: (bar.width - width) / 2 - inputArea.x
                width: bar.markerWidth
                height: bar.markerHeight + 4
                radius: 6
                clip: true
                color: "transparent"
                opacity: (Settings.bar.islandHint || Countdown.active) && !Lock.locked ? Math.max(0, 1 - bar.revealAmount * 3) : 0
                visible: opacity > 0
                enabled: !Lock.locked
                Accessible.role: Accessible.Button
                Accessible.name: "Открыть остров · " + Qt.locale().toString(markerClock.date, "d MMMM HH:mm")

                Shape {
                    id: markerShape
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    width: bar.markerWidth
                    height: bar.markerHeight
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeWidth: 0
                        strokeColor: "transparent"
                        fillColor: Theme.color.background
                        startX: 0
                        startY: 0
                        // Горизонтальные касательные по обоим концам: без острого среза.
                        PathCubic {
                            x: bar.markerCurve
                            y: markerShape.height
                            control1X: bar.markerCurve / 2
                            control1Y: 0
                            control2X: bar.markerCurve / 2
                            control2Y: markerShape.height
                        }
                        PathLine { x: markerShape.width - bar.markerCurve; y: markerShape.height }
                        PathCubic {
                            x: markerShape.width
                            y: 0
                            control1X: markerShape.width - bar.markerCurve / 2
                            control1Y: markerShape.height
                            control2X: markerShape.width - bar.markerCurve / 2
                            control2Y: 0
                        }
                        PathLine { x: 0; y: 0 }
                    }
                }
                SystemClock { id: markerClock; precision: SystemClock.Minutes }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: (bar.markerHeight - height) / 2
                    spacing: 8
                    opacity: bar.markerTextReveal * bar.markerTextReveal * (3 - 2 * bar.markerTextReveal)
                    visible: opacity > 0
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Qt.locale().toString(markerClock.date, "d MMMM") + "  ·  " + Qt.formatTime(markerClock.date, "HH:mm")
                        color: Theme.color.text
                        font.pixelSize: Math.min(11, Theme.font.caption)
                        font.weight: Font.Medium
                        font.features: { "tnum": 1 }
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: Countdown.active
                        text: "· " + (Countdown.attention ? "Готово" : (Countdown.running ? "" : "Ⅱ ") + Countdown.text)
                        color: Theme.color.textMuted
                        font.pixelSize: Math.min(11, Theme.font.caption)
                        font.features: { "tnum": 1 }
                    }
                }
            }

            // Вогнутые внешние переходы: островок плавно срастается с краем экрана.
            Repeater {
                model: 2
                Shape {
                    id: corner
                    required property int index
                    width: bar.edgeFillet + 2
                    height: bar.edgeFilletHeight
                    x: island.x + (index === 0 ? -bar.edgeFillet : island.width - 2)
                    y: 0
                    visible: bar.revealProgress > 0 && bar.edgeFillet > 0.5 && !(bar.layoutOrigin === "left" && index === 0) && !(bar.layoutOrigin === "right" && index === 1)
                    transform: Scale {
                        origin.x: corner.width / 2
                        xScale: corner.index === 0 ? 1 : -1
                    }
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeWidth: 0
                        strokeColor: "transparent"
                        fillColor: island.color
                        startX: 0
                        startY: 0
                        // Перекрытие устраняет шов между сглаженными краями.
                        PathLine { x: bar.edgeFillet + 2; y: 0 }
                        PathLine { x: bar.edgeFillet + 2; y: bar.edgeFilletHeight }
                        PathLine { x: bar.edgeFillet; y: bar.edgeFilletHeight }
                        PathArc {
                            x: 0
                            y: 0
                            radiusX: bar.edgeFillet
                            radiusY: bar.edgeFilletHeight
                            direction: PathArc.Counterclockwise
                        }
                    }
                }
            }

            Rectangle {
                id: island
                x: bar.layoutOrigin === "left" ? 0 : bar.layoutOrigin === "right" ? inputArea.width - width : (inputArea.width - width) / 2
                readonly property real targetWidth: Math.min(bar.width - 16, bar.displayExpanded ? (bar.displayPanelOpen ? ((bar.displayMode === "dashboard") ? 1360 : 880) : (bar.displayMode === "notification") ? 480 : Settings.bar.compactHeader ? 640 : Math.max(expandedContent.implicitWidth + 16, bar.hasDetails ? 460 : 0)) : compactContent.implicitWidth + 24)
                readonly property real targetHeight: bar.displayExpanded ? bar.surfaceHeight - 16 : Math.max(34, Settings.panelHeight - 22)
                readonly property real targetRadius: bar.displayExpanded && (bar.displayPanelOpen || bar.displayMode !== "rest") ? 24 : targetHeight / 2
                property real shapeWidth: targetWidth
                property real shapeHeight: targetHeight
                property real shapeRadius: targetRadius
                property real contentPhase: 1
                readonly property real widthReveal: 1 - Math.pow(1 - bar.revealAmount, 1.35)
                readonly property real heightReveal: bar.revealAmount
                readonly property real closingFade: bar.closing ? Math.max(0, (bar.revealAmount - 0.65) / 0.35) : 1
                readonly property real contentRevealRaw: Math.max(0, Math.min(1, (bar.revealAmount - 0.36) / 0.64))
                readonly property real contentReveal: contentRevealRaw * contentRevealRaw * (3 - 2 * contentRevealRaw)
                readonly property color markerColor: Theme.color.background

                // Сначала раскрывается ширина, затем высота; содержимое не пережимается.
                y: 0
                width: bar.collapsedWidth + ((bar.closing ? bar.closingWidth : shapeWidth) - bar.collapsedWidth) * widthReveal
                height: bar.markerHeight + ((bar.closing ? bar.closingHeight : shapeHeight) - bar.markerHeight) * heightReveal
                radius: Math.min(height / 2, bar.markerCorner + (shapeRadius - bar.markerCorner) * bar.revealAmount)
                topLeftRadius: 0
                topRightRadius: 0
                bottomLeftRadius: bar.layoutOrigin === "left" ? 0 : radius
                bottomRightRadius: bar.layoutOrigin === "right" ? 0 : radius
                color: Qt.rgba(markerColor.r + (Theme.color.background.r - markerColor.r) * bar.revealAmount, markerColor.g + (Theme.color.background.g - markerColor.g) * bar.revealAmount, markerColor.b + (Theme.color.background.b - markerColor.b) * bar.revealAmount, 1)
                antialiasing: true
                clip: true
                visible: bar.revealProgress > 0
                enabled: bar.revealed
                Keys.onEscapePressed: {
                    if (Ui.controlCenterOpen && Ui.controlCenterPage !== "main")
                        Ui.controlCenterPage = "main";
                    else
                        bar.closePanel();
                }
                Behavior on shapeWidth {
                    enabled: bar.revealed && bar.revealAmount >= 0.999
                    NumberAnimation {
                        id: widthMotion
                        duration: bar.motion.slow
                        easing.type: Easing.InOutSine
                    }
                }
                Behavior on shapeHeight {
                    enabled: bar.revealed && bar.revealAmount >= 0.999
                    NumberAnimation {
                        id: heightMotion
                        duration: bar.motion.slow
                        easing.type: Easing.InOutSine
                    }
                }
                Behavior on shapeRadius {
                    enabled: bar.revealed && bar.revealAmount >= 0.999
                    NumberAnimation {
                        id: radiusMotion
                        duration: bar.motion.slow
                        easing.type: Easing.InOutSine
                    }
                }

                Item {
                    id: contentCanvas
                    x: bar.layoutOrigin === "left" ? 0 : bar.layoutOrigin === "right" ? island.width - width : (island.width - width) / 2
                    width: bar.closing ? bar.closingWidth : island.targetWidth
                    height: bar.closing ? bar.closingHeight : island.targetHeight
                    opacity: island.contentReveal * island.contentPhase * island.closingFade
                    transform: Translate {
                        y: bar.closing ? -8 * (1 - island.closingFade) : 8 * (1 - island.contentReveal * island.contentPhase)
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton && Settings.bar.rightClickDashboard)
                                Ui.dashboardOpen = !Ui.dashboardOpen;
                        }
                    }

                    IslandRest {
                        id: compactContent
                        anchors.centerIn: parent
                        opacity: bar.displayExpanded ? 0 : 1
                        visible: opacity > 0
                        enabled: !bar.displayExpanded
                        Behavior on opacity {
                            NumberAnimation {
                                duration: bar.motion.fast
                            }
                        }
                    }

                    Flickable {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: Settings.panelHeight - 16
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        contentWidth: expandedContent.implicitWidth
                        contentHeight: height
                        boundsBehavior: Flickable.StopAtBounds
                        flickableDirection: Flickable.HorizontalFlick
                        opacity: bar.displayExpanded && !(bar.displayMode === "notification") && !bar.displayPanelOpen && !Settings.bar.compactHeader ? 1 : 0
                        visible: opacity > 0
                        enabled: bar.displayExpanded && !(bar.displayMode === "notification") && !bar.displayPanelOpen && !Settings.bar.compactHeader
                        clip: true
                        Behavior on opacity {
                            NumberAnimation {
                                duration: bar.motion.normal
                            }
                        }

                        RowLayout {
                            id: expandedContent
                            height: parent.height
                            spacing: 10
                            Zone {
                                id: leftZone
                                ids: Profiles.idsForZone("left")
                            }
                            Zone {
                                id: centerZone
                                ids: Profiles.idsForZone("center")
                            }
                            Zone {
                                id: rightZone
                                ids: Profiles.idsForZone("right")
                            }
                            PrivacyIndicator {
                                Layout.alignment: Qt.AlignVCenter
                            }
                            TextButton {
                                text: FocusMode.summary
                                visible: FocusMode.active
                                onClicked: FocusMode.stop()
                            }
                        }
                    }

                    IslandStatusLine {
                        id: statusLine
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        height: Settings.panelHeight - 16
                        visible: bar.displayExpanded && !(bar.displayMode === "notification") && (bar.displayPanelOpen || Settings.bar.compactHeader)
                        title: bar.displayPanelOpen ? bar.panelTitle : ""
                        closable: bar.displayPanelOpen
                        onCloseRequested: bar.closePanel()
                        onTrayOpenChanged: {
                            if (!trayOpen && !bar.pointerInside && bar.displayPanelOpen)
                                collapseDelay.restart();
                        }
                    }

                    RowLayout {
                        id: panelToolbar
                        x: 16
                        y: Settings.panelHeight - 12
                        width: parent.width - 32
                        height: 40
                        spacing: 4
                        visible: bar.displayPanelOpen
                        IslandTab {
                            text: "Обзор"
                            icon: "view-grid-symbolic"
                            selected: (bar.displayMode === "dashboard")
                            onClicked: Ui.openDashboard(false)
                        }
                        IslandTab {
                            text: "Управление"
                            icon: "preferences-system-symbolic"
                            selected: bar.displayMode.startsWith("control:")
                            onClicked: Ui.controlCenterOpen = true
                        }
                        IslandTab {
                            text: Notifications.count ? `Уведомления · ${Notifications.count}` : "Уведомления"
                            icon: "preferences-system-notifications-symbolic"
                            selected: bar.displayMode === "history"
                            onClicked: Notifications.centerOpen = true
                        }
                    }

                    Flickable {
                        id: detailViewport
                        x: 16
                        y: bar.bodyTop
                        width: parent.width - 32
                        height: Math.min(bar.detailHeight, bar.maximumBodyHeight)
                        contentWidth: width
                        contentHeight: bar.detailHeight
                        boundsBehavior: Flickable.StopAtBounds
                        clip: true
                        visible: bar.displayExpanded && (bar.displayPanelOpen || bar.displayMode !== "rest")
                        opacity: bar.pagePhase
                        enabled: bar.pagePhase > 0.98 && !pageOut.running && !bar.closing
                        transform: Translate {
                            x: bar.pageDirection * (pageOut.running ? -12 : 18) * (1 - bar.pagePhase)
                            y: bar.pageDirection === 0 ? (pageOut.running ? -5 : 7) * (1 - bar.pagePhase) : 0
                        }

                        Column {
                            id: detailColumn
                            width: parent.width
                            spacing: 14
                            Loader {
                                id: panelContent
                                width: parent.width
                                active: bar.displayPanelOpen
                                visible: active
                                height: active ? (item?.implicitHeight ?? 0) : 0
                                sourceComponent: bar.displayMode === "dashboard" ? dashboardContent : bar.displayMode === "timer" ? timerContent : bar.displayMode === "privacy" ? privacyContent : bar.displayMode.startsWith("control:") ? controlContent : notificationContent
                            }
                            IslandDetails {
                                id: eventDetails
                                width: parent.width
                                visible: !bar.displayPanelOpen && hasContent
                                notification: bar.incoming
                                levelShown: bar.levelVisible && !bar.displayPanelOpen
                                levelKind: Ui.islandOsdKind
                                glance: bar.displayMode === "glance"
                            }
                        }
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.rightMargin: 4
                        y: detailViewport.y + detailViewport.visibleArea.yPosition * detailViewport.height
                        width: 3
                        height: Math.max(18, detailViewport.visibleArea.heightRatio * detailViewport.height)
                        radius: 2
                        color: Theme.alpha(Theme.color.outline, 0.5)
                        visible: detailViewport.visible && detailViewport.contentHeight > detailViewport.height
                    }
                } // contentCanvas: стабильная геометрия во время морфинга
            }
        } // inputArea: общий предок островка и всех его элементов

        // Неподвижная область центрального маркера не зависит от угла,
        // в который перемещена раскрывающаяся поверхность.
        Item {
            id: centralHit
            x: (bar.width - width) / 2
            y: 0
            width: bar.markerWidth
            height: Lock.locked ? 0 : bar.markerHeight + 6
            z: 4
            HoverHandler {
                id: centralHover
                enabled: !Lock.locked
                onHoveredChanged: {
                    if (hovered && !bar.toastMode && (!bar.revealed || bar.closing)) {
                        bar.suppressHover = false;
                        Ui.islandOrigin = "center";
                        bar.surfaceOrigin = "center";
                        if (bar.closing || collapseDelay.running) {
                            bar.hoverReady = true;
                            collapseDelay.stop();
                        } else hoverDelay.restart();
                    } else if (!hovered) {
                        if (bar.expanded && !bar.pointerInside && !bar.suppressHover)
                            collapseDelay.restart();
                        bar.suppressHover = false;
                    }
                }
            }
            MouseArea {
                anchors.fill: parent
                enabled: !Lock.locked && !bar.panelOpen && (bar.closing || bar.revealAmount < 0.85)
                cursorShape: Qt.PointingHandCursor
                onClicked: bar.openFromMarker()
            }
        }

        Loader {
            id: leftMarker
            readonly property bool hovered: visible && opacity > 0.05 && (item?.hovered ?? false)
            x: 0
            width: Settings.bar.islandHint ? Math.min(bar.markerWidth, Math.max(0, (bar.width - bar.markerWidth) / 2 - 48)) : 0
            height: opacity > 0 ? bar.markerHeight + 4 : 0
            opacity: Settings.bar.islandHint && !Lock.locked && width >= 84 ? Math.max(0, 1 - bar.revealAmount * 3) : 0
            visible: opacity > 0
            source: "IslandEdgeMarker.qml"
            onLoaded: {
                item.label = "Обзор";
                item.attachLeft = true;
                item.species = "rabbit";
                item.curve = Qt.binding(() => Math.min(bar.markerCurve, leftMarker.width / 4));
                item.presence = Qt.binding(() => bar.markerPresence);
                item.surfaceHeight = Qt.binding(() => bar.markerHeight);
                item.duration = Qt.binding(() => bar.motion.fast);
                item.triggered.connect(() => bar.openSection("dashboard"));
            }
        }
        Loader {
            id: rightMarker
            readonly property bool hovered: visible && opacity > 0.05 && (item?.hovered ?? false)
            x: bar.width - width
            width: leftMarker.width
            height: leftMarker.height
            opacity: leftMarker.opacity
            visible: opacity > 0
            source: "IslandEdgeMarker.qml"
            onLoaded: {
                item.label = "Управление";
                item.attachLeft = false;
                item.species = "dog";
                item.curve = Qt.binding(() => Math.min(bar.markerCurve, rightMarker.width / 4));
                item.presence = Qt.binding(() => bar.markerPresence);
                item.surfaceHeight = Qt.binding(() => bar.markerHeight);
                item.duration = Qt.binding(() => bar.motion.fast);
                item.triggered.connect(() => bar.openSection("control"));
            }
        }

        Component {
            id: dashboardContent
            DashboardContent {}
        }
        Component {
            id: notificationContent
            NotificationHistory {
                maximumHeight: bar.maximumBodyHeight
            }
        }

        Component {
            id: privacyContent
            PrivacyDetails {}
        }
        Component { id: timerContent; TimerPanel {} }
        Connections {
            target: Ui
            function onIslandDismissRequested() { bar.closePanel(); }
        }
        Component {
            id: controlContent
            ControlContent {
                page: bar.displayMode.startsWith("control:") ? bar.displayMode.slice(8) : "main"
                maxListHeight: Math.max(100, bar.maximumBodyHeight - 56)
            }
        }

        // «Не засыпать» (services/Caffeine.qml): пока включено, простоя нет.
        IdleInhibitor {
            window: bar
            enabled: Caffeine.active
        }

        Component {
            id: workspacesComponent

            Workspaces {
                output: bar.modelData.name
            }
        }

        Component {
            id: windowTitleComponent

            WindowTitle {
                width: Math.min(180, implicitWidth)
            }
        }

        Component {
            id: trayComponent

            Tray {}
        }

        Component {
            id: keyboardComponent

            KeyboardLayout {}
        }

        Component {
            id: statusComponent

            StatusIcons {}
        }

        Component {
            id: notificationsComponent

            NotificationButton {}
        }

        Component {
            id: mediaComponent

            MediaWidget {}
        }

        Component {
            id: networkComponent

            NetworkWidget {}
        }

        Component {
            id: noteComponent

            NoteWidget {}
        }

        Component {
            id: dateComponent

            DateWidget {}
        }

        Component {
            id: weatherComponent

            WeatherWidget {}
        }

        Component {
            id: sysmonComponent

            SystemMonitor {}
        }

        Component {
            id: clockComponent

            Clock {}
        }
    }

    // Каждый виджет — отдельный блок с собственной поверхностью.
    // Скрытые виджеты не оставляют пустых капсул и промежутков.
    component Zone: RowLayout {
        id: zone

        property var ids: []
        readonly property int count: repeater.count
        Layout.alignment: Qt.AlignVCenter
        visible: count > 0
        spacing: 5

        Repeater {
            id: repeater
            model: zone.ids.filter(id => bar.widgets[id] !== undefined && bar.ownerOf(id) === zone && bar.showWidget(id))

            Rectangle {
                id: block
                required property string modelData
                readonly property bool accent: modelData === "clock" || modelData === "workspaces"
                readonly property bool hasContent: widget.item !== null

                visible: hasContent
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: hasContent ? (modelData === "windowTitle" ? Math.min(180, widget.item.implicitWidth) : widget.item.implicitWidth) + 16 : 0
                implicitHeight: Math.max(28, Settings.panelHeight - 28)
                radius: implicitHeight / 2
                color: blockHover.hovered ? Theme.color.hover : accent ? Theme.alpha(Theme.color.primary, 0.12) : Theme.alpha(Theme.color.text, 0.045)
                border.width: Theme.borders ? 1 : 0
                border.color: accent ? Theme.alpha(Theme.color.primary, 0.16) : Theme.alpha(Theme.color.outline, 0.08)
                Behavior on color {
                    ColorAnimation {
                        duration: bar.motion.fast
                    }
                }

                HoverHandler {
                    id: blockHover
                }
                Loader {
                    id: widget
                    anchors.centerIn: parent
                    sourceComponent: bar.widgets[block.modelData]
                }
            }
        }
    }
}
