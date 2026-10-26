#!/usr/bin/env node
// Проверка палитры вне Quickshell.
//
//   node tools/check-palette.js <картинка | #цвет> [схема] [контраст]
//       прогоняет matugen и сборку токенов из config/color.js, печатает
//       исправления контраста и нарушения WCAG для тёмного и светлого режима;
//   node tools/check-palette.js --file [путь к palette.json]
//       проверяет уже записанную палитру (по умолчанию ~/.local/state/konshell/palette.json);
//   node tools/check-palette.js --fallback <#цвет>
//       печатает JSON резервной палитры для вставки в config/fallback-palette.js.
//
// Код возврата 1, если есть нарушения контраста.

const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");

// color.js написан как QML-библиотека: убираем строку .pragma и выполняем.
const source = fs.readFileSync(path.join(__dirname, "../config/color.js"), "utf8").replace(/^\.pragma library\s*$/m, "");
const Color = new Function(source + "\nreturn { buildTokens, rolesFromMatugen, audit, contrast };")();

function matugen(input, scheme, contrast) {
    const common = ["--dry-run", "-j", "hex", "-t", `scheme-${scheme}`, `--contrast=${contrast}`];
    const args = input.startsWith("#")
        ? ["color", "hex", input, ...common]
        : ["image", input, ...common, "--source-color-index", "0"];
    return JSON.parse(execFileSync("matugen", args, { stdio: ["ignore", "pipe", "pipe"] }).toString());
}

function report(name, tokens, adjusted) {
    const failures = Color.audit(tokens);
    console.log(`\n== ${name}`);
    for (const pair of [["text", "background"], ["textMuted", "background"], ["textMuted", "surface"],
                        ["textMuted", "surfaceVariant"], ["textMuted", "popup"], ["primaryText", "primary"]])
        console.log(`  ${(pair[0] + " / " + pair[1]).padEnd(28)} ${Color.contrast(tokens[pair[0]], tokens[pair[1]]).toFixed(2)}`);
    for (const line of adjusted || [])
        console.log(`  исправлено: ${line}`);
    for (const line of failures)
        console.log(`  НАРУШЕНИЕ: ${line}`);
    if (!failures.length)
        console.log("  все правила контраста выполнены");
    return failures.length;
}

const args = process.argv.slice(2);
let failures = 0;

if (args[0] === "--file") {
    const file = args[1] || path.join(process.env.HOME, ".local/state/konshell/palette.json");
    const palette = JSON.parse(fs.readFileSync(file, "utf8"));
    console.log("источник:", JSON.stringify(palette.source));
    for (const mode of ["dark", "light"])
        failures += report(mode, palette[mode]);
} else if (args[0] === "--fallback") {
    const roles = Color.rolesFromMatugen(matugen(args[1] || "#6b7fd7", "tonal-spot", 0));
    const out = {};
    for (const mode of ["dark", "light"]) {
        const built = Color.buildTokens(roles[mode], mode);
        failures += Color.audit(built.tokens).length;
        out[mode] = built.tokens;
    }
    console.log(JSON.stringify(out, null, 4));
} else if (args[0]) {
    const roles = Color.rolesFromMatugen(matugen(args[0], args[1] || "tonal-spot", args[2] || 0));
    for (const mode of ["dark", "light"]) {
        const built = Color.buildTokens(roles[mode], mode);
        failures += report(mode, built.tokens, built.adjusted);
    }
} else {
    console.log("Использование: см. комментарий в начале файла.");
    process.exit(2);
}

process.exit(failures ? 1 : 0);
