#!/bin/sh
# Подключает цвета KonShell к приложениям. Сами файлы цветов пишет оболочка в
# user/colors/ (services/ThemeExport.qml); здесь — только подключение:
#   kitty     include <user>/colors/kitty.conf          в конце kitty.conf
#   GTK 3/4   @import url("file://<user>/colors/gtk*.css") в начале gtk.css
#   Qt        color_scheme_path = <user>/colors/qt6ct.conf  в qt6ct.conf
#   Zed       ссылка themes/konshell.json → <user>/colors/zed.json, темы KonShell в settings.json
#   Firefox   ссылка ~/.cache/wal/colors.json → <user>/colors/pywalfox.json (для Pywalfox)
#   niri      цвета подключает user/niri.kdl (install.sh)
#
#   install-theme-hooks.sh               подключить
#   install-theme-hooks.sh --uninstall   убрать
#
# Повторный запуск ничего не дублирует. Перед первой правкой файла рядом сохраняется
# копия <файл>.konshell-bak. Подключения прежних версий (konshell-colors.* в папках
# программ) убираются в обоих режимах. Вызывается из install.sh.

set -eu
config=${XDG_CONFIG_HOME:-$HOME/.config}
cache=${XDG_CACHE_HOME:-$HOME/.cache}
shell_dir=$(cd "$(dirname "$0")/.." && pwd)
user=${KONSHELL_HOME:-$shell_dir/user}
user=${user%/}
colors="$user/colors"
mode=${1:-install}
marker="KonShell: цвета под обои"

backup() {
    [ -e "$1" ] && [ ! -L "$1" ] && [ ! -e "$1.konshell-bak" ] && cp -p "$1" "$1.konshell-bak"
    return 0
}

# unhook <файл> <строка> — убрать строку подключения и пометку; пустые строки в конце
# обрезаются, а файл, в котором больше ничего не осталось, удаляется.
unhook() {
    file=$1 line=$2
    [ -e "$file" ] && grep -qF -- "$line" "$file" || return 0
    grep -vF -e "$line" -e "$marker" "$file" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' > "$file.tmp" || true
    if [ -s "$file.tmp" ]; then
        mv "$file.tmp" "$file"
    else
        rm -f "$file.tmp" "$file"
    fi
    echo "убрано из $file"
}

# append_hook <файл> <строка> <знак комментария> — в конец (последнее определение побеждает).
append_hook() {
    file=$1 line=$2
    if [ "$mode" = --uninstall ]; then
        unhook "$file" "$line"
        return 0
    fi
    [ -e "$file" ] || { echo "нет $file — пропускаю"; return 0; }
    if grep -qF -- "$line" "$file"; then
        echo "уже подключено: $file"
    else
        backup "$file"
        printf '\n%s %s\n%s\n' "$3" "$marker" "$line" >> "$file"
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
    if [ -e "$file" ] && grep -qF -- "$line" "$file"; then
        echo "уже подключено: $file"
        return 0
    fi
    backup "$file"
    { printf '/* %s */\n%s\n' "$marker" "$line"; [ -e "$file" ] && cat "$file"; } > "$file.tmp"
    mv "$file.tmp" "$file"
    echo "подключено: $file"
}

# link <ссылка> <цель> — ссылка в папке программы на файл из user/colors.
link() {
    if [ "$mode" = --uninstall ]; then
        [ -L "$1" ] && rm -f "$1" && echo "убрана ссылка $1"
        return 0
    fi
    mkdir -p "$(dirname "$1")"
    [ -e "$1" ] && [ ! -L "$1" ] && rm -f "$1"
    ln -sfn "$2" "$1"
    echo "ссылка: $1 → $2"
}

ensure_file() {
    [ "$mode" = --uninstall ] && return 0
    mkdir -p "$(dirname "$1")"
    [ -e "$1" ] || : > "$1"
}

# --- Прежние версии: файлы цветов лежали в папках программ ------------------------
mode_saved=$mode
mode=--uninstall
unhook "$config/kitty/kitty.conf" 'include konshell-colors.conf'
unhook "$config/gtk-3.0/gtk.css" "@import 'konshell-colors.css';"
unhook "$config/gtk-4.0/gtk.css" "@import 'konshell-colors.css';"
mode=$mode_saved
rm -f "$config/kitty/konshell-colors.conf" "$config/gtk-3.0/konshell-colors.css" "$config/gtk-4.0/konshell-colors.css" \
      "$config/qt6ct/colors/KonShell.conf"

# --- Подключение ------------------------------------------------------------------
mkdir -p "$colors"
for f in kitty.conf gtk3.css gtk4.css niri.kdl qt6ct.conf zed.json pywalfox.json; do
    ensure_file "$colors/$f"
done

append_hook "$config/kitty/kitty.conf" "include $colors/kitty.conf" "#"
prepend_hook "$config/gtk-3.0/gtk.css" "@import url(\"file://$colors/gtk3.css\");"
prepend_hook "$config/gtk-4.0/gtk.css" "@import url(\"file://$colors/gtk4.css\");"
[ -d "$config/zed" ] && link "$config/zed/themes/konshell.json" "$colors/zed.json"
link "$cache/wal/colors.json" "$colors/pywalfox.json"

# Zed: выбрать темы KonShell Dark/Light. Меняются только значения "light" и "dark"
# в блоке "theme"; прежние названия — в user/state/, возвращаются при --uninstall.
zed_settings="$config/zed/settings.json"
zed_previous="$user/state/zed-previous-themes.json"
# прежние версии хранили этот файл в папке Zed
[ -e "$config/zed/.konshell-previous-themes" ] && { mkdir -p "$user/state"; mv "$config/zed/.konshell-previous-themes" "$zed_previous"; }
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

# Qt: qt6ct берёт палитру из user/colors/qt6ct.conf; QT_QPA_PLATFORMTHEME=qt6ct задаёт
# user/niri.kdl. Прежние значения qt6ct.conf — в user/state/, возвращаются при --uninstall.
qt_conf="$config/qt6ct/qt6ct.conf"
qt_previous="$user/state/qt6ct-previous.json"
[ -e "$config/qt6ct/.konshell-previous" ] && { mkdir -p "$user/state"; mv "$config/qt6ct/.konshell-previous" "$qt_previous"; }
if command -v python3 >/dev/null 2>&1 && { [ "$mode" != --uninstall ] || [ -e "$qt_previous" ]; }; then
    [ "$mode" != --uninstall ] && { mkdir -p "$config/qt6ct"; backup "$qt_conf"; }
    python3 -I - "$qt_conf" "$qt_previous" "$colors/qt6ct.conf" "$mode" <<'PY'
import configparser, json, os, sys
path, previous_path, scheme, mode = sys.argv[1:5]
ini = configparser.RawConfigParser(strict=False)
ini.optionxform = str
if os.path.exists(path):
    ini.read(path, encoding="utf-8")
if not ini.has_section("Appearance"):
    ini.add_section("Appearance")
app = ini["Appearance"]
wanted = {"custom_palette": "true", "color_scheme_path": scheme}
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
    # Прежние значения — только при первом подключении: смена пути к схеме их не трогает.
    if not os.path.exists(previous_path):
        json.dump({k: app.get(k) for k in wanted}, open(previous_path, "w"))
    for key, value in wanted.items():
        app[key] = value
with open(path, "w", encoding="utf-8") as f:
    ini.write(f, space_around_delimiters=False)
print(("убрано из " if mode == "--uninstall" else "подключено: ") + path)
PY
fi
