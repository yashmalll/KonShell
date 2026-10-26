#!/bin/sh
# Подключает файлы цветов KonShell к приложениям: kitty, GTK 3/4, niri, Zed, Qt (qt6ct).
# Вызывается из install.sh; можно запускать и отдельно.
#
#   install-theme-hooks.sh              добавить строки подключения
#   install-theme-hooks.sh --uninstall  убрать их
#
# Повторный запуск ничего не дублирует. Перед первой правкой файла рядом
# сохраняется копия <файл>.konshell-bak. Сами файлы цветов пишет оболочка
# (services/ThemeExport.qml); здесь, если их ещё нет, создаются пустые —
# иначе niri не загрузил бы конфиг с include на несуществующий файл.

set -eu
config=${XDG_CONFIG_HOME:-$HOME/.config}
mode=${1:-install}
marker="KonShell: цвета под обои"

backup() {
    [ -e "$1" ] && [ ! -e "$1.konshell-bak" ] && cp -p "$1" "$1.konshell-bak"
    return 0
}

# unhook <файл> <строка> — убрать строку подключения и пометку; пустые строки в конце
# обрезаются, а файл, в котором больше ничего не осталось, удаляется.
unhook() {
    file=$1 line=$2
    [ -e "$file" ] && grep -qF "$line" "$file" || return 0
    grep -vF -e "$line" -e "$marker" "$file" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' > "$file.tmp" || true
    if [ -s "$file.tmp" ]; then
        mv "$file.tmp" "$file"
    else
        rm -f "$file.tmp" "$file"
    fi
    echo "убрано из $file"
}

# append_hook <файл> <строка> — дописать в конец (для kitty и niri: последнее определение побеждает).
append_hook() {
    file=$1 line=$2
    if [ "$mode" = --uninstall ]; then
        unhook "$file" "$line"
        return 0
    fi
    [ -e "$file" ] || { echo "нет $file — пропускаю"; return 0; }
    if grep -qF "$line" "$file"; then
        echo "уже подключено: $file"
    else
        backup "$file"
        printf '\n// %s\n%s\n' "$marker" "$line" | sed "s|^// |$3 |" >> "$file"
        echo "подключено: $file"
    fi
}

# prepend_hook <файл> <строка> — для CSS: @import должен стоять в начале файла.
prepend_hook() {
    file=$1 line=$2
    if [ "$mode" = --uninstall ]; then
        unhook "$file" "$line"
        return 0
    fi
    mkdir -p "$(dirname "$file")"
    if [ -e "$file" ] && grep -qF "$line" "$file"; then
        echo "уже подключено: $file"
        return 0
    fi
    backup "$file"
    { printf '/* %s */\n%s\n' "$marker" "$line"; [ -e "$file" ] && cat "$file"; } > "$file.tmp"
    mv "$file.tmp" "$file"
    echo "подключено: $file"
}

ensure_file() {
    [ "$mode" = --uninstall ] && return 0
    mkdir -p "$(dirname "$1")"
    [ -e "$1" ] || : > "$1"
}

ensure_file "$config/niri/konshell-colors.kdl"
ensure_file "$config/kitty/konshell-colors.conf"
ensure_file "$config/gtk-3.0/konshell-colors.css"
ensure_file "$config/gtk-4.0/konshell-colors.css"

append_hook "$config/niri/config.kdl" 'include "konshell-colors.kdl"' "//"
append_hook "$config/kitty/kitty.conf" 'include konshell-colors.conf' "#"
prepend_hook "$config/gtk-3.0/gtk.css" "@import 'konshell-colors.css';"
prepend_hook "$config/gtk-4.0/gtk.css" "@import 'konshell-colors.css';"

# Zed: выбрать темы KonShell Dark/Light (файл темы пишет оболочка). Меняются только
# значения "light" и "dark" в блоке "theme"; прежние названия сохраняются рядом
# и возвращаются при --uninstall. settings.json у Zed — JSON с запятыми в конце, поэтому правка точечная.
zed_settings="$config/zed/settings.json"
zed_previous="$config/zed/.konshell-previous-themes"
if [ -e "$zed_settings" ] && command -v python3 >/dev/null 2>&1; then
    [ "$mode" != --uninstall ] && backup "$zed_settings"
    python3 -I - "$zed_settings" "$zed_previous" "$mode" <<'PY'
