#!/bin/bash
# Скрипт управления пользователями файлового сервера Samba
# Обновленная версия с исправлениями для новой структуры smb.conf
# Author: System Administrator
# Version: 2.0

CONFIG_FILE="/etc/samba-user-manager.conf"
LOG_FILE="/var/log/samba-user-manager.log"
WORKGROUP="workgroup"
BASE_DIRS=("/srv/BAZISMODEL" "/srv/INSTALL" "/srv/ARCHIVE")

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция логирования
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
    echo -e "$2$1${NC}"
}

# Функция проверки прав root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log "Этот скрипт должен запускаться с правами root!" "$RED"
        exit 1
    fi
}

# Функция проверки конфигурации Samba
check_samba_config() {
    if testparm -s >/dev/null 2>&1; then
        log "Конфигурация Samba корректна" "$GREEN"
        return 0
    else
        log "ОШИБКА: Конфигурация Samba содержит ошибки!" "$RED"
        return 1
    fi
}

# Функция создания конфигурационного файла
create_config() {
    cat > "$CONFIG_FILE" << EOF
# Конфигурация менеджера пользователей Samba
WORKGROUP="workgroup"
BASE_DIRS=("/srv/BAZISMODEL" "/srv/INSTALL" "/srv/ARCHIVE")
BACKUP_DIR="/backup/users"
KEEP_BACKUP_DAYS=30
EOF
    log "Создан конфигурационный файл: $CONFIG_FILE" "$GREEN"
}

# Функция загрузки конфигурации
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    else
        create_config
    fi
}

# Функция создания резервной копии пользователя
backup_user() {
    local username="$1"
    local backup_dir="$BACKUP_DIR/$(date +%Y%m%d)"
    
    mkdir -p "$backup_dir"
    
    # Архивируем домашнюю директорию
    if [[ -d "/home/$username" ]]; then
        tar -czf "$backup_dir/${username}_home.tar.gz" -C "/home" "$username" 2>/dev/null
    fi
    
    # Архивируем папку в ARCHIVE
    if [[ -d "/srv/ARCHIVE/$username" ]]; then
        tar -czf "$backup_dir/${username}_archive.tar.gz" -C "/srv/ARCHIVE" "$username" 2>/dev/null
    fi
    
    # Сохраняем информацию о пользователе
    getent passwd "$username" > "$backup_dir/${username}_info.txt" 2>/dev/null
    getent group "$WORKGROUP" >> "$backup_dir/${username}_info.txt" 2>/dev/null
    
    log "Создана резервная копия пользователя $username в $backup_dir" "$BLUE"
}

# Функция очистки старых бэкапов
clean_old_backups() {
    if [[ -d "$BACKUP_DIR" ]]; then
        find "$BACKUP_DIR" -type d -mtime +$KEEP_BACKUP_DAYS -exec rm -rf {} \; 2>/dev/null
        log "Очищены резервные копии старше $KEEP_BACKUP_DAYS дней" "$BLUE"
    fi
}

# Функция добавления шары Samba для личного архива
add_samba_share() {
    local username="$1"
    local smb_conf="/etc/samba/smb.conf"
    local temp_conf="/tmp/smb.conf.tmp"
    
    # Проверяем, есть ли уже такая секция
    if grep -q "\[${username}_archive\]" "$smb_conf"; then
        log "Сетевая папка ${username}_archive уже существует в Samba" "$YELLOW"
        return 0
    fi
    
    # Создаем временный файл
    cp "$smb_conf" "$temp_conf"
    
    # Находим место для вставки (перед первым [archive] разделом или в конец)
    if grep -q "^\[ARCHIVE\]" "$temp_conf"; then
        # Вставляем перед [ARCHIVE]
        awk -v user="$username" '
        /^\[ARCHIVE\]/ {
            print "[" user "_archive]"
            print "    comment = Личный архив " user
            print "    path = /srv/ARCHIVE/" user
            print "    browseable = no"
            print "    read only = no"
            print "    valid users = " user ", root, aleksey"
            print "    create mask = 0770"
            print "    directory mask = 0770"
            print ""
        }
        { print }
        ' "$temp_conf" > "$smb_conf"
    else
        # Добавляем в конец файла
        cat >> "$smb_conf" << EOF

[${username}_archive]
    comment = Личный архив $username
    path = /srv/ARCHIVE/$username
    browseable = no
    read only = no
    valid users = $username, root, aleksey
    create mask = 0770
    directory mask = 0770
EOF
    fi
    
    # Удаляем временный файл
    rm -f "$temp_conf"
    
    # Проверяем конфигурацию
    if check_samba_config; then
        log "Добавлена сетевая папка ${username}_archive в Samba" "$GREEN"
        return 0
    else
        log "ОШИБКА: Не удалось добавить сетевую папку ${username}_archive" "$RED"
        return 1
    fi
}

