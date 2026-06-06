#!/bin/bash
# Быстрая проверка состояния дисков

echo "=== Быстрая проверка дисков ==="
echo "Время: $(date)"

echo -e "\n1. Проверка монтирования:"
if mountpoint -q /mnt/DATADISK; then
    echo "  DATADISK: ✓ смонтирован"
else
    echo "  DATADISK: ✗ НЕ смонтирован!"
fi

if mountpoint -q /mnt/RescueData; then
    echo "  RESCUEDISK: ✓ смонтирован"
else
    echo "  RESCUEDISK: ✗ НЕ смонтирован!"
fi

echo -e "\n2. Свободное место:"
df -h /mnt/DATADISK /mnt/RescueData 2>/dev/null || echo "  Некоторые диски не доступны"

echo -e "\n3. Проверка записи:"
for mp in /mnt/DATADISK /mnt/RescueData; do
    if [ -d "$mp" ]; then
        test_file="$mp/.test_write_$$"
        if touch "$test_file" 2>/dev/null; then
            echo "  $mp: ✓ запись работает"
            rm -f "$test_file"
        else
            echo "  $mp: ✗ ошибка записи"
        fi
    fi
done
