#!/usr/bin/env bash
# Установка KonShell — оболочки рабочего стола для niri на Quickshell (Arch Linux).
#
#   ./install.sh                 установить или обновить подключение
#   ./install.sh --yes           без вопросов (пакеты ставятся сразу)
#   ./install.sh --no-packages   не трогать пакеты
#   ./install.sh --update        git pull + установка новой версией и перезапуск
#   ./install.sh --uninstall     убрать KonShell (настройки остаются в user/)
#   ./install.sh --uninstall --purge   убрать вместе с настройками, PIN и кэшем
#
# Все файлы KonShell — в этой папке: код и user/ (настройки, палитра, PIN, кэш,
# цвета для приложений). В конфигах программ — только строки подключения:
#   1. недостающие пакеты (pacman, после подтверждения);
#   2. niri: user/niri.kdl из шаблона niri/konshell.kdl и строка include с полным
#      путём к нему в конце config.kdl; автозапуск waybar, mako и подобных
#      закомментирован. Копия config.kdl до первой правки — config.kdl.konshell-bak;
#      невалидный конфиг откатывается;
#   3. цвета приложений (scripts/install-theme-hooks.sh): kitty, GTK, Qt, Zed, Firefox;
#   4. команда ~/.local/bin/konshell — то же, что qs -p <эта папка>;
#   5. запуск оболочки, если вы в сеансе niri.
# Повторный запуск ничего не дублирует. --update сначала подтягивает свежую версию
# репозитория (только fast-forward; при локальных правках останавливается), затем
# выполняет установку уже новой версией скрипта.

set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
user=${KONSHELL_HOME:-$repo/user}
user=${user%/}
config=${XDG_CONFIG_HOME:-$HOME/.config}
state=${XDG_STATE_HOME:-$HOME/.local/state}
cache=${XDG_CACHE_HOME:-$HOME/.cache}
data=${XDG_DATA_HOME:-$HOME/.local/share}
bin="$HOME/.local/bin"
niri_dir="$config/niri"
niri_conf="$niri_dir/config.kdl"
include_line="include \"$user/niri.kdl\""
include_comment="// KonShell: автозапуск, клавиши, обои, цвета ($repo)"
marker="// KonShell: отключено —"

yes=0 packages=1 uninstall=0 purge=0 update=0
rest=()
for arg in "$@"; do
    case "$arg" in
        -u|--update) update=1; continue ;;
        -y|--yes) yes=1 ;;
        --no-packages) packages=0 ;;
        --uninstall) uninstall=1 ;;
        --purge) purge=1 ;;
        -h|--help) sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "неизвестный параметр: $arg (см. --help)" >&2; exit 2 ;;
    esac
    rest+=("$arg")
done

bold=$'\e[1m' dim=$'\e[2m' green=$'\e[32m' yellow=$'\e[33m' red=$'\e[31m' reset=$'\e[0m'
[ -t 1 ] || bold= dim= green= yellow= red= reset=
step() { printf '\n%s==>%s %s%s%s\n' "$green" "$reset" "$bold" "$*" "$reset"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '    %s!%s %s\n' "$yellow" "$reset" "$*"; }
die() { printf '%sОшибка:%s %s\n' "$red" "$reset" "$*" >&2; exit 1; }
ask() {
    [ "$yes" -eq 1 ] && return 0
    local answer
    read -r -p "    $1 [Y/n] " answer
    [[ -z "$answer" || "$answer" =~ ^[YyДд] ]]
}

[ "$(id -u)" -ne 0 ] || die "запускайте от своего пользователя, не от root (sudo попросит пароль сам)"

stop_shell() {
    command -v qs >/dev/null 2>&1 || return 0
    qs kill -p "$repo" >/dev/null 2>&1 || true
    qs kill -c konshell >/dev/null 2>&1 || true   # прежние версии: qs -c konshell
}

reload_niri() {
    if [ -n "${NIRI_SOCKET:-}" ] && command -v niri >/dev/null 2>&1; then
        niri msg action load-config-file >/dev/null 2>&1 || true
    fi
}

# ---------------------------------------------------------------- обновление

