#!/bin/bash

# Скрипт для создания копии файла с датой в имени
# Использование: ./backup_script.sh /путь/к/файлу

# Проверяем, передан ли аргумент
if [ $# -eq 0 ]; then
    echo "❌ Ошибка: Не указано имя файла!"
    echo "Использование: $0 /путь/к/файлу"
    exit 1
fi

source_file="$1"

# Проверяем, существует ли файл
if [ ! -f "$source_file" ]; then
    echo "❌ Ошибка: Файл '$source_file' не найден!"
    exit 1
fi

# Получаем директорию и имя файла
file_dir=$(dirname "$source_file")
file_name=$(basename "$source_file")

# Создаем имя для копии с датой
current_date=$(date +%Y%m%d_%H%M%S)
backup_name="${file_dir}/${file_name}_${current_date}.bak"

# Создаем копию
cp "$source_file" "$backup_name"

# Проверяем результат
if [ $? -eq 0 ]; then
    echo "✅ Копия успешно создана:"
    echo "   $backup_name"
    echo "   Размер: $(du -h "$backup_name" | cut -f1)"
else
    echo "❌ Ошибка при создании копии!"
    exit 1
fi