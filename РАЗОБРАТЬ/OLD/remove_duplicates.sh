#!/bin/bash

# 1. Установка системных зависимостей
sudo apt-get update
sudo apt-get install -y fdupes imagemagick python3-venv python3-dev

# 2. Создание виртуального окружения
VENV_DIR="./.venv_image_cleaner"
if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv "$VENV_DIR"
    source "$VENV_DIR/bin/activate"
    
    # Установка Python-пакетов в виртуальное окружение
    pip install opencv-python numpy pillow
    deactivate
fi

# 3. Поиск дубликатов
fdupes -r -n -S "$(pwd)" > duplicates.txt

# 4. Анализ качества и удаление через виртуальное окружение
source "$VENV_DIR/bin/activate"
python3 << 'EOF'
import os
import cv2
import numpy as np
from PIL import Image

def get_image_quality(img_path):
    try:
        # Проверка RAW-форматов
        raw_extensions = ('.nef', '.cr2', '.arw', '.raf', '.dng')
        if img_path.lower().endswith(raw_extensions):
            return (os.path.getsize(img_path) * 2  # RAW имеет приоритет
            
        # Для обычных изображений
        with Image.open(img_path) as img:
            resolution = img.size[0] * img.size[1]
            
            # Оценка качества только для поддерживаемых форматов
            if img_path.lower().endswith(('.jpg', '.jpeg', '.png', '.webp')):
                try:
                    image = cv2.imread(img_path)
                    if image is None:
                        return resolution
                        
                    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
                    sharpness = cv2.Laplacian(gray, cv2.CV_64F).var()
                    contrast = gray.std()
                    return resolution + sharpness * 100 + contrast * 50
                except:
                    return resolution
            return resolution
            
    except Exception as e:
        print(f"[WARNING] Ошибка оценки {img_path}: {str(e)}")
        return 0

def process_duplicates(file_list):
    if len(file_list) < 2:
        return
        
    scores = [(get_image_quality(f), f) for f in file_list]
    scores.sort(reverse=True)
    
    print(f"\nНайдено дубликатов: {len(scores)}")
    print(f"Лучший: {scores[0][1]} (оценка: {scores[0][0]})")
    
    for score, file in scores[1:]:
        try:
            os.remove(file)
            print(f"Удалён: {file} (оценка: {score})")
        except Exception as e:
            print(f"Ошибка удаления {file}: {str(e)}")

# Чтение файла с дубликатами
current_group = []
with open('duplicates.txt', 'r', encoding='utf-8', errors='ignore') as f:
    for line in f:
        line = line.strip()
        if not line:
            if current_group:
                process_duplicates(current_group)
                current_group = []
        else:
            current_group.append(line)
    
    if current_group:
        process_duplicates(current_group)
EOF

# 5. Очистка
deactivate
rm -f duplicates.txt
echo "Обработка завершена. Виртуальное окружение сохранено в $VENV_DIR"