if [ "$update" -eq 1 ]; then
    [ "$uninstall" -eq 0 ] || die "--update и --uninstall вместе не используются"
    command -v git >/dev/null 2>&1 || die "нет git (sudo pacman -S git)"
    git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
        || die "$repo — не git-репозиторий; обновите вручную (git clone заново)"

    step "Обновление KonShell"
    if [ -n "$(git -C "$repo" status --porcelain --untracked-files=no)" ]; then
        git -C "$repo" status --short --untracked-files=no | sed 's/^/    /'
        die "в репозитории есть несохранённые правки — закоммитьте или уберите их (git stash) и повторите"
    fi
    branch=$(git -C "$repo" symbolic-ref --quiet --short HEAD) \
        || die "репозиторий не на ветке (detached HEAD) — переключитесь: git -C \"$repo\" switch main"
    git -C "$repo" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' >/dev/null 2>&1 \
        || die "у ветки $branch нет upstream — задайте: git -C \"$repo\" branch -u origin/$branch"
    old=$(git -C "$repo" rev-parse HEAD)
    git -C "$repo" pull --ff-only --quiet || die "git pull не удался (ветка разошлась с удалённой?) — разберитесь вручную"
    new=$(git -C "$repo" rev-parse HEAD)
    if [ "$old" = "$new" ]; then
        info "уже последняя версия ($(git -C "$repo" log -1 --format='%h %s'))"
    else
        info "$(git -C "$repo" rev-list --count "$old..$new") новых коммитов:"
        git -C "$repo" log --format='      %h %s' "$old..$new" | head -20
    fi
    # Дальше — установка уже обновлённым скриптом: в нём могли поменяться шаги.
    exec "$repo/install.sh" "${rest[@]}"
fi

# Убрать из config.kdl строки KonShell: свой include и подключения прежних версий
# (konshell.kdl, konshell-colors.kdl, konshell-cursor.kdl) вместе с пометками над ними.
# С restore=1 — ещё и вернуть закомментированный автозапуск.
clean_niri_conf() {
    python3 -I - "$niri_conf" "$marker" "$1" <<'PY'
import re, sys
path, marker, restore = sys.argv[1], sys.argv[2], sys.argv[3] == "1"
lines = open(path, encoding="utf-8").read().split("\n")
ours = re.compile(r'^include "(?:konshell(?:-colors|-cursor)?\.kdl|[^"]*/niri\.kdl)"\s*$')
out = []
for line in lines:
    s = line.strip()
    if ours.match(s) and ("konshell" in s or "/user/niri.kdl" in s):
        # пометка KonShell прямо над include — тоже убрать
        while out and out[-1].strip().startswith("// KonShell:"):
            out.pop()
        continue
    if restore and line.lstrip().startswith(marker):
        indent = line[: len(line) - len(line.lstrip())]
        line = indent + line.lstrip()[len(marker):].lstrip()
    out.append(line)
open(path, "w", encoding="utf-8").write("\n".join(out).rstrip("\n") + "\n")
PY
}

# ---------------------------------------------------------------- удаление

if [ "$uninstall" -eq 1 ]; then
    step "Останавливаю оболочку"
    stop_shell

    step "Отключаю цвета приложений"
    sh "$repo/scripts/install-theme-hooks.sh" --uninstall | sed 's/^/    /' || true

    step "Убираю KonShell из niri"
    if [ -f "$niri_conf" ]; then
        clean_niri_conf 1
        info "строка include убрана, отключённый автозапуск возвращён"
        if command -v niri >/dev/null 2>&1; then
            niri validate -c "$niri_conf" >/dev/null 2>&1 && info "конфиг niri в порядке" \
                || warn "niri validate сообщает об ошибке — сравните с $niri_conf.konshell-bak"
        fi
    fi
    rm -f "$niri_dir/konshell.kdl" "$niri_dir/konshell-colors.kdl" "$niri_dir/konshell-cursor.kdl"
    reload_niri

    step "Убираю команду и пункт меню"
    [ -f "$bin/konshell" ] && grep -q "KonShell" "$bin/konshell" && rm -f "$bin/konshell" && info "$bin/konshell"
    rm -f "$data/applications/konshell-settings.desktop"
    [ -L "$config/quickshell/konshell" ] && rm -f "$config/quickshell/konshell"

    if [ "$purge" -eq 1 ]; then
        step "Удаляю настройки, состояние и кэш"
        rm -rf "$user"
        info "$user"
    else
        info "${dim}настройки остались в $user (удалить: --uninstall --purge)${reset}"
    fi

    printf '\n%sKonShell удалён.%s Пакеты не тронуты — при желании: sudo pacman -Rns quickshell matugen …\n' "$bold" "$reset"
    printf 'Перезайдите в сеанс niri, чтобы вернулись прежние панель и уведомления.\n'
    exit 0