import json, os, re, sys
path, previous_path, mode = sys.argv[1:4]
text = open(path, encoding="utf-8").read()
block = re.search(r'"theme"\s*:\s*\{[^{}]*\}', text)
if not block:
    print("в настройках Zed нет блока theme — пропускаю")
    sys.exit(0)
body = block.group(0)
current = {k: m.group(1) for k in ("light", "dark") if (m := re.search(r'"%s"\s*:\s*"([^"]*)"' % k, body))}
if mode == "--uninstall":
    if not os.path.exists(previous_path):
        sys.exit(0)
    wanted = json.load(open(previous_path))
    os.remove(previous_path)
else:
    wanted = {"light": "KonShell Light", "dark": "KonShell Dark"}
    if current == wanted:
        print("уже подключено: " + path)
        sys.exit(0)
    json.dump(current, open(previous_path, "w"))
for key, name in wanted.items():
    body = re.sub(r'("%s"\s*:\s*")[^"]*(")' % key, lambda m: m.group(1) + name + m.group(2), body)
open(path, "w", encoding="utf-8").write(text[:block.start()] + body + text[block.end():])
print(("убрано из " if mode == "--uninstall" else "подключено: ") + path)
PY
fi

# Qt: qt6ct берёт палитру из схемы KonShell.conf (её пишет оболочка), а Qt-приложения
# включают qt6ct переменной QT_QPA_PLATFORMTHEME (environment в niri/konshell.kdl).
# Прежние значения qt6ct.conf сохраняются рядом и возвращаются при --uninstall.
qt_conf="$config/qt6ct/qt6ct.conf"
qt_previous="$config/qt6ct/.konshell-previous"
if command -v python3 >/dev/null 2>&1; then
    if [ "$mode" != --uninstall ]; then
        ensure_file "$config/qt6ct/colors/KonShell.conf"
        backup "$qt_conf"
    fi
    python3 -I - "$qt_conf" "$qt_previous" "$config/qt6ct/colors/KonShell.conf" "$mode" <<'PY'
import configparser, json, os, sys
path, previous_path, scheme, mode = sys.argv[1:5]
if mode == "--uninstall" and not os.path.exists(previous_path):
    sys.exit(0)
ini = configparser.RawConfigParser(strict=False)
ini.optionxform = str
if os.path.exists(path):
    ini.read(path, encoding="utf-8")
if not ini.has_section("Appearance"):
    ini.add_section("Appearance")
app = ini["Appearance"]
wanted = {"custom_palette": "true", "color_scheme_path": scheme}
# Стиль и значки — только если пользователь их не выбирал.
for key, value in (("style", "Fusion"), ("icon_theme", "Adwaita")):
    if key not in app:
        wanted[key] = value
if mode == "--uninstall":
    for key, value in json.load(open(previous_path)).items():
        if value is None:
            app.pop(key, None)
        else:
            app[key] = value
    os.remove(previous_path)
    if len(app) == 0:
        ini.remove_section("Appearance")
else:
    if all(app.get(k) == v for k, v in wanted.items() if k in ("custom_palette", "color_scheme_path")):
        print("уже подключено: " + path)
        sys.exit(0)
    json.dump({k: app.get(k) for k in wanted}, open(previous_path, "w"))
    for key, value in wanted.items():
        app[key] = value
with open(path, "w", encoding="utf-8") as f:
    ini.write(f, space_around_delimiters=False)
print(("убрано из " if mode == "--uninstall" else "подключено: ") + path)
PY

    # Переменную QT_QPA_PLATFORMTHEME для приложений из niri задаёт niri/konshell.kdl.
    # Прежние версии вставляли её в config.kdl с пометкой KonShell — убираем.
    niri_conf="$config/niri/config.kdl"
    [ -e "$niri_conf" ] && python3 -I - "$niri_conf" "$marker" <<'PY'
import re, sys
path, marker = sys.argv[1:3]
text = open(path, encoding="utf-8").read()
new = re.sub(r'^[ \t]*QT_QPA_PLATFORMTHEME "qt6ct"\s*// ' + re.escape(marker) + r'\n', "", text, flags=re.M)
if new != text:
    open(path, "w", encoding="utf-8").write(new)
    print("убрана старая строка QT_QPA_PLATFORMTHEME из " + path)
PY
fi

if [ "$mode" != --uninstall ] && command -v niri >/dev/null 2>&1; then
    niri validate >/dev/null 2>&1 && echo "конфиг niri в порядке" || echo "ВНИМАНИЕ: niri validate сообщает об ошибке" >&2
fi
