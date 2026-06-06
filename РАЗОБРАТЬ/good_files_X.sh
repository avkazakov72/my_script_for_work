#!/bin/bash

# Установите утилиты для восстановления
sudo apt install jpegoptim imagemagick

BAD_DIR="/home/aleksey/Изображения/HomeArchive/ФотоНеОбработанные/Выяснить/jpg/500K "
RECOVERY_DIR="/home/aleksey/восстановленные_фото"

mkdir -p "$RECOVERY_DIR"

echo "Попытка восстановления JPEG файлов..."
echo

find "$BAD_DIR" -type f -iname "*.jpg" | while read -r file; do
    filename=$(basename "$file")
    echo "Обработка: $filename"
    
    # Способ 1: через jpegoptim
    if jpegoptim "$file" --dest="$RECOVERY_DIR" 2>/dev/null; then
        echo "  ✅ Восстановлен через jpegoptim"
    # Способ 2: через convert (ImageMagick)
    elif convert "$file" "$RECOVERY_DIR/${filename%.*}_recovered.jpg" 2>/dev/null; then
        echo "  ✅ Восстановлен через convert"
    else
        echo "  ❌ Не удалось восстановить"
    fi
done
