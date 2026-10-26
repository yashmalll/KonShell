.pragma library

// Цветовые утилиты темы: OKLab/OKLCH, контраст WCAG и сборка токенов
// из ролей Material You (вывод matugen). Без зависимостей от QML, чтобы
// тот же код можно было проверить в node (tools/check-palette.js).

// Версия сборки токенов: меняется вместе с логикой buildTokens, чтобы палитра,
// собранная старым кодом, не бралась из кэша.
var TOKENS_VERSION = 3;

// ---------- Разбор и запись ----------

// "#rrggbb" или "#aarrggbb" (формат Qt) -> {r, g, b, a} в 0..1.
function parse(hex) {
    let s = String(hex).replace("#", "");
    let a = 1;
    if (s.length === 8) {
        a = parseInt(s.slice(0, 2), 16) / 255;
        s = s.slice(2);
    }
    return {
        r: parseInt(s.slice(0, 2), 16) / 255,
        g: parseInt(s.slice(2, 4), 16) / 255,
        b: parseInt(s.slice(4, 6), 16) / 255,
        a: a
    };
}

function byte(v) {
    return Math.round(Math.max(0, Math.min(1, v)) * 255).toString(16).padStart(2, "0");
}

// Непрозрачный цвет -> "#rrggbb"; с alpha < 1 -> "#aarrggbb" (так его понимает Qt).
function hex(c, alpha) {
    const a = alpha === undefined ? 1 : alpha;
    const rgb = byte(c.r) + byte(c.g) + byte(c.b);
    return a >= 1 ? "#" + rgb : "#" + byte(a) + rgb;
}

function withAlpha(hexColor, alpha) {
    return hex(parse(hexColor), alpha);
}

// ---------- OKLab ----------

function toLinear(v) {
    return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
}

function fromLinear(v) {
    return v <= 0.0031308 ? v * 12.92 : 1.055 * Math.pow(v, 1 / 2.4) - 0.055;
}

function toOklab(hexColor) {
    const c = parse(hexColor);
    const r = toLinear(c.r), g = toLinear(c.g), b = toLinear(c.b);
    const l = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
    const m = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
    const s = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
    return {
        L: 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
        a: 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
        b: 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
    };
}

// null, если цвет вне sRGB.
function fromOklab(L, a, b) {
    const l = Math.pow(L + 0.3963377774 * a + 0.2158037573 * b, 3);
    const m = Math.pow(L - 0.1055613458 * a - 0.0638541728 * b, 3);
    const s = Math.pow(L - 0.0894841775 * a - 1.2914855480 * b, 3);
    const r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s;
    const g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s;
    const bl = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s;
    const eps = 1e-4;
    if ([r, g, bl].some(v => v < -eps || v > 1 + eps))
        return null;
    return { r: fromLinear(Math.max(0, r)), g: fromLinear(Math.max(0, g)), b: fromLinear(Math.max(0, bl)) };
}

function toOklch(hexColor) {
    const o = toOklab(hexColor);
    return { L: o.L, C: Math.hypot(o.a, o.b), h: (Math.atan2(o.b, o.a) * 180 / Math.PI + 360) % 360 };
}

// Цвет из OKLCH; если он вне sRGB, насыщенность уменьшается, а светлота и тон сохраняются.
function fromOklch(L, C, h) {
    const rad = h * Math.PI / 180;
    let lo = 0, hi = C;
    let best = fromOklab(L, 0, 0) || { r: L, g: L, b: L };
    for (let i = 0; i < 24; i++) {
        const c = i === 0 ? C : (lo + hi) / 2;
        const rgb = fromOklab(L, c * Math.cos(rad), c * Math.sin(rad));
        if (rgb) {
            best = rgb;
            if (i === 0)
                break;
            lo = c;
        } else {
            hi = c;
        }
    }
    return hex(best);
}

// Смешивание в OKLab: t = 0 -> a, t = 1 -> b.
function mix(a, b, t) {
    const x = toOklab(a), y = toOklab(b);
    const rgb = fromOklab(x.L + (y.L - x.L) * t, x.a + (y.a - x.a) * t, x.b + (y.b - x.b) * t);
    return rgb ? hex(rgb) : (t < 0.5 ? a : b);
}

// ---------- Контраст WCAG 2.2 ----------

