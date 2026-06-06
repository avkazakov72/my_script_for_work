#!/bin/bash

# Создаем каталог GOOD в текущей директории
GOOD_DIR="./GOOD"
mkdir -p "$GOOD_DIR"

echo "=== Перенос рабочих графических файлов (≥50 КБ) в каталог GOOD ==="
echo

# Поддерживаемые форматы (включая RAW)
image_formats=(
    "*.jpg" "*.jpeg" "*.png" "*.gif" "*.bmp" "*.tiff" "*.tif" 
    "*.webp" "*.heic" "*.heif" "*.raw" "*.cr2" "*.nef" "*.arw" 
    "*.dng" "*.orf" "*.sr2" "*.pef" "*.raf" "*.rw2" "*.srw"
    "*.ico" "*.svg" "*.psd" "*.xcf"
)

# Счетчики
total=0
moved=0
broken=0
small=0

# Функция для проверки целостности изображения
is_valid_image() {
    local file="$1"
    
    # Проверяем через identify (ImageMagick)
    if identify "$file" >/dev/null 2>&1; then
        return 0
    # Для RAW файлов используем dcraw или exiftool
    elif [[ "$file" =~ \.(cr2|nef|arw|dng|orf|sr2|pef|raf|rw2|srw)$ ]]; then
        # Проверяем через exiftool
        if exiftool "$file" >/dev/null 2>&1; then
            return 0
        # Или через dcraw
        elif command -v dcraw &>/dev/null && dcraw -i "$file" >/dev/null 2>&1; then
            return 0
        fi
    fi
    
    return 1
}

# Функция для получения размера файла в КБ
get_file_size_kb() {
    local file="$1"
    if [ -f "$file" ]; then
        size=$(stat -c%s "$file")
        echo $((size / 1024))
    else
        echo "0"
    fi
}

# Обрабатываем файлы
for format in "${image_formats[@]}"; do
    while IFS= read -r -d '' file; do
        ((total++))
        filename=$(basename "$file")
        filesize_kb=$(get_file_size_kb "$file")
        
        echo "[$total] Проверка: $filename"
        echo "  Размер: ${filesize_kb} КБ"
        
        # Пропускаем файлы уже в каталоге GOOD
        if [[ "$file" == ./GOOD/* ]]; then
            echo "  ⏭️  Пропуск: файл уже в каталоге GOOD"
            continue
        fi
        
        # Проверяем размер (от 50 КБ)
        if [ "$filesize_kb" -lt 50 ]; then
            echo "  ❌ Отбракован: слишком маленький размер (${filesize_kb} КБ < 50 КБ)"
            ((small++))
            continue
        fi
        
        # Проверяем целостность файла
        if is_valid_image "$file"; then
            echo "  ✅ Подходит: рабочий файл, ${filesize_kb} КБ"
            mv "$file" "$GOOD_DIR/"
            ((moved++))
            echo "  📁 Перемещен в: $GOOD_DIR/"
        else
            echo "  ❌ Отбракован: битый или неподдерживаемый формат"
            ((broken++))
        fi
        
        echo
        
    done < <(find . -maxdepth 1 -type f -iname "$format" -print0 2>/dev/null)
done

echo "=== Результаты ==="
echo "Всего найдено файлов: $total"
echo "Перенесено в GOOD: $moved"
echo "Отбраковано (битые): $broken"
echo "Отбраковано (маленькие): $small"
echo "Каталог с подходящими файлами: $GOOD_DIR"