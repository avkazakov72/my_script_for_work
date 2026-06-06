#!/bin/bash

# Скрипт для запуска Windows 11 с физического диска nvme1n1
# Использует существующий мост br0
# Сохраните как: ~/scripts/vm_Win11_bridge.sh

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${GREEN}=== Запуск Windows 11 с физического диска nvme1n1 ===${NC}"
echo

# Проверяем, существует ли диск
if [ ! -e "/dev/nvme1n1" ]; then
    echo -e "${RED}Ошибка: Диск /dev/nvme1n1 не найден!${NC}"
    exit 1
fi

# Проверяем существование моста
if ! ip link show br0 &>/dev/null; then
    echo -e "${RED}Ошибка: Мост br0 не найден!${NC}"
    echo "Сначала создайте мост: sudo ip link add name br0 type bridge && sudo ip link set br0 up && sudo ip link set enp6s0 master br0 && sudo dhclient br0"
    exit 1
fi

echo -e "${GREEN}Мост br0 найден:${NC}"
ip a show br0 | grep inet
echo

# Проверяем OVMF
OVMF="/usr/share/ovmf/OVMF.fd"
if [ ! -f "$OVMF" ]; then
    echo -e "${YELLOW}OVMF не найден, устанавливаем...${NC}"
    sudo apt install -y ovmf
fi

# Спрашиваем о дополнительных дисках
echo -e "${BLUE}Доступные диски для подключения:${NC}"
echo "----------------"
lsblk -o NAME,SIZE,TYPE,MODEL,MOUNTPOINT | grep -E "disk|part" | grep -v "nvme0n1" | grep -v "nvme1n1"
echo "----------------"
echo

echo -e "${YELLOW}Введите пути к дополнительным дискам (например: /dev/sda /dev/sdb)"
echo "Или нажмите Enter для запуска без дополнительных дисков:${NC}"
read -p "> " disk_input

# Формируем список дополнительных дисков
extra_disks=()
if [ -n "$disk_input" ]; then
    for disk in $disk_input; do
        if [ -e "$disk" ]; then
            extra_disks+=("$disk")
            echo -e "${GREEN}✓ Будет подключен диск: $disk${NC}"
        else
            echo -e "${RED}✗ Диск $disk не найден${NC}"
        fi
    done
fi

# Спрашиваем о TPM
echo
echo -e "${BLUE}Windows 11 требует TPM 2.0.${NC}"
echo "1) Запустить с TPM (требуется swtpm)"
echo "2) Запустить без TPM (может не загрузиться Windows 11)"
read -p "Выберите [1/2]: " tpm_choice

TPM_ARGS=""
TPM_PID=""

if [ "$tpm_choice" = "1" ]; then
    if command -v swtpm &>/dev/null; then
        TPM_DIR="/tmp/tpm-win11-$$"
        mkdir -p "$TPM_DIR"
        
        echo -e "${GREEN}Запускаем TPM эмулятор...${NC}"
        sudo swtpm socket \
            --tpmstate dir="$TPM_DIR" \
            --ctrl type=unixio,path="$TPM_DIR/swtpm-sock" \
            --tpm2 \
            --log level=20 &
        
        TPM_PID=$!
        sleep 1
        
        TPM_ARGS="-chardev socket,id=chrtpm,path=$TPM_DIR/swtpm-sock \
                  -tpmdev emulator,id=tpm0,chardev=chrtpm \
                  -device tpm-tis,tpmdev=tpm0"
        
        echo -e "${GREEN}TPM эмулятор запущен${NC}"
    else
        echo -e "${YELLOW}swtpm не установлен. Установите: sudo apt install swtpm${NC}"
        echo "Запускаем без TPM..."
    fi
else
    echo -e "${YELLOW}Запуск без TPM${NC}"
fi

# Формируем команду запуска
echo
echo -e "${GREEN}Формируем команду запуска...${NC}"

QEMU_CMD="sudo qemu-system-x86_64 \
    -enable-kvm \
    -machine type=q35,accel=kvm \
    -cpu host \
    -smp 4 \
    -m 8G \
    -drive file=/dev/nvme1n1,format=raw,if=virtio \
    -bios $OVMF \
    -vga virtio \
    -display gtk \
    -usb \
    -device usb-tablet"

# Добавляем TPM
if [ -n "$TPM_ARGS" ]; then
    QEMU_CMD="$QEMU_CMD $TPM_ARGS"
fi

# Добавляем дополнительные диски
for disk in "${extra_disks[@]}"; do
    QEMU_CMD="$QEMU_CMD -drive file=$disk,format=raw,if=virtio"
done

# Добавляем сеть (используем существующий мост)
QEMU_CMD="$QEMU_CMD -netdev bridge,id=net0,br=br0 -device virtio-net-pci,netdev=net0"

# Показываем команду
echo
echo -e "${CYAN}Команда запуска:${NC}"
echo "$QEMU_CMD"
echo
echo -e "${YELLOW}Нажмите Enter для запуска Windows 11...${NC}"
read

# Запускаем
eval $QEMU_CMD

# После завершения ВМ, очищаем TPM
if [ -n "$TPM_PID" ]; then
    echo -e "${YELLOW}Останавливаем TPM эмулятор...${NC}"
    sudo kill $TPM_PID 2>/dev/null
    sudo rm -rf "$TPM_DIR"
fi

echo -e "${GREEN}Виртуальная машина остановлена${NC}"