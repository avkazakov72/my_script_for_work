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
    # Также проверяем, является ли диском с LVM, используемым системой
    if lsblk -n -o NAME "$disk" 2>/dev/null | grep -q "$(df / | tail -1 | awk '{print $1}' | sed 's/[0-9]//g')"; then
        return 0
    fi
    return 1
}

# Функция для получения списка всех дисков (кроме системных)
get_available_disks() {
    local disks=()
    
    # Получаем список всех дисков (не разделов)
    while read -r disk size type; do
        # Пропускаем, если это не диск (проверяем по типу)
        if [[ "$type" != "disk" ]]; then
            continue
        fi
        
        # Пропускаем системные диски
        if is_system_disk "/dev/$disk"; then
            echo -e "${YELLOW}Пропускаем системный диск: /dev/$disk${NC}" >&2
            continue
        fi
        
        # Добавляем диск в массив
        disks+=("/dev/$disk")
        
    done < <(lsblk -n -o NAME,SIZE,TYPE | grep -E "disk$")
    
    printf '%s\n' "${disks[@]}"
}

# Функция для получения списка USB устройств
get_usb_disks() {
    local usb_disks=()
    
    # Находим все USB устройства
    for dev in /dev/sd*; do
        if [[ -e "$dev" ]]; then
            # Проверяем, является ли устройство USB
            if udevadm info --query=property --name="$dev" 2>/dev/null | grep -q "ID_BUS=usb"; then
                # Проверяем, что это диск, а не раздел
                if [[ ! "$dev" =~ [0-9]$ ]]; then
                    # Проверяем, не системный ли это диск
                    if ! is_system_disk "$dev"; then
                        usb_disks+=("$dev")
                    fi
                fi
            fi
        fi
    done
    
    # Также проверяем /dev/sd* для старых систем
    if [[ ${#usb_disks[@]} -eq 0 ]]; then
        while read -r disk size type; do
            if [[ "$type" = "disk" ]]; then
                # Пытаемся определить USB по имени или другим признакам
                if [[ -L "/sys/block/$(basename "$disk")" ]]; then
                    if readlink -f "/sys/block/$(basename "$disk")" | grep -q "usb"; then
                        if ! is_system_disk "$disk"; then
                            usb_disks+=("$disk")
                        fi
                    fi
                fi
            fi
        done < <(lsblk -n -o NAME,SIZE,TYPE)
    fi
    
    printf '%s\n' "${usb_disks[@]}"
}

# Функция для отображения меню выбора дисков
show_disk_menu() {
    local disks=("$@")
    local usb_disks=($(get_usb_disks))
    
    echo -e "\n${GREEN}=== Доступные диски для подключения ===${NC}"
    echo -e "${YELLOW}Системные диски (Debian) исключены из списка${NC}\n"
    
    declare -a menu_items
    local i=1
    
    # Сначала показываем обычные диски
    echo -e "${BLUE}Обычные диски:${NC}"
    for disk in "${disks[@]}"; do
        # Получаем информацию о диске
        local model=$(sudo smartctl -i "$disk" 2>/dev/null | grep "Device Model" | cut -d: -f2 | xargs)
        local size=$(lsblk -n -o SIZE "$disk" | head -1)
        local vendor=""
        
        # Пытаемся получить вендора через udevadm
        if command -v udevadm &>/dev/null; then
            vendor=$(udevadm info --query=property --name="$disk" 2>/dev/null | grep "ID_VENDOR=" | cut -d= -f2 | xargs)
        fi
        
        # Проверяем, является ли диск USB
        local is_usb=0
        for usb in "${usb_disks[@]}"; do
            if [[ "$usb" == "$disk" ]]; then
                is_usb=1
                break
            fi
        done
        
        if [[ $is_usb -eq 0 ]]; then
            # Формируем строку для обычного диска
            local info=""
            [[ -n "$vendor" ]] && info+="Вендор: $vendor "
            [[ -n "$model" ]] && info+="Модель: $model "
            [[ -z "$info" ]] && info="Информация отсутствует"
            
            echo -e "  ${CYAN}$i.${NC} ${GREEN}$disk${NC} (${BLUE}$size${NC}) - $info"
            menu_items[$i]="$disk"
            ((i++))
        fi
    done
    
    # Затем показываем USB диски
    echo -e "\n${PURPLE}USB диски:${NC}"
    for disk in "${disks[@]}"; do
        # Проверяем, является ли диск USB
        local is_usb=0
        for usb in "${usb_disks[@]}"; do
            if [[ "$usb" == "$disk" ]]; then
                is_usb=1
                break
            fi
        done
        
        if [[ $is_usb -eq 1 ]]; then
            local model=$(sudo smartctl -i "$disk" 2>/dev/null | grep "Device Model" | cut -d: -f2 | xargs)
            local size=$(lsblk -n -o SIZE "$disk" | head -1)
            local usb_info=$(lsusb | grep -i "$(basename "$disk")" 2>/dev/null | cut -d: -f3- | xargs)
            
            echo -e "  ${CYAN}$i.${NC} ${GREEN}$disk${NC} (${BLUE}$size${NC}) - ${PURPLE}USB:${NC} ${usb_info:-"USB устройство"}"
            menu_items[$i]="$disk"
            ((i++))
        fi
    done
    
    if [[ $i -eq 1 ]]; then
        echo -e "${RED}Нет доступных дисков для подключения${NC}"
        return 1
    fi
    
    echo -e "\n${YELLOW}Введите номера дисков для подключения (через запятую или пробел)"
    echo -e "Например: 1,3,5  или 1 3 5"
    echo -e "Или 'all' для подключения всех дисков"
    echo -e "Или 'q' для выхода без запуска${NC}"
    
    read -p "> " selection
    
    if [[ "$selection" == "q" ]]; then
        echo -e "${RED}Выход...${NC}"
        exit 0
    fi
    
    local selected_disks=()
    
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
    
    if [[ ${#selected_disks[@]} -eq 0 ]]; then
        echo -e "${RED}Не выбрано ни одного диска. Запуск без дополнительных дисков.${NC}"
    else
        echo -e "\n${GREEN}Выбраны диски:${NC}"
        for disk in "${selected_disks[@]}"; do
            echo -e "  ${CYAN}-${NC} $disk"
        done
    fi
    
    # Возвращаем выбранные диски
    printf '%s\n' "${selected_disks[@]}"
}

# Функция для создания аргументов QEMU для дисков
create_disk_args() {
    local selected_disks=("$@")
    local disk_args=""
    local i=1
    
    for disk in "${selected_disks[@]}"; do
        # Проверяем, существует ли диск
        if [[ -e "$disk" ]]; then
            # Добавляем диск как virtio-blk устройство
            disk_args="$disk_args -drive file=$disk,format=raw,if=virtio,index=$i"
            ((i++))
        else
            echo -e "${RED}Предупреждение: Диск $disk не найден и будет пропущен${NC}"
        fi
    done
    
    echo "$disk_args"
}

# Основная функция
main() {
    echo -e "${GREEN}=== Запуск виртуальной машины Kali Linux ===${NC}"
    
    # Проверяем наличие необходимых программ
    if ! command -v qemu-system-x86_64 &>/dev/null; then
        echo -e "${RED}Ошибка: qemu-system-x86_64 не установлен${NC}"
        echo "Установите: sudo apt install qemu-system-x86"
        exit 1
    fi
    
    # Проверяем права на /dev/sdc
    if [[ ! -r "/dev/sdc" ]]; then
        echo -e "${YELLOW}Предупреждение: Нет прав на чтение /dev/sdc${NC}"
        echo "Попробуйте: sudo chmod 666 /dev/sdc"
    fi
    
    # Получаем список доступных дисков
    echo -e "${BLUE}Сканирование доступных дисков...${NC}"
    mapfile -t available_disks < <(get_available_disks)
    
    if [[ ${#available_disks[@]} -eq 0 ]]; then
        echo -e "${YELLOW}Нет доступных дисков для подключения${NC}"
        echo "Запуск ВМ без дополнительных дисков..."
        selected_disks=()
    else
        # Показываем меню и получаем выбранные диски
        mapfile -t selected_disks < <(show_disk_menu "${available_disks[@]}")
    fi
    
    # Создаем аргументы для дополнительных дисков
    extra_disk_args=$(create_disk_args "${selected_disks[@]}")
    
    echo -e "\n${GREEN}Запуск QEMU...${NC}"
    echo -e "${BLUE}Команда запуска:${NC}"
    echo "sudo qemu-system-x86_64 \\"
    echo " -enable-kvm \\"
    echo " -m 8G \\"
    echo " -cpu host \\"
    echo " -smp 2 \\"
    echo " -drive file=/dev/sdc,format=raw,if=virtio \\"
    echo " -bios /usr/share/ovmf/OVMF.fd \\"
    echo " -vga virtio \\"
    echo " -nic user \\"
    echo " -usb \\"
    echo " -device usb-tablet \\"
    for disk in "${selected_disks[@]}"; do
        echo " -drive file=$disk,format=raw,if=virtio \\"
    done
    echo " -display gtk"
    
    echo -e "\n${YELLOW}Нажмите Enter для запуска или Ctrl+C для отмены...${NC}"
    read -r
    
    # Запускаем QEMU с основным диском и выбранными дополнительными
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
        $extra_disk_args \
        -display gtk
}

# Запускаем основную функцию
main