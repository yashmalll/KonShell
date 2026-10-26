import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.services

// Док внизу каждого монитора: закреплённые и запущенные приложения.
//   Левый клик — запустить, перейти к окну или к следующему окну приложения;
//   средний — новое окно; правый — меню (окна, закрепить, закрыть); колесо — окна по очереди.
// При dock.autoHide док прячется и выезжает, когда мышь у нижнего края экрана;
// на пустом рабочем столе он виден всегда. Без автоскрытия окна niri не заходят под него.
// Стиль (dock.style): attached — прижат к нижнему краю, нижние углы плавно (вогнуто)
// переходят в край экрана; floating — плавающая панель со скруглёнными углами.
//   qs -c konshell ipc call dock toggle | pin <id> | unpin <id>
Scope {
    id: root

    // Показать док по IPC на время, даже при автоскрытии.
    property bool forced: false

    IpcHandler {
        target: "dock"

        function toggle(): void {
            root.forced = !root.forced;
        }
        function pin(id: string): void {
            DockApps.pin(id);
        }
        function unpin(id: string): void {
            DockApps.unpin(id);
        }
    }

    Variants {
        model: Settings.dock.enabled ? Quickshell.screens : []

        PanelWindow {
            id: dock

            required property ShellScreen modelData

            readonly property int iconSize: Math.max(24, Math.min(72, Settings.dock.iconSize))
            readonly property int padding: Theme.spacing.sm
            readonly property bool attached: Settings.dock.style !== "floating"
            readonly property int edgeMargin: attached ? 0 : Theme.spacing.sm
            readonly property int cornerRadius: Math.min(Theme.radius.panel + 4, Math.floor(panelHeight / 2))
            // Вогнутые закругления по бокам прижатого дока — переход в край экрана.
            readonly property int fillet: attached ? Math.max(cornerRadius, 8) : 0
            readonly property int panelHeight: iconSize + padding * 2 + 6
            // Над доком — место под подсказку с названием и увеличенный значок.
            readonly property int headroom: Theme.font.body + Theme.spacing.lg * 2 + 8

            readonly property bool autoHide: Settings.dock.autoHide
            readonly property var activeWorkspace: Niri.workspaces.find(ws => ws.output === modelData.name && ws.is_active) ?? null
            readonly property bool workspaceEmpty: activeWorkspace !== null && Niri.windowsOn(activeWorkspace.id).length === 0
            property bool hovered: false
            property int menusOpen: 0
            readonly property bool revealed: !autoHide || root.forced || hovered || menusOpen > 0 || workspaceEmpty

            screen: modelData
            WlrLayershell.namespace: "konshell-dock"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            anchors {
                bottom: true
                left: true
                right: true
            }
            implicitHeight: panelHeight + edgeMargin + headroom
            // Без автоскрытия окна niri заканчиваются над доком.
            exclusionMode: autoHide ? ExclusionMode.Ignore : ExclusionMode.Normal
            exclusiveZone: autoHide ? 0 : panelHeight + edgeMargin
            color: "transparent"

            // Ввод — только в доке (или в полоске у края, пока он спрятан): прозрачная
            // часть окна клики не перехватывает.
            mask: Region {
                item: dock.revealed ? inputArea : trigger
            }

            // Размытие повторяет форму панели: у прижатой — прямые нижние углы и
            // вогнутые закругления по бокам (квадрат минус круг).
            BackgroundEffect.blurRegion: Region {
                item: panel
                topLeftRadius: dock.cornerRadius
                topRightRadius: dock.cornerRadius
                bottomLeftRadius: dock.attached ? 0 : dock.cornerRadius
                bottomRightRadius: dock.attached ? 0 : dock.cornerRadius

                Region {
                    x: panel.x - dock.fillet
                    y: panel.y + panel.height - dock.fillet
                    width: dock.fillet
                    height: dock.fillet
                }
                Region {
                    x: panel.x + panel.width
                    y: panel.y + panel.height - dock.fillet
                    width: dock.fillet
                    height: dock.fillet
                }
                Region {
                    shape: RegionShape.Ellipse
                    intersection: Intersection.Subtract
                    x: panel.x - dock.fillet * 2
                    y: panel.y + panel.height - dock.fillet * 2
                    width: dock.fillet * 2
                    height: dock.fillet * 2
                }
                Region {
                    shape: RegionShape.Ellipse
                    intersection: Intersection.Subtract
                    x: panel.x + panel.width
                    y: panel.y + panel.height - dock.fillet * 2
                    width: dock.fillet * 2
                    height: dock.fillet * 2
                }
            }

            // Место панели, когда она выдвинута.
            readonly property real shownY: height - edgeMargin - panelHeight

            // Ввод: место панели и полоса под ней до края экрана — по пути от края
            // к доку мышь не выходит из него, и он не начинает прятаться.
            Item {
                id: inputArea

                x: panel.x - dock.fillet
                y: dock.shownY
                width: panel.width + dock.fillet * 2
                height: dock.panelHeight + dock.edgeMargin
            }

            // Полоска у нижнего края: наведение на неё выдвигает спрятанный док.
            Item {
                id: trigger

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 2
            }

            // Наведение на любую часть окна, куда пропускает маска.
            Item {
                anchors.fill: parent

                HoverHandler {
                    onHoveredChanged: {
                        if (hovered) {
                            hideTimer.stop();
                            dock.hovered = true;
                        } else {
                            hideTimer.restart();
                        }
                    }
                }
            }

            Timer {
                id: hideTimer

                interval: 400
                onTriggered: dock.hovered = false
            }

            Item {
                id: panel

                // Выезжает изменением y, а не Translate: размытие под панелью
                // (BackgroundEffect.blurRegion) следит за её геометрией и едет вместе
                // с ней. Сдвиг Translate размытие не видит — оно появлялось бы сразу
                // на конечном месте, раньше значков. Спрятанная панель — целиком ниже
                // окна, и вместе с ней за краем и область размытия.
                anchors.horizontalCenter: parent.horizontalCenter
                y: dock.revealed ? dock.shownY : dock.height
                width: row.implicitWidth + dock.padding * 2
                height: dock.panelHeight
                visible: DockApps.items.length > 0

                // Плавающий док.
                Rectangle {
                    anchors.fill: parent
                    visible: !dock.attached
                    radius: dock.cornerRadius
                    color: Theme.color.panel
                    border.width: Theme.borders ? 1 : 0
                    border.color: Theme.color.border
                }

                // Прижатый к краю: скруглённый верх, по бокам вогнутые закругления
                // в край экрана. Рамка — без нижней стороны (она на краю экрана).
                Shape {
                    id: attachedShape

                    readonly property real f: dock.fillet
                    readonly property real r: dock.cornerRadius
                    readonly property real w: width
                    readonly property real h: height

                    x: -f
                    width: parent.width + f * 2
                    height: parent.height
                    visible: dock.attached
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        fillColor: Theme.color.panel
                        strokeColor: Theme.borders ? Theme.color.border : "transparent"
                        strokeWidth: 1

                        startX: 0
                        startY: attachedShape.h
                        PathArc {
                            x: attachedShape.f
                            y: attachedShape.h - attachedShape.f
                            radiusX: attachedShape.f
                            radiusY: attachedShape.f
                            direction: PathArc.Counterclockwise
                        }
                        PathLine { x: attachedShape.f; y: attachedShape.r }
                        PathArc {
                            x: attachedShape.f + attachedShape.r
                            y: 0
                            radiusX: attachedShape.r
                            radiusY: attachedShape.r
                        }
                        PathLine { x: attachedShape.w - attachedShape.f - attachedShape.r; y: 0 }
                        PathArc {
                            x: attachedShape.w - attachedShape.f
                            y: attachedShape.r
                            radiusX: attachedShape.r
                            radiusY: attachedShape.r
                        }
                        PathLine { x: attachedShape.w - attachedShape.f; y: attachedShape.h - attachedShape.f }
                        PathArc {
                            x: attachedShape.w
                            y: attachedShape.h
                            radiusX: attachedShape.f
                            radiusY: attachedShape.f
                            direction: PathArc.Counterclockwise
                        }
                    }
                }

                Behavior on y {
                    NumberAnimation {
                        duration: Theme.anim.slow
                        easing.type: dock.revealed ? Easing.OutBack : Theme.anim.exit
                        easing.overshoot: 0.8
                    }
                }
                Behavior on width {
                    NumberAnimation { duration: Theme.anim.normal; easing.type: Theme.anim.enter }
                }

                Row {
                    id: row

                    anchors.left: parent.left
                    anchors.leftMargin: dock.padding
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacing.xs

                    Repeater {
                        // objectProp: значок с тем же key остаётся тем же делегатом —
                        // меню и анимации не сбрасываются при каждом событии niri.
                        model: ScriptModel {
                            values: DockApps.items
                            objectProp: "key"
                        }

                        Row {
                            id: slot

                            required property var modelData
                            required property int index

                            spacing: row.spacing

                            // Разделитель между закреплёнными и остальными.
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 1
                                height: dock.iconSize * 0.6
                                color: Theme.color.border
                                visible: slot.index > 0 && !slot.modelData.pinned && DockApps.items[slot.index - 1].pinned
                            }

                            DockItem {
                                item: slot.modelData
                                iconSize: dock.iconSize
                                onMenuOpenChanged: dock.menusOpen += menuOpen ? 1 : -1
                            }
                        }
                    }
                }
            }
        }
    }
}
