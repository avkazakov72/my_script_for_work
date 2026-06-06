#!/bin/bash

# Создаем каталог GOOD в текущей директории
GOOD_DIR="./GOOD"
mkdir -p "$GOOD_DIR"

# Подсчитываем общее количество файлов для прогресса
total_files=$(find . -maxdepth 1 -type f \( -iname "*.mp4" -o -iname "*.avi" -o -iname "*.mkv" -o -iname "*.mov" -o -iname "*.wmv" -o -iname "*.flv" -o -iname "*.webm" -o -iname "*.m4v" \) | wc -l)
current_file=0

echo "Найдено видеофайлов: $total_files"
echo "Начинаем проверку и перенос подходящих файлов..."
echo

# Функция для проверки длительности видео
get_duration() {
    local file="$1"
    # Получаем длительность в секундах через ffprobe
    duration=$(ffprobe -v error -select_streams v:0 -show_entries stream=duration -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null)
    
    # Проверяем, что длительность получена и является числом
    if [[ $duration =~ ^[0-9]+\.?[0-9]*$ ]]; then
        echo "$duration"
    else
        echo "0"
    fi
}

# Функция для проверки, является ли файл рабочим видео
is_valid_video() {
    local file="$1"
    
    # Проверяем общую целостность файла и наличие видео потока
    if ffprobe -v error -select_streams v:0 -show_entries stream=codec_type -of csv=p=0 "$file" 2>/dev/null | grep -q "video"; then
        return 0
    else
        return 1
    fi
}

# Счетчики
good_count=0
bad_count=0

# Обрабатываем видеофайлы в текущей директории
while IFS= read -r -d '' file; do
    ((current_file++))
    filename=$(basename "$file")
    
    echo "[$current_file/$total_files] Проверка: $filename"
    
    # Пропускаем файлы в каталоге GOOD
    if [[ "$file" == ./GOOD/* ]]; then
        echo "  Пропуск: файл уже в каталоге GOOD"
        continue
    fi
    
    # Проверяем, что файл рабочий
    if ! is_valid_video "$file"; then
        echo "  ❌ Отбракован: не является рабочим видеофайлом"
        ((bad_count++))
        continue
    fi
    
    # Получаем длительность
    duration=$(get_duration "$file")
    
    # Проверяем длительность (от 5 секунд)
    if (( $(echo "$duration >= 5" | bc -l) )); then
        duration_int=${duration%.*}
        echo "  ✅ Подходит: длительность ${duration_int} секунд"
        
        # ПЕРЕНОСИМ (перемещаем) файл в каталог GOOD
        mv "$file" "$GOOD_DIR/"
        ((good_count++))
        echo "  📁 Перемещен в: $GOOD_DIR/"
    else
        echo "  ❌ Отбракован: длительность ${duration%.*} секунд (меньше 5 сек)"
        ((bad_count++))
    fi
    
    echo
done < <(find . -maxdepth 1 -type f \( -iname "*.mp4" -o -iname "*.avi" -o -iname "*.mkv" -o -iname "*.mov" -o -iname "*.wmv" -o -iname "*.flv" -o -iname "*.webm" -o -iname "*.m4v" \) -print0)

echo "=== Результаты ==="
echo "Всего обработано: $total_files"
echo "Перенесено в GOOD: $good_count"
echo "Отбраковано: $bad_count"
echo "Каталог с подходящими файлами: $GOOD_DIR"