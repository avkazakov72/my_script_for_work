#!/bin/bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Функция для проверки, является ли диск системным
is_system_disk() {
    local disk=$1
    
    # Проверяем, содержит ли диск разделы, которые смонтированы в корень /, /boot, /boot/efi, /home
    if lsblk -n -o MOUNTPOINT "$disk" 2>/dev/null | grep -q -E '^/$|^/boot$|^/boot/efi$|^/home$'; then
        return 0
    fi
    
    return 1
}

# Функция для получения списка всех дисков (кроме системных)
get_available_disks() {
    local disks=()
    
    # Получаем список всех дисков (не разделов)
    while read -r disk size type; do
        # Пропускаем, если это не диск
        if [[ "$type" != "disk" ]]; then
            continue
        fi
        
        # Пропускаем системные диски
        if is_system_disk "/dev/$disk"; then
            continue
        fi
        
        # Добавляем диск в массив
        disks+=("/dev/$disk")
        
    done < <(lsblk -n -o NAME,SIZE,TYPE | grep -E "disk$")
    
    printf '%s\n' "${disks[@]}"
}

# Функция для получения модели диска
get_disk_model() {
    local disk=$1
    local model=""
    
    # Пробуем получить модель через smartctl
    if command -v smartctl &>/dev/null; then
        model=$(sudo smartctl -i "$disk" 2>/dev/null | grep "Device Model" | cut -d: -f2 | xargs)
    fi
    
    # Если smartctl не дал результата, пробуем через lsblk
    if [[ -z "$model" ]]; then
        model=$(lsblk -n -o MODEL "$disk" 2>/dev/null | head -1)
    fi
    
    echo "$model"
}

# Функция для отображения меню выбора дисков
show_disk_menu() {
    local disks=("$@")
    
    # Очищаем буфер ввода
    while read -r -t 0; do read -r; done
    
    echo -e "\n${GREEN}=== Доступные диски для подключения ===${NC}"
    echo -e "${YELLOW}Системные диски (Debian) исключены из списка${NC}\n"
    
    local i=1
    declare -a menu_items
    
    for disk in "${disks[@]}"; do
        local size=$(lsblk -n -o SIZE "$disk" | head -1)
        local model=$(get_disk_model "$disk")
        
        # Проверяем, является ли диск USB (простая проверка по пути)
        local usb_indicator=""
        if [[ "$disk" =~ ^/dev/sd ]] && [[ -d "/sys/block/$(basename "$disk")" ]]; then
            if readlink -f "/sys/block/$(basename "$disk")" 2>/dev/null | grep -q "usb"; then
                usb_indicator="${PURPLE}[USB]${NC} "
            fi
        fi
        
        echo -e "  ${CYAN}$i.${NC} ${usb_indicator}${GREEN}$disk${NC} (${BLUE}$size${NC}) - ${model:-"Без модели"}"
        menu_items[$i]="$disk"
        ((i++))
    done
    
    if [[ $i -eq 1 ]]; then
        echo -e "${RED}Нет доступных дисков для подключения${NC}"
        return 1
    fi
    
    echo -e "\n${YELLOW}Введите номера дисков для подключения (через запятую или пробел)"
    echo -e "Например: 1,3,5  или 1 3 5"
    echo -e "Или 'all' для подключения всех дисков"
    echo -e "Или нажмите Enter для запуска без дополнительных дисков${NC}"
    
    # Принудительно сбрасываем буфер вывода
    echo -n "> " > /dev/tty
    read -r selection < /dev/tty
    
    local selected_disks=()
    
    if [[ -z "$selection" ]]; then
        echo -e "${YELLOW}Запуск без дополнительных дисков${NC}"
        return 0
    fi
    
    if [[ "$selection" == "all" ]]; then
        for ((j=1; j<i; j++)); do
            selected_disks+=("${menu_items[$j]}")
        done
    else
        # Заменяем запятые на пробелы и разбиваем на массив
        IFS=', ' read -ra numbers <<< "$selection"
        for num in "${numbers[@]}"; do
            if [[ "$num" =~ ^[0-9]+$ ]] && [[ $num -ge 1 ]] && [[ $num -lt $i ]]; then
                selected_disks+=("${menu_items[$num]}")
            else
                echo -e "${RED}Неверный номер: $num${NC}"
            fi
        done
    fi
    
    if [[ ${#selected_disks[@]} -gt 0 ]]; then
        echo -e "\n${GREEN}Выбраны диски:${NC}"
        for disk in "${selected_disks[@]}"; do
            echo -e "  ${CYAN}-${NC} $disk"
        done
    fi
    
    # Возвращаем выбранные диски
    printf '%s\n' "${selected_disks[@]}"
}

# Основная функция
main() {
    echo -e "${GREEN}=== Запуск виртуальной машины Kali Linux ===${NC}"
    
    # Проверяем наличие qemu
    if ! command -v qemu-system-x86_64 &>/dev/null; then
        echo -e "${RED}Ошибка: qemu-system-x86_64 не установлен${NC}"
        exit 1
    fi
    
    # Получаем список доступных дисков
    echo -e "${BLUE}Сканирование доступных дисков...${NC}"
    mapfile -t available_disks < <(get_available_disks)
    
    # Показываем меню и получаем выбранные диски
    if [[ ${#available_disks[@]} -gt 0 ]]; then
        mapfile -t selected_disks < <(show_disk_menu "${available_disks[@]}")
    else
        echo -e "${YELLOW}Нет доступных дисков для подключения${NC}"
        selected_disks=()
    fi
    
    # Формируем аргументы для дополнительных дисков
    extra_args=""
    for disk in "${selected_disks[@]}"; do
        if [[ -n "$disk" && -e "$disk" ]]; then
            extra_args="$extra_args -drive file=$disk,format=raw,if=virtio"
        fi
    done
    
    # Показываем команду запуска
    echo -e "\n${GREEN}Запуск QEMU...${NC}"
    echo -e "${BLUE}Команда запуска:${NC}"
    echo "sudo qemu-system-x86_64 \\"
    echo "  -enable-kvm \\"
    echo "  -m 8G \\"
    echo "  -cpu host \\"
    echo "  -smp 2 \\"
    echo "  -drive file=/dev/sdc,format=raw,if=virtio \\"
    echo "  -bios /usr/share/ovmf/OVMF.fd \\"
    echo "  -vga virtio \\"
    echo "  -nic user \\"
    echo "  -usb \\"
    echo "  -device usb-tablet \\"
    for disk in "${selected_disks[@]}"; do
        if [[ -n "$disk" ]]; then
            echo "  -drive file=$disk,format=raw,if=virtio \\"
        fi
    done
    echo "  -display gtk"
    
    echo -e "\n${YELLOW}Нажмите Enter для запуска или Ctrl+C для отмены...${NC}"
    read -r < /dev/tty
    
    # Запускаем QEMU
    sudo qemu-system-x86_64 \
        -enable-kvm \
        -m 8G \
        -cpu host \
        -smp 2 \
        -drive file=/dev/sdc,format=raw,if=virtio \
        -bios /usr/share/ovmf/OVMF.fd \
        -vga virtio \
        -nic user \
        -usb \
        -device usb-tablet \
        $extra_args \
        -display gtk
}

# Запускаем основную функцию
main