function luminance(hexColor) {
    const c = parse(hexColor);
    return 0.2126 * toLinear(c.r) + 0.7152 * toLinear(c.g) + 0.0722 * toLinear(c.b);
}

function contrast(a, b) {
    const x = luminance(a), y = luminance(b);
    return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05);
}

// Сдвигает светлоту fg (тон и насыщенность сохраняются, насколько позволяет sRGB),
// пока контраст с bg не станет не ниже min. Направление: от фона.
function ensureContrast(fg, bg, min) {
    if (contrast(fg, bg) >= min)
        return fg;
    const lch = toOklch(fg);
    const lighter = luminance(bg) < 0.18;
    const target = lighter ? 1 : 0;
    // Если даже крайняя светлота не помогает, пробуем другое направление.
    if (contrast(fromOklch(target, lch.C, lch.h), bg) < min) {
        const other = fromOklch(1 - target, lch.C, lch.h);
        if (contrast(other, bg) >= min)
            return ensureContrastTowards(lch, bg, min, 1 - target);
        return contrast("#ffffff", bg) > contrast("#000000", bg) ? "#ffffff" : "#000000";
    }
    return ensureContrastTowards(lch, bg, min, target);
}

function ensureContrastTowards(lch, bg, min, target) {
    let near = lch.L, far = target;
    for (let i = 0; i < 24; i++) {
        const mid = (near + far) / 2;
        if (contrast(fromOklch(mid, lch.C, lch.h), bg) >= min)
            far = mid;
        else
            near = mid;
    }
    return fromOklch(far, lch.C, lch.h);
}

// ---------- Сборка токенов ----------

// Поверхности, на которых в оболочке встречается текст.
var SURFACES = ["background", "surface", "surfaceVariant", "popup"];

// Пары «текст или элемент — фон» и минимальный контраст.
// 4.5 — обычный текст, 3 — крупный текст, иконки и границы элементов.
function contrastRules() {
    const rules = [];
    for (const bg of SURFACES) {
        rules.push(["text", bg, 4.5]);
        rules.push(["textMuted", bg, 4.5]);
        for (const accent of ["primary", "secondary", "tertiary", "error", "success", "warning"])
            rules.push([accent, bg, 3]);
    }
    rules.push(["outline", "background", 3]);
    rules.push(["outline", "popup", 3]);
    for (const pair of [["primaryText", "primary"], ["secondaryText", "secondary"], ["tertiaryText", "tertiary"],
                        ["errorText", "error"], ["successText", "success"], ["warningText", "warning"],
                        ["primaryContainerText", "primaryContainer"], ["activeText", "active"]])
        rules.push([pair[0], pair[1], 4.5]);
    return rules;
}

// Сдвигает тон hue к тону toward не больше чем на maxShift градусов,
// чтобы статусные цвета сочетались с палитрой и не теряли смысла.
function harmonizeHue(hue, toward, maxShift) {
    const diff = ((toward - hue + 540) % 360) - 180;
    return (hue + Math.max(-maxShift, Math.min(maxShift, diff * 0.5)) + 360) % 360;
}

// Акцент — исходный цвет обоев (source_color), а не primary схемы Material You:
// схема приглушает насыщенность. Тон и насыщенность сохраняются, светлота
// сдвигается ровно до читаемости на всех поверхностях. Приглушённым обоям
// насыщенность чуть поднимается (до 0.035), чтобы акцент был заметен; у серого
// источника (бесцветные обои) остаётся primary схемы, иначе акцент слился бы с текстом.
// Светлота акцента держится в коридоре (OKLCH L): тёмный режим 0.62–0.88,
// светлый 0.40–0.62 — иначе тёмный акцент в светлой теме сливается с текстом.
function wallpaperAccent(md, t, dark) {
    const source = md.source_color;
    if (!source)
        return null;
    const lch = toOklch(source);
    if (lch.C < 0.012)
        return null;
    const L = dark ? Math.min(0.88, Math.max(0.62, lch.L)) : Math.min(0.62, Math.max(0.40, lch.L));
    let primary = fromOklch(L, Math.max(lch.C, 0.035), lch.h);
    for (const bg of SURFACES)
        primary = ensureContrast(primary, t[bg], 3);
    // Текст на акценте: тёмный оттенок той же гаммы на светлом акценте, светлый — на тёмном.
    const light = luminance(primary) > 0.18;
    const primaryText = ensureContrast(light ? md.on_primary_fixed : md.primary_fixed, primary, 4.5);
    // Мягкая заливка того же тона: акцент, растворённый в фоне.
    const primaryContainer = mix(primary, t.background, dark ? 0.62 : 0.72);
    return {
        primary: primary,
        primaryText: primaryText,
        primaryContainer: primaryContainer,
        primaryContainerText: ensureContrast(md.on_primary_container, primaryContainer, 4.5)
    };
}

