#!/bin/bash

# Скрипт проверки состояния дополнительных дисков
# Автор: Совместное человеческо-генаративноАИшное творчество
# Дата: $(date +%Y-%m-%d)

# Конфигурация
LOG_FILE="/var/log/disk_check.log"
MAX_LOG_SIZE=10485760  # 10MB
EMAIL="av.kazakov.yar@gmail.com"  # Замените на свой email если настроена отправка почты
DISKS=(
    "DATADISK:/mnt/DATADISK:48ab0853-44e1-4a6f-8a52-a164a0954edc"
    "RESCUEDISK:/mnt/RescueData:a64d99ef-e7e1-4ee6-adeb-a4966e877905"
)

# Цвета для вывода (опционально)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Функция логирования
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | sudo tee -a "$LOG_FILE"
}

# Функция проверки и ротации лога
rotate_log() {
    if [ -f "$LOG_FILE" ] && [ $(stat -c%s "$LOG_FILE") -gt $MAX_LOG_SIZE ]; then
        sudo mv "$LOG_FILE" "${LOG_FILE}.old"
        log_message "Лог файл был ротирован"
    fi
}

# Функция проверки SMART
check_smart() {
    local disk=$1
    if command -v smartctl &> /dev/null; then
        if sudo smartctl -H "/dev/$disk" 2>/dev/null | grep -q "PASSED"; then
            echo "SMART: PASSED"
            return 0
        else
            echo "SMART: FAILED или нет данных"
            return 1
        fi
    else
        echo "smartctl не установлен"
        return 2
    fi
}

# Функция проверки свободного места
check_disk_space() {
    local mount_point=$1
    local threshold=10  # Процент свободного места для предупреждения
    
    if df "$mount_point" &> /dev/null; then
        local used_percent=$(df "$mount_point" | awk 'NR==2 {print $5}' | sed 's/%//')
        local free_percent=$((100 - used_percent))
        
        if [ $free_percent -lt $threshold ]; then
            echo "ВНИМАНИЕ: Свободно только ${free_percent}% на $mount_point"
            return 1
        else
            echo "OK: Свободно ${free_percent}%"
            return 0
        fi
    else
        echo "Диск не смонтирован"
        return 2
    fi
}

# Основная функция проверки
main_check() {
    log_message "=== Начало проверки дисков ==="
    
    local any_problems=0
    local problem_disks=""
    
    for disk_info in "${DISKS[@]}"; do
        IFS=':' read -r label mount_point uuid <<< "$disk_info"
        
        echo -e "\n${YELLOW}Проверка диска: $label ($uuid)${NC}"
        log_message "Проверка диска: $label"
        
        # 1. Проверка монтирования
        if mountpoint -q "$mount_point"; then
            echo -e "${GREEN}✓ Диск смонтирован${NC}"
            log_message "  - Диск смонтирован корректно"
            
            # 2. Проверка свободного места
            space_check=$(check_disk_space "$mount_point")
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✓ $space_check${NC}"
                log_message "  - $space_check"
            else
                echo -e "${RED}✗ $space_check${NC}"
                log_message "  - ВНИМАНИЕ: $space_check"
                any_problems=1
                problem_disks="$problem_disks $label(место)"
            fi
            
            # 3. Проверка возможности записи
            local test_file="$mount_point/.disk_test_$(date +%s)"
            if touch "$test_file" 2>/dev/null; then
                echo -e "${GREEN}✓ Запись возможна${NC}"
                log_message "  - Запись на диск возможна"
                rm -f "$test_file"
            else
                echo -e "${RED}✗ Ошибка записи${NC}"
                log_message "  - ОШИБКА: Нельзя записать на диск"
                any_problems=1
                problem_disks="$problem_disks $label(запись)"
            fi
            
        else
            echo -e "${RED}✗ Диск НЕ смонтирован!${NC}"
            log_message "  - ОШИБКА: Диск не смонтирован"
            any_problems=1
            problem_disks="$problem_disks $label(монтирование)"
            
            # Попытка автоматического монтирования
            echo "Попытка монтирования..."
            if sudo mount "$mount_point" 2>/dev/null; then
                echo -e "${GREEN}✓ Успешно смонтирован автоматически${NC}"
                log_message "  - Диск смонтирован автоматически"
                any_problems=0
                problem_disks=$(echo "$problem_disks" | sed "s/$label(монтирование)//")
            else
                log_message "  - НЕУДАЧА: Автоматическое монтирование не удалось"
            fi
        fi
        
        # 4. Проверка SMART (только для физических дисков)
        disk_device=$(find /dev/disk/by-uuid -lname "*$uuid*" -exec readlink -f {} \; 2>/dev/null | grep -o 'sd[a-z]')
        if [ -n "$disk_device" ]; then
            smart_result=$(check_smart "$disk_device")
            echo "  SMART статус: $smart_result"
            log_message "  - SMART: $smart_result"
        fi
    done
    
    # Итог
    if [ $any_problems -eq 0 ]; then
        echo -e "\n${GREEN}✓ Все диски в порядке${NC}"
        log_message "=== Проверка завершена: все диски в порядке ==="
        return 0
    else
        echo -e "\n${RED}✗ Обнаружены проблемы с дисками: $problem_disks${NC}"
        log_message "=== Проверка завершена: проблемы с дисками: $problem_disks ==="
        
        # Отправка уведомления (если настроен почтовый клиент)
        if command -v mail &> /dev/null; then
            echo "Проблемы с дисками: $problem_disks" | mail -s "Disk Alert on $(hostname)" "$EMAIL"
        fi
        
        return 1
    fi
}

# Запуск
rotate_log
main_check

exit $?
