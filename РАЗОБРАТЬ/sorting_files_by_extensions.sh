#!/bin/bash

# Простая версия с базовыми проверками
echo "=== Сортировка файлов по расширениям ==="
echo

# Запрашиваем исходный каталог
while true; do
    read -p "Введите путь к исходному каталогу (А): " SOURCE_DIR
    SOURCE_DIR=$(echo "$SOURCE_DIR" | sed "s/^['\"]//; s/['\"]$//")
    
    if [ ! -d "$SOURCE_DIR" ]; then
        echo "Ошибка: Каталог '$SOURCE_DIR' не существует!"
    else
        break
    fi
done

# Запрашиваем целевой каталог
while true; do
    read -p "Введите путь к целевому каталогу (Б): " TARGET_DIR
    TARGET_DIR=$(echo "$TARGET_DIR" | sed "s/^['\"]//; s/['\"]$//")
    
    if [ -z "$TARGET_DIR" ]; then
        echo "Ошибка: Путь не может быть пустым!"
    else
        break
    fi
done

# Подтверждение
echo
echo "Будет выполнено:"
echo "Источник: $SOURCE_DIR"
echo "Цель: $TARGET_DIR"
echo

read -p "Продолжить? (y/N): " confirm
if [[ ! "$confirm" =~ ^[YyДд]$ ]]; then
    echo "Операция отменена."
    exit 0
fi

# Создаем целевой каталог
mkdir -p "$TARGET_DIR"

# Обработка файлов
echo
echo "Обработка файлов..."

find "$SOURCE_DIR" -type f | while read -r file; do
    # Получаем расширение файла (в верхнем регистре)
    extension="${file##*.}"
    extension=$(echo "$extension" | tr '[:lower:]' '[:upper:]')
    
    # Если файл без расширения, используем "NO_EXTENSION"
    if [ -z "$extension" ] || [ "$extension" = "$file" ]; then
        extension="NO_EXTENSION"
    fi
    
    # Создаем подкаталог для расширения
    ext_dir="$TARGET_DIR/$extension"
    mkdir -p "$ext_dir"
    
    # Копируем файл в целевой каталог
    mv "$file" "$ext_dir/"
    echo "Скопирован: $file -> $ext_dir/"
done

echo
echo "Готово! Файлы отсортированы по расширениям."