// md: роль Material You -> "#rrggbb" для выбранного режима.
// options.accent: "wallpaper" — акцент как на обоях (по умолчанию), "material" — primary схемы.
// options.achromatic: обои без цвета — акцент из схемы (серый с оттенком обоев).
// Возвращает {tokens, adjusted}: adjusted — какие токены пришлось подправить по контрасту.
function buildTokens(md, mode, options) {
    const dark = mode !== "light";
    const accentFromWallpaper = (options?.accent ?? "wallpaper") === "wallpaper" && !options?.achromatic;
    const t = {
        background: md.surface,
        surface: md.surface_container,
        surfaceVariant: md.surface_container_high,
        popup: md.surface_container_low,

        text: md.on_surface,
        textMuted: md.on_surface_variant,

        primary: md.primary,
        primaryText: md.on_primary,
        primaryContainer: md.primary_container,
        primaryContainerText: md.on_primary_container,
        secondary: md.secondary,
        secondaryText: md.on_secondary,
        tertiary: md.tertiary,
        tertiaryText: md.on_tertiary,

        border: md.outline_variant,
        outline: md.outline,

        active: md.secondary_container,
        activeText: md.on_secondary_container,

        error: md.error,
        errorText: md.on_error
    };

    if (accentFromWallpaper) {
        const accent = wallpaperAccent(md, t, dark);
        if (accent)
            Object.assign(t, accent);
    }

    // Успех и предупреждение: фиксированные тона (зелёный, янтарный),
    // слегка подтянутые к основному цвету палитры.
    const primaryHue = toOklch(t.primary).h;
    const statusL = dark ? 0.82 : 0.52;
    t.success = fromOklch(statusL, 0.14, harmonizeHue(150, primaryHue, 12));
    t.warning = fromOklch(dark ? 0.84 : 0.60, 0.15, harmonizeHue(75, primaryHue, 8));
    t.successText = dark ? md.surface : "#ffffff";
    t.warningText = dark ? md.surface : md.on_surface;

    const adjusted = [];
    for (const rule of contrastRules()) {
        const fixed = ensureContrast(t[rule[0]], t[rule[1]], rule[2]);
        if (fixed !== t[rule[0]]) {
            adjusted.push(`${rule[0]} на ${rule[1]}: ${t[rule[0]]} -> ${fixed}`);
            t[rule[0]] = fixed;
        }
    }

    // Состояния: полупрозрачные слои поверх любого фона.
    t.hover = withAlpha(t.text, 0.08);
    t.pressed = withAlpha(t.text, 0.12);
    t.focus = t.primary;
    t.selection = withAlpha(t.primary, 0.35);
    t.textDisabled = withAlpha(t.text, 0.38);
    t.disabled = withAlpha(t.text, 0.12);
    t.shadow = withAlpha(md.shadow || "#000000", dark ? 0.5 : 0.2);
    t.scrim = withAlpha(md.scrim || "#000000", 0.4);

    return { tokens: t, adjusted: adjusted };
}

