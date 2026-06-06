#!/bin/bash

# Целевой каталог
TARGET_DIR="$HOME/Видео/HOMEMOVES"

# Создаем целевой каталог, если его нет
mkdir -p "$TARGET_DIR"

# Поддерживаемые форматы видео (можно дополнять)
VIDEO_EXTS=("*.mp4" "*.mov" "*.avi" "*.mkv" "*.mpeg" "*.mpg" "*.wmv" "*.flv" "*.m4v" "*.3gp" "*.webm")

# Находим и перемещаем файлы с сохранением структуры подкаталогов
find . -type f \( -iname "*.mp4" -o -iname "*.mov" -o -iname "*.avi" -o -iname "*.mkv" -o -iname "*.mpeg" -o -iname "*.mpg" -o -iname "*.wmv" -o -iname "*.flv" -o -iname "*.m4v" -o -iname "*.3gp" -o -iname "*.webm" \) -print0 | while IFS= read -r -d '' file; do
    # Получаем относительный путь
    rel_path="${file#./}"
    
    # Создаем целевую директорию
    new_dir="$TARGET_DIR/$(dirname "$rel_path")"
    mkdir -p "$new_dir"
    
    # Перемещаем файл
    mv -nv "$file" "$new_dir/"
done

echo "Все видеофайлы перемещены в $TARGET_DIR"
