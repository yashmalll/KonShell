import QtQuick
import QtQuick.Shapes
import qs.config
import qs.services
import qs.widgets

Item {
    id: edge
    property string label
    property bool attachLeft: true
    property string species: "rabbit"
    property real curve: 32
    property real presence: 1
    property real surfaceHeight: 14
    property int duration: 180
    readonly property bool hovered: area.containsMouse
    signal triggered
    enabled: visible && !Lock.locked
    Accessible.role: Accessible.Button
    Accessible.name: "Открыть «" + label + "»"
    Shape {
        id: edgeShape
        width: edge.width
        height: edge.surfaceHeight
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer
        transform: Scale {
            origin.x: edgeShape.width / 2
            xScale: edge.attachLeft ? 1 : -1
        }
        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillColor: Theme.color.background
            startX: 0
            startY: 0
            PathLine {
                x: 0
                y: edge.surfaceHeight
            }
            PathLine {
                x: edgeShape.width - edge.curve
                y: edge.surfaceHeight
            }
            PathCubic {
                x: edgeShape.width
                y: 0
                control1X: edgeShape.width - edge.curve / 2
                control1Y: edge.surfaceHeight
                control2X: edgeShape.width - edge.curve / 2
                control2Y: 0
            }
            PathLine {
                x: 0
                y: 0
            }
        }
    }
    Canvas {
        id: scenery
        width: edge.width
        height: edge.surfaceHeight
        opacity: edge.presence
        antialiasing: false
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            const base = Math.floor(height - 2);
            const kind = pet.objectKind;
            const carrying = pet.mood === "fetch" || pet.mood === "return";
            const x = Math.round(pet.objectX + (pet.mood === "play" ? Math.sin(pet.frame * 0.7) * 6 : 0));
            if (kind === "carrot") {
                ctx.fillStyle = "#e5a16a";
                ctx.fillRect(x, base - 3, pet.mood === "eat" ? 4 - pet.frame % 3 : 5, 2);
                ctx.fillRect(x + 1, base - 1, 2, 1);
                ctx.fillStyle = "#98ba83";
                ctx.fillRect(x + 4, base - 5, 1, 3);
                ctx.fillRect(x + 5, base - 4, 2, 1);
            } else if (kind === "bone") {
                ctx.fillStyle = "#e2d7bd";
                ctx.fillRect(x + 1, base - 2, 5, 1);
                ctx.fillRect(x, base - 3, 2, 3);
                ctx.fillRect(x + 5, base - 3, 2, 3);
            } else if (kind === "ball" || (kind === "stick" && !carrying)) {
                ctx.fillStyle = kind === "ball" ? "#c393b0" : "#ac886a";
                if (kind === "ball") {
                    ctx.fillRect(x + 1, base - 4, 3, 4);
                    ctx.fillRect(x, base - 3, 5, 2);
                    ctx.fillStyle = "#ead6e1";
                    ctx.fillRect(x + 1 + pet.frame % 2, base - 3, 1, 1);
                } else {
                    ctx.fillRect(x, base - 2, 8, 1);
                    ctx.fillRect(x + 5, base - 3, 1, 2);
                }
            } else if (kind === "bowl") {
                ctx.fillStyle = "#93afbc";
                ctx.fillRect(x, base - 2, 9, 1);
                ctx.fillRect(x + 1, base - 1, 7, 2);
                ctx.fillStyle = "#c3dbe6";
                ctx.fillRect(x + 2 + pet.frame % 2, base - 2, 3, 1);
            } else if (kind === "bed") {
                ctx.fillStyle = "#a28d9f";
                ctx.fillRect(x - 8, base, 22, 2);
                ctx.fillStyle = "#c2afbd";
                ctx.fillRect(x - 7, base - 1, 5, 1);
            }
            if (pet.mood === "sleep") {
                const zx = Math.round(pet.x + 17), zy = 2 + pet.frame % 3;
                ctx.fillStyle = "#aaa6b6";
                ctx.fillRect(zx, zy, 3, 1);
                ctx.fillRect(zx + 1, zy + 1, 1, 1);
                ctx.fillRect(zx, zy + 2, 3, 1);
            } else if (pet.mood === "proud") {
                ctx.fillStyle = "#dca7b5";
                const hx = Math.round(pet.x + 18), hy = 3 - pet.frame % 2;
                ctx.fillRect(hx, hy, 1, 1);
                ctx.fillRect(hx + 2, hy, 1, 1);
                ctx.fillRect(hx, hy + 1, 3, 1);
                ctx.fillRect(hx + 1, hy + 2, 1, 1);
            } else if (pet.mood === "dig") {
                ctx.fillStyle = "#a28b73";
                for (let n = 0; n < 3; n++)
                    ctx.fillRect(Math.round(pet.x + 14 + n * 2), base - (pet.frame + n) % 3, 1, 1);
            }
        }
    }
    Canvas {
        id: pet
        width: 16
        height: 12
        x: (edge.width - width) / 2
        y: Math.max(0, (edge.surfaceHeight - height) / 2 + ((mood === "hop" || mood === "play") ? (frame % 3 === 0 ? -1 : 1) : 0))
        opacity: edge.presence
        antialiasing: false
        property bool facingLeft: false
        transform: Scale {
            origin.x: pet.width / 2
            xScale: pet.facingLeft ? -1 : 1
            Behavior on xScale {
                NumberAnimation {
                    duration: Settings.theme.reduceMotion ? 0 : 220
                    easing.type: Easing.InOutSine
                }
            }
        }
        property int frame: Math.floor(Math.random() * 19)
        property string mood: "rest"
        property string objectKind: ""
        property real objectX: 0
        property string task: ""
        property real homeX: 0
        function wait(milliseconds) {
            actionTimer.interval = Math.round(milliseconds);
            actionTimer.restart();
        }
        function moveTo(destination) {
            facingLeft = destination < x;
            walkMotion.to = destination;
            walkMotion.duration = Math.max(1600, Math.abs(destination - x) * (edge.species === "rabbit" ? 75 : 110));
            walkMotion.start();
        }
        function nextAction() {
            walkMotion.stop();
            if (!animated)
                return;
            const choices = edge.species === "rabbit" ? ["walk", "hop", "eat", "play", "wash", "ears", "dig", "stretch", "sleep"] : ["walk", "wag", "sniff", "sit", "stretch", "eat", "drink", "play", "fetch", "sleep"];
            const available = choices.filter(value => value !== task);
            task = available[Math.floor(Math.random() * available.length)];
            objectKind = task === "eat" ? (edge.species === "rabbit" ? "carrot" : "bone") : task === "play" ? "ball" : task === "drink" ? "bowl" : task === "fetch" ? "stick" : task === "sleep" ? "bed" : "";
            const left = edge.curve + 12, right = Math.max(left, edge.width - edge.curve - 28);
            homeX = Math.max(left, Math.min(right, x));
            if (objectKind) {
                objectX = left + 22 + Math.random() * Math.max(0, right - left - 44);
                const target = Math.max(left, Math.min(right, objectX > x + 8 ? objectX - 16 : objectX + 8));
                mood = "approach";
                moveTo(target);
                wait(walkMotion.duration + 15000);
            } else {
                mood = task;
                if (mood === "walk" || mood === "hop") {
                    moveTo(left + Math.random() * (right - left));
                    wait(walkMotion.duration + 1000 + Math.random() * 2000);
                } else
                    wait(3500 + Math.random() * (mood === "sleep" ? 8000 : 5000));
            }
            requestPaint();
            scenery.requestPaint();
        }
        function arrived() {
            if (mood === "approach") {
                mood = task;
                wait(task === "fetch" ? 1600 : 4500 + Math.random() * 4500);
            } else if (mood === "return") {
                mood = "proud";
                objectKind = "";
                wait(2200);
            }
        }
        function advanceAction() {
            if (mood === "fetch") {
                mood = "return";
                moveTo(homeX);
                wait(walkMotion.duration + 4000);
            } else
                nextAction();
        }
        onAnimatedChanged: {
            if (animated)
                nextAction();
            else {
                walkMotion.stop();
                actionTimer.stop();
            }
        }
        onMoodChanged: {
            requestPaint();
            scenery.requestPaint();
        }
        onXChanged: if (mood === "sleep" || mood === "proud" || mood === "dig")
            scenery.requestPaint()
        readonly property bool animated: edge.visible && edge.presence > 0.95 && !Settings.theme.reduceMotion
        readonly property var dog: ["...bb.dddd......", "...bbdddddk.....", "...bddddddnn....", "....ddddddnn....", ".....dddddd.....", ".d...dddddd.....", ".dddddddddd.....", "..ddddwwwddd....", "...dddwwwdd.....", "...ddd..ddd.....", "...dd....dd.....", "..ddd...ddd....."]
        readonly property var rabbit: ["...ww..ww.......", "...wp..pw.......", "...wp..pw.......", "...wwwwww.......", "..wwwkwwkww.....", "..wwwwpwwww.....", "...wwwwwww......", "....wwwwww...w..", "...wwwwwwwwwww..", "...wwwwwwwww....", "...www..www.....", "..wwww..wwww...."]
        onFrameChanged: {
            requestPaint();
            scenery.requestPaint();
        }
        onFacingLeftChanged: requestPaint()
        Component.onCompleted: {
            requestPaint();
            Qt.callLater(nextAction);
        }
        Connections {
            target: edge
            function onSpeciesChanged() {
                pet.nextAction();
            }
        }
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            const rows = edge.species === "rabbit" ? rabbit : dog;
            const fur = edge.species === "rabbit" ? "#eee8e1" : "#cda57d";
            const blink = mood === "sleep" || (mood === "sniff" && frame % 3 === 0) || frame % 19 === 17;
            for (let row = 0; row < rows.length; row++) {
                for (let col = 0; col < rows[row].length; col++) {
                    const cell = rows[row][col];
                    if (cell === ".")
                        continue;
                    if (mood === "sleep" && row < (edge.species === "rabbit" ? 3 : 1))
                        continue;
                    ctx.fillStyle = cell === "k" ? (blink ? fur : "#26232b") : cell === "n" ? "#342c2c" : cell === "b" ? "#8f6650" : cell === "p" ? "#d795a8" : cell === "w" && edge.species === "dog" ? "#ead8c3" : fur;
                    let step = row >= 10 && (["walk", "hop", "approach", "return", "dig"].includes(mood)) && frame % 2 ? (col < 7 ? 1 : -1) : 0;
                    if (mood === "stretch" && row >= 8)
                        step += col < 7 ? -1 : 1;
                    if (edge.species === "dog" && row === 6 && col >= 7 && col <= 9)
                        ctx.fillStyle = "#8da8a4";
                    const px = col + step;
                    const py = (mood === "sleep" || mood === "sit") && row >= 7 ? Math.min(11, row + 1) : mood === "sniff" && row <= 5 ? row + frame % 2 : row;
                    ctx.fillRect(px, py, 1, 1);
                }
            }
            if (mood === "eat" || mood === "drink") {
                ctx.fillStyle = "#d795a8";
                ctx.fillRect(11, 6 + frame % 2, 2, 1);
                ctx.fillStyle = fur;
                ctx.fillRect(9, 8 - frame % 2, 2, 1);
            }
            if (mood === "wag") {
                ctx.fillStyle = fur;
                const tailX = 1;
                ctx.clearRect(tailX, 4, 2, 3);
                ctx.fillRect(tailX, 4 + frame % 3, 2, 1);
                ctx.fillRect(3, 6, 1, 1);
            }
            if (mood === "wash") {
                ctx.fillStyle = fur;
                ctx.fillRect(7, 4 + frame % 3, 2, 2);
            }
            if (mood === "ears") {
                ctx.clearRect(7, 0, 3, 3);
                ctx.fillStyle = fur;
                ctx.fillRect(7 + frame % 2, 1, 2, 3);
                ctx.fillStyle = "#d795a8";
                ctx.fillRect(7 + frame % 2, 2, 1, 1);
            }
            if (mood === "fetch" || mood === "return") {
                ctx.fillStyle = "#ac886a";
                ctx.fillRect(9, 6, 7, 1);
                ctx.fillRect(13, 5, 1, 2);
            }
        }
        Timer {
            interval: edge.species === "rabbit" ? 180 : 240
            repeat: true
            running: pet.animated
            onTriggered: pet.frame++
        }
        Timer {
            id: actionTimer
            onTriggered: pet.advanceAction()
        }
        NumberAnimation {
            id: walkMotion
            target: pet
            property: "x"
            easing.type: Easing.InOutSine
            onFinished: pet.arrived()
        }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: edge.triggered()
    }
    Timer {
        interval: edge.duration
        running: edge.hovered
        onTriggered: edge.triggered()
    }
}
