# СИСТЕМА МОНИТОРИНГА ДОПОЛНИТЕЛЬНЫХ ДИСКОВ
# (Настроено для zsh/bash)

## КОНФИГУРАЦИЯ ДИСКОВ:

1. **DATADISK** (1.8 TB)
   - Монтируется в: `/mnt/DATADISK`
   - UUID: 48ab0853-44e1-4a6f-8a52-a164a0954edc
   - Назначение: Хранение редко используемых данных

2. **RESCUEDISK** (149 GB) 
   - Монтируется в: `/mnt/RescueData`
   - UUID: a64d99ef-e7e1-4ee6-adeb-a4966e877905
   - Назначение: Резервное копирование

## ФАЙЛЫ КОНФИГУРАЦИИ:

1. **/etc/fstab** - автоматическое монтирование при загрузке
2. **crontab** - автоматические проверки
3. **/var/log/disk_check.log** - логи мониторинга

## КОМАНДЫ ДЛЯ ZSH:

### Ручные проверки:
```zsh
# Полная проверка (требует sudo)
sudo ~/scripts/disk_monitor/disk_monitor_check_disks.sh

# Быстрая проверка
~/scripts/disk_monitor/disk_monitor_quick_check.sh

# Проверка монтирования
mount | grep -E "DATADISK|RescueData"

# Просмотр места
df -h /mnt/DATADISK /mnt/RescueData


# ПАМЯТКА ДВОЕЧНИКУ:

# Управление, в случае чАво:
# Принудительное монтирование
sudo mount -a
# Перемонтировать все
sudo umount /mnt/DATADISK /mnt/RescueData 2>/dev/null; sudo mount -a
# Просмотр логов
sudo tail -f /var/log/disk_check.log

# Просмотр конфигураций
# Показать fstab настройки
grep -E "DATADISK|RESCUEDISK" /etc/fstab
# Показать задачи мониторинга
crontab -l | grep disk_monitor
# Показать информацию о дисках
lsblk -f /dev/sda /dev/sdb