fi

# ---------------------------------------------------------------- установка

printf '%sKonShell%s — оболочка для niri на Quickshell\n%sпапка: %s%s\n' "$bold" "$reset" "$dim" "$repo" "$reset"

command -v pacman >/dev/null 2>&1 || die "нужен Arch Linux или производный дистрибутив с pacman"
command -v niri >/dev/null 2>&1 || warn "niri не установлен — поставьте его (sudo pacman -S niri) и войдите в сеанс niri"

# Обязательные: без них оболочка не запустится или не построит палитру.
required=(quickshell matugen brightnessctl ffmpeg curl python libnotify xdg-utils)
# Дополнительные: история буфера, запись экрана, перекраска Qt и GTK3, обои AVIF/JXL, Firefox.
optional=(cliphist wl-clipboard wf-recorder slurp grim qt6ct adw-gtk-theme kimageformats python-pywalfox)

if [ "$packages" -eq 1 ]; then
    step "Пакеты"
    mapfile -t missing_req < <(pacman -T "${required[@]}" 2>/dev/null || true)
    mapfile -t missing_opt < <(pacman -T "${optional[@]}" 2>/dev/null || true)
    if [ ${#missing_req[@]} -eq 0 ] && [ ${#missing_opt[@]} -eq 0 ]; then
        info "всё уже установлено"
    else
        [ ${#missing_req[@]} -gt 0 ] && info "обязательные: ${missing_req[*]}"
        [ ${#missing_opt[@]} -gt 0 ] && info "дополнительные: ${missing_opt[*]} ${dim}(буфер обмена, запись экрана, перекраска Qt/GTK3, Firefox)${reset}"
        to_install=("${missing_req[@]}")
        if [ ${#missing_opt[@]} -gt 0 ] && ask "Поставить и дополнительные?"; then
            to_install+=("${missing_opt[@]}")
        fi
        if [ ${#to_install[@]} -gt 0 ]; then
            if ask "Установить: ${to_install[*]}?"; then
                flags=(--needed)
                [ "$yes" -eq 1 ] && flags+=(--noconfirm)
                sudo pacman -S "${flags[@]}" "${to_install[@]}"
            elif [ ${#missing_req[@]} -gt 0 ]; then
                die "без обязательных пакетов оболочка не заработает: ${missing_req[*]}"
            fi
        fi
    fi
fi

command -v qs >/dev/null 2>&1 || die "нет qs (пакет quickshell)"

step "Папка user/"
mkdir -p "$user/state" "$user/cache" "$user/colors"
[ -e "$user/cursor.kdl" ] || : > "$user/cursor.kdl"
[ -e "$user/colors/niri.kdl" ] || : > "$user/colors/niri.kdl"
# Прежние версии хранили данные в ~/.config/konshell, ~/.local/state/konshell и
# ~/.cache/konshell: переносим (уже существующее в user/ не трогаем), сами папки
# сохраняем в user/old/.
migrated=0
for pair in "$config/konshell:." "$state/konshell:state" "$cache/konshell:cache"; do
    old=${pair%%:*} sub=${pair##*:}
    [ -d "$old" ] && [ ! -L "$old" ] || continue
    (cd "$old" && find . -type f) | while read -r f; do
        dest="$user/$sub/${f#./}"
        [ -e "$dest" ] && continue
        mkdir -p "$(dirname "$dest")"
        cp -p "$old/$f" "$dest"
    done
    mkdir -p "$user/old"
    mv "$old" "$user/old/$(basename "$(dirname "$old")")-konshell"
    migrated=1
done
[ "$migrated" -eq 1 ] && info "данные прежней версии перенесены в user/ (старые папки — в user/old/)"
[ -L "$config/quickshell/konshell" ] && rm -f "$config/quickshell/konshell" && info "убрана ссылка прежней версии ~/.config/quickshell/konshell"
info "$user"

step "niri"
if [ ! -f "$niri_conf" ]; then
    warn "нет $niri_conf — запустите niri один раз (он создаст конфиг) и повторите установку"
else
    [ -e "$niri_conf.konshell-bak" ] || { cp -p "$niri_conf" "$niri_conf.konshell-bak"; info "копия конфига: config.kdl.konshell-bak"; }
    before=$(mktemp)
    cp -p "$niri_conf" "$before"

    # user/niri.kdl из шаблона: абсолютные пути к оболочке и к user/.
    esc() { printf '%s' "$1" | sed 's/[\\&|]/\\&/g'; }
    sed -e "s|@SHELL@|$(esc "$repo")|g" -e "s|@USER@|$(esc "$user")|g" "$repo/niri/konshell.kdl" > "$user/niri.kdl"
    info "user/niri.kdl собран из niri/konshell.kdl"

    clean_niri_conf 0
    rm -f "$niri_dir/konshell.kdl" "$niri_dir/konshell-colors.kdl" "$niri_dir/konshell-cursor.kdl"
    python3 -I - "$niri_conf" "$marker" "$include_comment" "$include_line" <<'PY'
import re, sys
path, marker, comment, include = sys.argv[1:5]
text = open(path, encoding="utf-8").read()
# Автозапуск того, что заменяет KonShell: панель, уведомления, обои, простой.
conflict = re.compile(r'^(\s*)(spawn(?:-sh)?-at-startup\s+"(?:[^"]*/)?(?:waybar|mako|swaync|dunst|swaybg|swww-daemon|hyprpaper|swayidle)\b.*)$', re.M)
text, n = conflict.subn(lambda m: f"{m.group(1)}{marker} {m.group(2)}", text)
if n:
    print(f"    отключён автозапуск: {n}")
text = text.rstrip("\n") + f"\n\n{comment}\n{include}\n"
open(path, "w", encoding="utf-8").write(text)
PY
    info "в конце config.kdl: $include_line"

    if niri validate -c "$niri_conf" >/dev/null 2>&1; then
        info "конфиг niri в порядке"
        rm -f "$before"
    else
        cp -p "$before" "$niri_conf"
        rm -f "$before"
        niri validate -c "$niri_conf" 2>&1 | tail -5 >&2 || true
        die "после правки конфиг niri невалиден — откатил изменения"
    fi
fi

step "Цвета приложений"
sh "$repo/scripts/install-theme-hooks.sh" | sed 's/^/    /'

step "Команда konshell"
mkdir -p "$bin"
printf '#!/bin/sh\n# KonShell: то же, что qs -p <папка оболочки>. Например: konshell ipc call launcher toggle\nexec qs -p %s "$@"\n' \
    "$(printf '%q' "$repo")" > "$bin/konshell"
chmod +x "$bin/konshell"
info "$bin/konshell"
case ":$PATH:" in *":$bin:"*) ;; *) warn "$bin нет в PATH — команда konshell будет доступна по полному пути" ;; esac

step "Запуск"
reload_niri
if [ -n "${NIRI_SOCKET:-}" ] && [ -n "${WAYLAND_DISPLAY:-}" ]; then
    stop_shell
    # Ждём, пока старая оболочка действительно завершится: иначе новая может
    # не стартовать (занят IPC и слои), особенно после обновления кода.
    for _ in $(seq 1 50); do
        pgrep -f -- "qs .*$repo" >/dev/null 2>&1 || break
        sleep 0.1
    done
    pkill -KILL -f -- "qs .*$repo" >/dev/null 2>&1 || true
    log=$(mktemp "${TMPDIR:-/tmp}/konshell-start.XXXXXX")
    setsid -f qs -p "$repo" >"$log" 2>&1 < /dev/null
    sleep 2
    if pgrep -f -- "qs .*$repo" >/dev/null 2>&1; then
        info "оболочка запущена"
        rm -f "$log"
    else
        warn "оболочка не запустилась, вывод qs:"
        sed 's/^/      /' "$log" | tail -n 30
        info "полный вывод: $log; запуск вручную: qs -p $repo"
    fi
else
    info "вы не в сеансе niri — оболочка запустится при следующем входе"
fi

cat <<EOF

${bold}Готово.${reset} Все файлы KonShell — в $repo (настройки — user/). Клавиши:
    Mod+Space        лаунчер
    Mod+Alt+V        история буфера обмена
    Mod+Alt+N        новая заметка
    Mod+Shift+E      выключение, перезагрузка, выход
    Super+Alt+L      блокировка экрана
Настройки — «Настройки KonShell» в лаунчере. Обои по умолчанию — ~/Pictures/Wallpapers.
${dim}Если остались прежние панель или уведомления (waybar, mako) — перезайдите в сеанс niri.${reset}
EOF
