#!/bin/bash
echo "Отключение сетевых папок..."
fusermount -u /mnt/WORKSERVER/BAZISMODEL
fusermount -u /mnt/WORKSERVER/INSTALL
echo "Готово"
df -h | grep  sshfs
