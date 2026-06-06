#!/bin/bash

# Создаем каталоги
mkdir -p /mnt/DATAINFO/RESCUE_DATA/{PICTURE,VIDEO,ARCHIVE}

# Функция для перемещения файлов с проверкой
move_files() {
    local pattern=$1
    local target_dir=$2
    
    find /mnt/DATAINFO/RESCUE_DATA -type f \( $pattern \) -print0 | while IFS= read -r -d '' file; do
        echo "Перемещаем: $file -> $target_dir"
        mv -v "$file" "$target_dir/"
    done
}

# Перемещаем изображения
move_files '-iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.bmp" -o -iname "*.tiff" -o -iname "*.tif" -o -iname "*.webp" -o -iname "*.svg" -o -iname "*.raw" -o -iname "*.cr2" -o -iname "*.nef"' "/mnt/DATAINFO/RESCUE_DATA/PICTURE"

# Перемещаем видео
move_files '-iname "*.mp4" -o -iname "*.avi" -o -iname "*.mov" -o -iname "*.mkv" -o -iname "*.wmv" -o -iname "*.flv" -o -iname "*.webm" -o -iname "*.m4v" -o -iname "*.mpg" -o -iname "*.mpeg" -o -iname "*.3gp"' "/mnt/DATAINFO/RESCUE_DATA/VIDEO"

# Перемещаем архивы
move_files '-iname "*.zip" -o -iname "*.rar" -o -iname "*.7z" -o -iname "*.tar" -o -iname "*.gz" -o -iname "*.bz2" -o -iname "*.xz" -o -iname "*.tar.gz" -o -iname "*.tar.bz2" -o -iname "*.tar.xz" -o -iname "*.tgz"' "/mnt/DATAINFO/RESCUE_DATA/ARCHIVE"

echo "Готово! Все файлы отсортированы."