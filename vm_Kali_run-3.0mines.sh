#!/bin/bash

# Использование: sudo ./vm_Kali_run.sh [диск1] [диск2] ...

echo "=== Запуск виртуальной машины Kali Linux ==="
echo

# Если аргументы не переданы, показываем список и завершаем работу
if [ $# -eq 0 ]; then
    echo "Использование: $0 /dev/sdX /dev/sdY ..."
    echo
    echo "Доступные диски:"
    echo "----------------"
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT | grep -E "disk|part" | grep -v "nvme0n1"
    echo "----------------"
    echo
    echo "Пример: sudo $0 /dev/sda /dev/sdb"
    exit 1
fi

# Проверяем переданные диски
valid_disks=()
for disk in "$@"; do
    if [ -e "$disk" ]; then
        valid_disks+=("$disk")
        echo "Будет подключен диск: $disk"
    else
        echo "Предупреждение: Диск $disk не найден"
    fi
done

echo
echo "Запуск QEMU..."
echo

# Формируем команду
cmd="sudo qemu-system-x86_64 \
    -enable-kvm \
    -m 8G \
    -cpu host \
    -smp 2 \
    -drive file=/dev/sdc,format=raw,if=virtio \
    -bios /usr/share/ovmf/OVMF.fd \
    -vga virtio \
    -nic user \
    -usb \
    -device usb-tablet"

# Добавляем дополнительные диски
for disk in "${valid_disks[@]}"; do
    cmd="$cmd -drive file=$disk,format=raw,if=virtio"
done

cmd="$cmd -display gtk"

# Запускаем
eval $cmd