# Функция удаления шары Samba
remove_samba_share() {
    local username="$1"
    local smb_conf="/etc/samba/smb.conf"
    local temp_conf="/tmp/smb.conf.tmp"
    
    # Удаляем секцию из конфига
    if [[ -f "$smb_conf" ]]; then
        awk -v user="$username" '
        /^\[' user '_archive\]/ { skip=1; next }
        skip && /^\[/ { skip=0 }
        !skip { print }
        ' "$smb_conf" > "$temp_conf"
        
        # Проверяем что конфиг не испорчен
        if testparm -s "$temp_conf" >/dev/null 2>&1; then
            mv "$temp_conf" "$smb_conf"
            log "Удалена сетевая папка ${username}_archive из Samba" "$GREEN"
        else
            log "Ошибка: Конфигурация Samba повреждена при удалении пользователя $username" "$RED"
            rm -f "$temp_conf"
            return 1
        fi
    fi
    return 0
}

# Функция создания пользователя
create_user() {
    echo
    log "=== СОЗДАНИЕ НОВОГО ПОЛЬЗОВАТЕЛЯ ===" "$BLUE"
    
    read -p "Введите имя пользователя: " username
    
    # Проверка существования пользователя
    if id "$username" &>/dev/null; then
        log "Пользователь $username уже существует!" "$RED"
        return 1
    fi
    
    # Создание пользователя системы
    useradd -m -s /bin/bash -G "$WORKGROUP" "$username"
    if [[ $? -ne 0 ]]; then
        log "Ошибка при создании пользователя $username" "$RED"
        return 1
    fi
    
    # Установка пароля системы
    passwd "$username"
    if [[ $? -ne 0 ]]; then
        log "Ошибка при установке пароля системы" "$RED"
        userdel -r "$username" 2>/dev/null
        return 1
    fi
    
    # Добавление в Samba
    echo "Установите пароль Samba для пользователя $username:"
    smbpasswd -a "$username"
    if [[ $? -ne 0 ]]; then
        log "Ошибка при добавлении пользователя в Samba" "$RED"
        return 1
    fi
    
    # Создание личной папки в ARCHIVE
    mkdir -p "/srv/ARCHIVE/$username"
    chown "$username:$WORKGROUP" "/srv/ARCHIVE/$username"
    chmod 770 "/srv/ARCHIVE/$username"
    
    # Настройка прав для существующих каталогов
    for dir in "${BASE_DIRS[@]}"; do
        if [[ -d "$dir" ]]; then
            setfacl -m "u:$username:rwx" "$dir" 2>/dev/null
        fi
    done
    
    # Специальные права для BAZISMODEL (запрет удаления)
    if [[ -d "/srv/BAZISMODEL" ]]; then
        setfacl -d -m "u:$username:rw-" "/srv/BAZISMODEL" 2>/dev/null
    fi
    
    # Добавляем сетевую папку в Samba
    if add_samba_share "$username"; then
        # Перезагружаем Samba если конфиг корректен
        systemctl reload smbd
    else
        log "ВНИМАНИЕ: Пользователь создан, но сетевая папка не добавлена. Проверьте конфиг Samba вручную." "$YELLOW"
    fi
    
    log "Пользователь $username успешно создан!" "$GREEN"
    log "Домашняя директория: /home/$username" "$GREEN"
    log "Архивная директория: /srv/ARCHIVE/$username" "$GREEN"
    log "Пользователь добавлен в группу: $WORKGROUP" "$GREEN"
    
    echo
    log "=== ИНФОРМАЦИЯ ДЛЯ ПОЛЬЗОВАТЕЛЯ ===" "$YELLOW"
    log "Логин для доступа: $username" "$YELLOW"
    log "Сетевые ресурсы:" "$YELLOW"
    log "  - BAZISMODEL (общая рабочая папка)" "$YELLOW"
    log "  - INSTALL (установочные файлы)" "$YELLOW"
    log "  - ARCHIVE (архив, видна только своя папка)" "$YELLOW"
    log "  - ${username}_archive (личный архив)" "$YELLOW"
    echo
}

# Функция удаления пользователя из Samba (блокировка)
disable_user() {
    echo
    log "=== БЛОКИРОВКА ПОЛЬЗОВАТЕЛЯ ===" "$BLUE"
    
    read -p "Введите имя пользователя для блокировки: " username
    
    # Проверка существования пользователя
    if ! id "$username" &>/dev/null; then
        log "Пользователь $username не существует!" "$RED"
        return 1
    fi
    
    # Создаем резервную копию
    backup_user "$username"
    
    # Блокировка учетной записи системы
    passwd -l "$username"
    
    # Блокировка в Samba
    smbpasswd -d "$username"
    
    # Удаление из группы workgroup
    gpasswd -d "$username" "$WORKGROUP"
    
    # Закрытие всех активных сессий
    pkill -u "$username" 2>/dev/null
    
    # Изменение прав доступа к папкам
    for dir in "${BASE_DIRS[@]}"; do
        if [[ -d "$dir" ]]; then
            setfacl -x "u:$username" "$dir" 2>/dev/null
        fi
    done
    
    # Блокировка личной папки в ARCHIVE
    if [[ -d "/srv/ARCHIVE/$username" ]]; then
        chown root:root "/srv/ARCHIVE/$username"
        chmod 700 "/srv/ARCHIVE/$username"
        setfacl -b "/srv/ARCHIVE/$username" 2>/dev/null
    fi
    
    log "Пользователь $username заблокирован!" "$GREEN"
    log "Доступ к системе и сетевым ресурсам закрыт" "$GREEN"
    log "Резервная копия создана в $BACKUP_DIR" "$GREEN"
    
    echo
    log "Для полного удаления пользователя используйте опцию 3" "$YELLOW"
}

# Функция полного удаления пользователя
delete_user() {
    echo
    log "=== ПОЛНОЕ УДАЛЕНИЕ ПОЛЬЗОВАТЕЛЯ ===" "$RED"
    
    read -p "Введите имя пользователя для полного удаления: " username
    
    # Проверка существования пользователя
    if ! id "$username" &>/dev/null; then
        log "Пользователь $username не существует!" "$RED"
        return 1
    fi
    
    # Создаем финальную резервную копию
    backup_user "$username"
    
    # Подтверждение удаления
    echo -e "${RED}ВНИМАНИЕ: Это действие необратимо!${NC}"
    echo -e "${RED}Будут удалены все данные пользователя:${NC}"
    echo -e "${RED}- Учетная запись системы${NC}"
    echo -e "${RED}- Домашняя директория /home/$username${NC}"
    echo -e "${RED}- Папка в архиве /srv/ARCHIVE/$username${NC}"
    echo -e "${RED}- Записи в Samba${NC}"
    echo
    
    read -p "Вы уверены? (y/N): " confirmation
    if [[ ! "$confirmation" =~ ^[Yy]$ ]]; then
        log "Удаление отменено" "$YELLOW"
        return 0
    fi
    
    # Удаляем сетевую папку из Samba
    if remove_samba_share "$username"; then
        systemctl reload smbd
    fi
    
    # Полное удаление пользователя
    smbpasswd -x "$username" 2>/dev/null    # Удаление из Samba
    userdel -r "$username" 2>/dev/null      # Удаление из системы с домашней директорией
    
    # Удаление папки в ARCHIVE (если не удалилась автоматически)
    if [[ -d "/srv/ARCHIVE/$username" ]]; then
        rm -rf "/srv/ARCHIVE/$username"
    fi
    
    # Очистка ACL
    for dir in "${BASE_DIRS[@]}"; do
        if [[ -d "$dir" ]]; then
            setfacl -x "u:$username" "$dir" 2>/dev/null
        fi
    done
    
    log "Пользователь $username полностью удален из системы!" "$GREEN"
    log "Резервная копия сохранена в $BACKUP_DIR" "$GREEN"
}

# Функция просмотра пользователей
list_users() {
    echo
    log "=== СПИСОК ПОЛЬЗОВАТЕЛЕЙ В ГРУППЕ $WORKGROUP ===" "$BLUE"
    
    echo "Системные пользователи в группе $WORKGROUP:"
    getent group "$WORKGROUP" | cut -d: -f4 | tr ',' '\n' | sort
    
    echo
    echo "Пользователи Samba:"
    pdbedit -L -v 2>/dev/null | grep "Unix username:" | awk '{print $3}' | sort || echo "Samba users not available"
    
    echo
    echo "Сетевые папки Samba:"
    smbclient -L localhost -U% 2>/dev/null | grep -E "^\s+[A-Z]" | head -10 || echo "Samba shares not available"
    
    echo
    log "Статус системных каталогов:" "$BLUE"
    for dir in "${BASE_DIRS[@]}"; do
        if [[ -d "$dir" ]]; then
            echo "  $dir: $(stat -c "%A %U %G" "$dir")"
        else
            echo "  $dir: НЕ СУЩЕСТВУЕТ"
        fi
    done
}

# Функция проверки целостности
check_system() {
    echo
    log "=== ПРОВЕРКА ЦЕЛОСТНОСТИ СИСТЕМЫ ===" "$BLUE"
    
    # Проверка существования группы
    if getent group "$WORKGROUP" >/dev/null; then
        log "Группа $WORKGROUP: OK" "$GREEN"
    else
        log "Группа $WORKGROUP: ОТСУТСТВУЕТ" "$RED"
    fi
    
    # Проверка каталогов
    for dir in "${BASE_DIRS[@]}"; do
        if [[ -d "$dir" ]]; then
            log "Каталог $dir: OK" "$GREEN"
        else
            log "Каталог $dir: ОТСУТСТВУЕТ" "$RED"
        fi
    done
    
    # Проверка службы Samba
    if systemctl is-active smbd >/dev/null; then
        log "Служба Samba: ЗАПУЩЕНА" "$GREEN"
    else
        log "Служба Samba: НЕ АКТИВНА" "$RED"
    fi
    
    # Проверка конфигурации Samba
    check_samba_config
}

# Главное меню
main_menu() {
    while true; do
        echo
        log "=== МЕНЕДЖЕР ПОЛЬЗОВАТЕЛЕЙ SAMBA v2.0 ===" "$BLUE"
        echo "1. Создать нового пользователя"
        echo "2. Заблокировать пользователя"
        echo "3. Полностью удалить пользователя (только root)"
        echo "4. Просмотр списка пользователей"
        echo "5. Проверка целостности системы"
        echo "6. Очистка старых резервных копий"
        echo "0. Выход"
        echo
        
        read -p "Выберите действие [0-6]: " choice
        
        case $choice in
            1) create_user ;;
            2) disable_user ;;
            3) delete_user ;;
            4) list_users ;;
            5) check_system ;;
            6) clean_old_backups ;;
            0) log "Выход из программы" "$GREEN"; exit 0 ;;
            *) log "Неверный выбор!" "$RED" ;;
        esac
        
        read -p "Нажмите Enter для продолжения..."
    done
}

# Инициализация
init_system() {
    check_root
    load_config
    
    # Создаем необходимые директории
    mkdir -p "${BASE_DIRS[@]}"
    mkdir -p "$BACKUP_DIR"
    
    # Проверяем существование группы workgroup
    if ! getent group "$WORKGROUP" >/dev/null; then
        groupadd "$WORKGROUP"
        log "Создана группа $WORKGROUP" "$GREEN"
    fi
}

# Запуск скрипта
init_system
main_menu