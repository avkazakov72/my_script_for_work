#!/bin/bash
echo "=== Маленькая сетевая диагностика ==="
echo -e "\n1. Наши интерфейсики:"
ip -br a

echo -e "\n2. Маршруты IPv4:"
ip route

echo -e "\n3. Маршруты IPv6:"
ip -6 route 2>/dev/null || echo "IPv6 отключен/нет их"

echo -e "\n4. Подключения NetworkManager:"
nmcli -t -f NAME,DEVICE,TYPE,STATE connection show

echo -e "\n5. Устройства:"
nmcli -t -f DEVICE,TYPE,STATE device status

echo -e "\n6. Чир с нтернетом:"
ping -c 2 8.8.8.8 2>&1 | tail -3
