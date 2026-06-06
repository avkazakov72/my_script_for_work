#!/bin/bash

# Создаем мост br0
sudo brctl addbr br0
# Добавляем физический интерфейс в мост
sudo brctl addif br0 enp6s0
# Поднимаем мост
sudo ip link set br0 up
# Удаляем IP с физического интерфейса
sudo ip addr flush dev enp6s0
# Получаем IP для моста через DHCP
sudo dhclient br0
# Проверяем результат
ip a show br0
