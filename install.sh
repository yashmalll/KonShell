#!/usr/bin/env bash
# Установка KonShell — оболочки рабочего стола для niri на Quickshell (Arch Linux).
#
#   ./install.sh                 установить или обновить подключение
#   ./install.sh --yes           без вопросов (пакеты ставятся сразу)
#   ./install.sh --no-packages   не трогать пакеты
#   ./install.sh --update        обновить KonShell из git (git pull) и перезапустить
#   ./install.sh --uninstall     убрать KonShell (настройки остаются)
#   ./install.sh --uninstall --purge   убрать вместе с настройками, PIN и кэшем
#
# Что делает установка:
#   1. ставит недостающие пакеты (pacman, после подтверждения);
#   2. ссылка ~/.config/quickshell/konshell → этот репозиторий (команда «qs -c konshell»);
#   3. niri: ссылка ~/.config/niri/konshell.kdl → niri/konshell.kdl и строка
#      include "konshell.kdl" в конце config.kdl; автозапуск waybar, mako и подобных
#      закомментирован (они дублировали бы панель и уведомления). Копия config.kdl
#      до первой правки — config.kdl.konshell-bak; невалидный конфиг откатывается;
#   4. перекраска приложений под палитру (scripts/install-theme-hooks.sh);
#   5. запуск оболочки, если вы в сеансе niri.
# Повторный запуск ничего не дублирует. --update сначала подтягивает свежую версию
# репозитория (только fast-forward; при локальных правках останавливается), затем
# выполняет установку уже новой версией скрипта.

set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
config=${XDG_CONFIG_HOME:-$HOME/.config}
state=${XDG_STATE_HOME:-$HOME/.local/state}
cache=${XDG_CACHE_HOME:-$HOME/.cache}
data=${XDG_DATA_HOME:-$HOME/.local/share}
niri_dir="$config/niri"
niri_conf="$niri_dir/config.kdl"
qs_link="$config/quickshell/konshell"
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
        -h|--help) sed -n '2,23p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
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
    if command -v qs >/dev/null 2>&1; then
        qs kill -c konshell >/dev/null 2>&1 || true
        # Копия, запущенная напрямую из папки репозитория (qs -p …).
        qs kill -p "$repo" >/dev/null 2>&1 || true
    fi
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

# ---------------------------------------------------------------- удаление

if [ "$uninstall" -eq 1 ]; then
    step "Останавливаю оболочку"
    stop_shell

    step "Отключаю перекраску приложений"
    sh "$repo/scripts/install-theme-hooks.sh" --uninstall || true
    rm -f "$niri_dir/konshell-colors.kdl"

    step "Убираю KonShell из niri"
    if [ -f "$niri_conf" ]; then
        python3 -I - "$niri_conf" "$marker" <<'PY'
import sys
path, marker = sys.argv[1:3]
lines = open(path, encoding="utf-8").read().split("\n")
out = []
for line in lines:
    if line.strip() in ('include "konshell.kdl"', "// KonShell: автозапуск, клавиши, обои (niri/konshell.kdl в репозитории)"):
        continue
    if line.lstrip().startswith(marker):
        indent = line[: len(line) - len(line.lstrip())]
        line = indent + line.lstrip()[len(marker):].lstrip()
    out.append(line)
open(path, "w", encoding="utf-8").write("\n".join(out).rstrip("\n") + "\n")
PY
        info "строка include убрана, отключённый автозапуск возвращён"
    fi
    [ -L "$niri_dir/konshell.kdl" ] && rm -f "$niri_dir/konshell.kdl"
    if command -v niri >/dev/null 2>&1 && [ -f "$niri_conf" ]; then
        niri validate -c "$niri_conf" >/dev/null 2>&1 && info "конфиг niri в порядке" \
            || warn "niri validate сообщает об ошибке — сравните с $niri_conf.konshell-bak"
    fi
    reload_niri

    step "Убираю ссылки"
    if [ -L "$qs_link" ] && [ "$(readlink -f "$qs_link")" = "$repo" ]; then
        rm -f "$qs_link"
        info "$qs_link"
    fi
    rm -f "$data/applications/konshell-settings.desktop"

    if [ "$purge" -eq 1 ]; then
        step "Удаляю настройки, состояние и кэш"
        rm -rf "$config/konshell" "$state/konshell" "$cache/konshell" "$cache/wal/colors.json"
        info "~/.config/konshell, ~/.local/state/konshell, ~/.cache/konshell"
    else
        info "${dim}настройки остались в ~/.config/konshell и ~/.local/state/konshell (удалить: --uninstall --purge)${reset}"
    fi

    printf '\n%sKonShell удалён.%s Пакеты не тронуты — при желании: sudo pacman -Rns quickshell matugen …\n' "$bold" "$reset"
    printf 'Перезайдите в сеанс niri, чтобы вернулись прежние панель и уведомления.\n'
    exit 0
