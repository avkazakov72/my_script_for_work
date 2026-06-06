#!/bin/bash
# Скрипт: connect_server.sh

SERVER_IP="46.229.182.169"
USERNAME="aleksey"
PORT="2222"
LOCAL_DIR="/mnt/WORKSERVER"

echo "=== ПОДКЛЮЧЕНИЕ К УДАЛЕННОМУ СЕРВЕРУ " $SERVER_IP " ==="
echo "=== Подключение пользователя" $USERNAME " с его паролем и правами доступа"

# Монтируем
echo "Подключение BAZISMODEL..."
sshfs -p $PORT $USERNAME"@"$SERVER_IP:/srv/BAZISMODEL $LOCAL_DIR/BAZISMODEL

if [ $? -eq 0 ]; then
    echo "✓ BAZISMODEL подключен"
else
    echo "✗ Ошибка BAZISMODEL"
fi

echo "Подключение INSTALL..."
sshfs -p $PORT $USERNAME"@"$SERVER_IP:/srv/INSTALL $LOCAL_DIR/INSTALL

if [ $? -eq 0 ]; then
    echo "✓ INSTALL подключен"
else
    echo "✗ Ошибка INSTALL"
fi

echo "=== ГОТОВО ==="
echo "Папки доступны в: $LOCAL_DIR/"
ls -la $LOCAL_DIR/