// 16 цветов терминала (ANSI) под палитру: классические оттенки, слегка подтянутые
// к акценту, с контрастом на фоне терминала 4.5:1 (тёмно-серый «чёрный» и серый
// для комментариев — 3:1). Возвращает {term0 … term15}.
function terminalColors(t, mode) {
    const dark = mode !== "light";
    const bg = t.background;
    const accentHue = toOklch(t.primary).h;
    // Порядок ANSI: красный, зелёный, жёлтый, синий, пурпурный, голубой.
    const hues = [27, 145, 95, 255, 330, 205];
    const out = {};
    hues.forEach((hue, i) => {
        const h = harmonizeHue(hue, accentHue, 10);
        out["term" + (i + 1)] = ensureContrast(fromOklch(dark ? 0.74 : 0.50, 0.13, h), bg, 4.5);
        out["term" + (i + 9)] = ensureContrast(fromOklch(dark ? 0.84 : 0.42, 0.14, h), bg, 4.5);
    });
    if (dark) {
        out.term0 = ensureContrast(t.surfaceVariant, bg, 1.4);
        out.term8 = ensureContrast(mix(t.textMuted, bg, 0.35), bg, 3);
        out.term7 = t.textMuted;
        out.term15 = t.text;
    } else {
        out.term0 = t.text;
        out.term8 = ensureContrast(mix(t.textMuted, bg, 0.2), bg, 3);
        out.term7 = ensureContrast(t.outline, bg, 3);
        out.term15 = ensureContrast(t.textMuted, bg, 4.5);
    }
    return out;
}

// Цвет в записи CSS: "#rrggbb" или "#rrggbbaa" (у Qt альфа впереди: "#aarrggbb").
function cssColor(hexColor, alpha) {
    const c = parse(hexColor);
    const a = alpha === undefined ? c.a : alpha;
    const rgb = byte(c.r) + byte(c.g) + byte(c.b);
    return a >= 1 ? "#" + rgb : "#" + rgb + byte(a);
}

// Значения для шаблонов приложений: токены режима, цвета терминала и производные.
// palette — весь palette.json: тогда в шаблоне доступны и {{dark.…}}, и {{light.…}}
// (нужно приложениям, которые сами переключают светлую и тёмную тему, как Zed).
function templateContext(tokens, mode, palette, extra) {
    const single = (t, m) => Object.assign({}, t, terminalColors(t, m), {
        mode: m,
        // Непрозрачное выделение для программ, которые не умеют альфу (kitty).
        selectionSolid: mix(t.primary, t.background, 0.65)
    });
    const context = single(tokens, mode);
    if (palette) {
        context.dark = single(palette.dark, "dark");
        context.light = single(palette.light, "light");
    }
    return Object.assign(context, extra || {});
}

// Подстановка в шаблон: {{name}}, {{dark.name}}, {{name|strip}} (без #), {{name|alpha:0.5}},
// {{name|json}} — строка в кавычках JSON (для путей), {{name|qt}} или {{name|qt:0.5}} — «#aarrggbb».
// Возвращает {text, missing}: missing — имена, которых нет в контексте.
function renderTemplate(template, context) {
    const missing = [];
    const text = template.replace(/\{\{\s*([a-zA-Z0-9.]+)\s*(?:\|\s*([a-z]+)(?::([0-9.]+))?\s*)?\}\}/g, (match, name, filter, arg) => {
        const value = name.split(".").reduce((obj, key) => obj?.[key], context);
        if (value === undefined) {
            missing.push(name);
            return match;
        }
        if (filter === "json")
            return JSON.stringify(String(value));
        if (typeof value !== "string" || !value.startsWith("#"))
            return String(value);
        if (filter === "strip")
            return cssColor(value).slice(1);
        if (filter === "alpha")
            return cssColor(value, parseFloat(arg));
        // Qt (qt6ct, kdeglobals): «#aarrggbb», альфа впереди; {{x|qt:0.5}} — с прозрачностью.
        if (filter === "qt") {
            const c = parse(value);
            const a = arg === undefined ? c.a : parseFloat(arg);
            return "#" + byte(a) + byte(c.r) + byte(c.g) + byte(c.b);
        }
        return cssColor(value);
    });
    return { text: text, missing: missing };
}

// Вывод matugen (JSON v4) -> {dark: md, light: md} с ролями в виде "#rrggbb".
function rolesFromMatugen(json) {
    const out = { dark: {}, light: {} };
    for (const role in json.colors) {
        out.dark[role] = json.colors[role].dark.color;
        out.light[role] = json.colors[role].light.color;
    }
    return out;
}

// Проверка готовых токенов: список нарушенных правил контраста.
function audit(tokens) {
    const failures = [];
    for (const rule of contrastRules()) {
        const ratio = contrast(tokens[rule[0]], tokens[rule[1]]);
        if (ratio < rule[2] - 0.005)
            failures.push(`${rule[0]} на ${rule[1]}: ${ratio.toFixed(2)} < ${rule[2]}`);
    }
    return failures;
}