fi

# ---------------------------------------------------------------- установка

printf '%sKonShell%s — оболочка для niri на Quickshell\n%sрепозиторий: %s%s\n' "$bold" "$reset" "$dim" "$repo" "$reset"

command -v pacman >/dev/null 2>&1 || die "нужен Arch Linux или производный дистрибутив с pacman"
command -v niri >/dev/null 2>&1 || warn "niri не установлен — поставьте его (sudo pacman -S niri) и войдите в сеанс niri"

# Обязательные: без них оболочка не запустится или не построит палитру.
required=(quickshell matugen brightnessctl ffmpeg curl python libnotify xdg-utils)
# Необязательные: история буфера, запись экрана, перекраска Qt и GTK3, обои AVIF/JXL, Firefox.
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

step "Конфигурация Quickshell"
mkdir -p "$config/quickshell"
if [ -L "$qs_link" ]; then
    if [ "$(readlink -f "$qs_link")" != "$repo" ]; then
        warn "$qs_link указывала на $(readlink -f "$qs_link") — перенаправляю сюда"
    fi
    ln -sfn "$repo" "$qs_link"
elif [ -e "$qs_link" ]; then
    die "$qs_link уже существует и это не ссылка — переименуйте его и запустите снова"
elif [ "$repo" != "$qs_link" ]; then
    ln -s "$repo" "$qs_link"
fi
info "$qs_link → $repo"

step "niri"
if [ ! -f "$niri_conf" ]; then
    warn "нет $niri_conf — запустите niri один раз (он создаст конфиг) и повторите установку"
else
    mkdir -p "$niri_dir"
    [ -e "$niri_conf.konshell-bak" ] || { cp -p "$niri_conf" "$niri_conf.konshell-bak"; info "копия конфига: config.kdl.konshell-bak"; }
    before=$(mktemp)
    cp -p "$niri_conf" "$before"
    ln -sfn "$repo/niri/konshell.kdl" "$niri_dir/konshell.kdl"
    [ -e "$niri_dir/konshell-colors.kdl" ] || : > "$niri_dir/konshell-colors.kdl"

    python3 -I - "$niri_conf" "$marker" <<'PY'
import re, sys
path, marker = sys.argv[1:3]
text = open(path, encoding="utf-8").read()
# Автозапуск того, что заменяет KonShell: панель, уведомления, обои, простой.
conflict = re.compile(r'^(\s*)(spawn(?:-sh)?-at-startup\s+"(?:[^"]*/)?(?:waybar|mako|swaync|dunst|swaybg|swww-daemon|hyprpaper|swayidle)\b.*)$', re.M)
text, n = conflict.subn(lambda m: f"{m.group(1)}{marker} {m.group(2)}", text)
if n:
    print(f"    отключён автозапуск: {n}")
if not re.search(r'^include "konshell\.kdl"\s*$', text, re.M):
    text = text.rstrip("\n") + '\n\n// KonShell: автозапуск, клавиши, обои (niri/konshell.kdl в репозитории)\ninclude "konshell.kdl"\n'
    print('    добавлено: include "konshell.kdl"')
open(path, "w", encoding="utf-8").write(text)
PY

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

step "Перекраска приложений под палитру"
sh "$repo/scripts/install-theme-hooks.sh" | sed 's/^/    /'

step "Запуск"
reload_niri
if [ -n "${NIRI_SOCKET:-}" ] && [ -n "${WAYLAND_DISPLAY:-}" ]; then
    stop_shell
    sleep 1
    setsid -f qs -c konshell >/dev/null 2>&1 < /dev/null
    info "оболочка запущена: qs -c konshell"
else
    info "вы не в сеансе niri — оболочка запустится при следующем входе"
fi

cat <<EOF

${bold}Готово.${reset} Клавиши (niri/konshell.kdl):
    Mod+Space        лаунчер
    Mod+Alt+V        история буфера обмена
    Mod+Alt+N        новая заметка
    Mod+Shift+E      выключение, перезагрузка, выход
    Super+Alt+L      блокировка экрана
Настройки — «Настройки KonShell» в лаунчере. Обои по умолчанию — ~/Pictures/Wallpapers.
${dim}Если остались прежние панель или уведомления (waybar, mako) — перезайдите в сеанс niri.${reset}
EOF
