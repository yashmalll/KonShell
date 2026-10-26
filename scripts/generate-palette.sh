#!/bin/sh
# Генерация палитры Material You через matugen. Запускается сервисом ColorScheme.
#
#   generate-palette.sh image <путь к картинке> <схема> <контраст> <индекс цвета> <ключ кэша>
#   generate-palette.sh color <#rrggbb>          <схема> <контраст> -              <ключ кэша>
#
# stdout: строка "key <ключ>", строка "achromatic 0|1", затем JSON matugen.
#         Строка "unchanged", если ключ совпал с ключом кэша (палитра уже актуальна).
# Код возврата: 0 — успех, 2 — файл недоступен, 3 — нет matugen, 4 — matugen не справился.
#
# Ключ включает время изменения файла, поэтому замена картинки по тому же пути
# тоже приводит к новой палитре.
# Префикс версии (v2) меняется вместе с логикой генерации, чтобы старый кэш не применялся.
#
# Бесцветные обои (ч/б, серые): matugen не находит в них цвета и без подсказки
# подставил бы свой синий #4285f4 — у всех таких обоев была бы одна синяя палитра.
# Поэтому даём ему метку --fallback-color, а увидев её в ответе, строим палитру
# «Нейтральная» от среднего цвета картинки (или «Монохром», если выбран он).

set -u
kind=$1 src=$2 scheme=$3 contrast=$4 index=$5 cached=$6
sentinel="#808081"

if ! command -v matugen >/dev/null 2>&1; then
    echo "matugen не найден. Установите: sudo pacman -S matugen" >&2
    exit 3
fi

if [ "$kind" = color ]; then
    key="v2|color|$src|$scheme|$contrast"
else
    if [ ! -r "$src" ]; then
        echo "Файл обоев недоступен: $src" >&2
        exit 2
    fi
    key="v2|image|$src|$(stat -c %Y "$src")|$scheme|$contrast|$index"
fi

if [ "$key" = "$cached" ]; then
    echo unchanged
    exit 0
fi

# run <схема> <аргументы matugen>
run() {
    run_scheme=$1
    shift
    # stdin закрыт: без --source-color-index matugen спрашивает в терминале и зависает.
    matugen "$@" --dry-run -j hex -t "scheme-$run_scheme" "--contrast=$contrast" </dev/null
}

# Средний цвет картинки как #rrggbb (ffmpeg сжимает её до одного пикселя).
average_color() {
    hex=$(ffmpeg -loglevel error -i "$1" -vf "scale=1:1:flags=area" -frames:v 1 -f rawvideo -pix_fmt rgb24 - </dev/null 2>/dev/null \
        | od -An -tx1 | tr -d ' \n')
    [ ${#hex} -eq 6 ] && echo "#$hex" || echo "$sentinel"
}

achromatic=0
if [ "$kind" = color ]; then
    json=$(run "$scheme" color hex "$src") || { echo "matugen не смог построить палитру из цвета $src" >&2; exit 4; }
else
    image=$src
    if ! json=$(run "$scheme" image "$image" --source-color-index "$index" --fallback-color "$sentinel" 2>/dev/null); then
        # matugen читает не все форматы (например, AVIF): уменьшаем картинку в PNG через ffmpeg.
        tmp=$(mktemp --suffix=.png)
        trap 'rm -f "$tmp"' EXIT
        if command -v ffmpeg >/dev/null 2>&1 \
            && ffmpeg -loglevel error -y -i "$src" -vf "scale=512:-2" -frames:v 1 "$tmp" </dev/null 2>/dev/null; then
            image=$tmp
            json=$(run "$scheme" image "$image" --source-color-index "$index" --fallback-color "$sentinel") \
                || { echo "matugen не смог разобрать картинку даже после перевода в PNG: $src" >&2; exit 4; }
        else
            echo "matugen не поддерживает формат, а перевести через ffmpeg не удалось: $src" >&2
            exit 4
        fi
    fi

    if printf '%s\n' "$json" | grep -A2 '"source_color"' | grep -qi "$sentinel"; then
        achromatic=1
        seed=$(average_color "$image")
        [ "$scheme" = monochrome ] && gray_scheme=monochrome || gray_scheme=neutral
        json=$(run "$gray_scheme" color hex "$seed") \
            || { echo "matugen не смог построить серую палитру для $src" >&2; exit 4; }
    fi
fi

printf 'key %s\nachromatic %s\n%s\n' "$key" "$achromatic" "$json"
