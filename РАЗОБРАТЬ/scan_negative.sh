#!/bin/bash
echo "📷 Оцифровка негативов"
echo "======================"
echo "1. Наведите камеру на негатив"
echo "2. Нажмите Enter для захвата"
echo "3. Ctrl+C для выхода"
echo ""

while true; do
    read -p "Готовы? Нажмите Enter... "
    filename="scan_$(date +%Y%m%d_%H%M%S).jpg"
    echo "Захватываю кадр..."
    ffmpeg -f v4l2 -i /dev/video0 -vf "negate" -frames 1 "$filename" -y
    echo "✅ Сохранено: $filename"
    echo ""
done
