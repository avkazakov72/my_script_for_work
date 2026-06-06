#Данный скрипт из указанного каталога и всех подкаталогов
#переносить все файлы в указанный каталог с разбивкой их
#по подкаталогам с сответсвующие файлу расширениями
#(создан с целью разобраться в хаосе с медийными и прочими 
#восстановленных и собранными файлами со сбойных дисков
#
#!/bin/bash

# Определяем исходный и целевой каталоги
SOURCE_DIR="/mnt/DATAINFO/DATA_0"
TARGET_DIR="/mnt/DATAINFO/DATA_NEW"

# Проверяем существование исходного каталога
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Ошибка: Исходный каталог $SOURCE_DIR не существует!"
    exit 1
fi

# Создаем целевой каталог, если он не существует
mkdir -p "$TARGET_DIR"

echo "Начинаем обработку файлов из $SOURCE_DIR"
echo "Целевой каталог: $TARGET_DIR"

# Используем цикл для обработки файлов
find "$SOURCE_DIR" -type f | while read -r file; do
    # Получаем расширение файла (в нижнем регистре)
    filename=$(basename "$file")
    extension="${filename##*.}"
    
    # Если файл не имеет расширения или имя файла совпадает с расширением
    if [[ "$filename" == "$extension" ]] || [[ "$extension" == "" ]]; then
        extension="no_extension"
    else
        # Преобразуем в нижний регистр
        extension=$(echo "$extension" | tr '[:upper:]' '[:lower:]')
    fi
    
    # Создаем целевой подкаталог для данного расширения
    target_subdir="$TARGET_DIR/$extension"
    mkdir -p "$target_subdir"
    
    # Получаем имя файла без расширения
    basename="${filename%.*}"
    
    # Если это скрытый файл без расширения (начинается с точки)
    if [[ "$filename" == .* && "$basename" == "$filename" ]]; then
        basename="$filename"
        extension=""
    fi
    
    # Формируем исходное целевое имя
    if [[ "$extension" != "no_extension" && "$extension" != "" ]]; then
        target_name="$filename"
    else
        target_name="$filename"
    fi
    
    target_path="$target_subdir/$target_name"
    
    # Проверяем, существует ли уже файл в целевом каталоге
    counter=1
    while [[ -e "$target_path" ]]; do
        # Если файл существует, добавляем "_!" или "_!N" к имени
        if [[ "$extension" != "no_extension" && "$extension" != "" ]]; then
            if [[ $counter -eq 1 ]]; then
                target_name="${basename}_!.${extension}"
            else
                target_name="${basename}_!${counter}.${extension}"
            fi
        else
            if [[ $counter -eq 1 ]]; then
                target_name="${basename}_!"
            else
                target_name="${basename}_!${counter}"
            fi
        fi
        target_path="$target_subdir/$target_name"
        ((counter++))
    done
    
    # Переносим файл
    echo "Перенос: $file -> $target_path"
    mv "$file" "$target_path"
    
done

echo "Обработка завершена!"
echo "Файлы рассортированы по каталогам в $TARGET_DIR"
