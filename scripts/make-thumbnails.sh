#!/bin/sh
# Миниатюры обоев для страницы «Оформление». Запускается сервисом Wallpaper после скана папки.
#
#   make-thumbnails.sh <папка кэша> <картинка>...
#
# Имя миниатюры — md5 полного пути (так же считает QML через Qt.md5).
# Пересоздаётся, только если миниатюры нет или картинка новее неё.
# Ошибки отдельных файлов не прерывают остальные; сетка покажет такие картинки из оригинала.

set -u
cache=$1
shift
mkdir -p "$cache" || exit 1
command -v ffmpeg >/dev/null 2>&1 || { echo "ffmpeg не найден: миниатюры не созданы" >&2; exit 3; }

for src in "$@"; do
    out="$cache/$(printf %s "$src" | md5sum | cut -c1-32).jpg"
    if [ ! -e "$out" ] || [ "$src" -nt "$out" ]; then
        # Фоновая задача: пониженный приоритет, чтобы не мешать работе.
        nice -n 10 ffmpeg -loglevel error -y -i "$src" -vf "scale=320:-2" -frames:v 1 -q:v 4 "$out" </dev/null \
            || echo "Не удалось сделать миниатюру: $src" >&2
    fi
done
