#!/bin/bash
# correct_check.sh
DISK="/dev/sda"

echo "=== ПРАВИЛЬНАЯ ПРОВЕРКА ДИСКА $DISK ==="
echo ""

# 1. Узнаем размер диска
TOTAL_BLOCKS=$(sudo blockdev --getsz "$DISK")
echo "1. Размер диска в блоках 512 байт: $TOTAL_BLOCKS"
echo "   В гигабайтах: $((TOTAL_BLOCKS * 512 / 1024 / 1024 / 1024))GB"
echo ""

# 2. Проверяем 1% диска (примерно 1.6GB)
CHECK_BLOCKS=$((TOTAL_BLOCKS / 100))
echo "2. Проверка 1% диска ($CHECK_BLOCKS блоков):"
sudo badblocks -svn -b 512 -c 1024 "$DISK" 0 "$CHECK_BLOCKS"
echo ""

# 3. Проверяем середину диска
MIDDLE=$((TOTAL_BLOCKS / 2))
MIDDLE_CHECK=$((TOTAL_BLOCKS / 200))  # 0.5% от середины
echo "3. Проверка середины диска (блок $MIDDLE):"
sudo badblocks -svn -b 512 -c 1024 "$DISK" "$MIDDLE" "$MIDDLE_CHECK"
echo ""

# 4. Проверяем конец диска
END=$((TOTAL_BLOCKS - CHECK_BLOCKS))
echo "4. Проверка конца диска (последние 1%):"
sudo badblocks -svn -b 512 -c 1024 "$DISK" "$END" "$CHECK_BLOCKS"