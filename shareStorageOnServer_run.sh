#!/bin/bash

# NFS Manager Script
# Управление подключением к NFS шаре на сервере

# Конфигурация
NFS_SERVER="192.168.1.30"
NFS_SHARE="/srv/storage/VM_DISK/share-storage"
MOUNT_POINT="/mnt/share-storage-onServer"
LOG_FILE="/tmp/shareStorageOnServe.log"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция логирования
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Функция вывода сообщений
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Функция проверки доступности NFS сервера
check_nfs_server() {
    print_status "Проверка доступности NFS сервера $NFS_SERVER..."
    
    # Проверяем доступность хоста
    if ! ping -c 2 -W 2 "$NFS_SERVER" > /dev/null 2>&1; then
        print_error "Сервер $NFS_SERVER недоступен"
        return 1
    fi
    
    # Проверяем доступность NFS экспорта
    if ! showmount -e "$NFS_SERVER" 2>/dev/null | grep -q "$NFS_SHARE"; then
        print_error "NFS экспорт $NFS_SHARE не найден на сервере"
        return 1
    fi
    
    print_success "NFS сервер доступен и экспорт найден"
    return 0
}

# Функция проверки и создания точки монтирования
check_mount_point() {
    print_status "Проверка точки монтирования $MOUNT_POINT..."
    
    if [ ! -d "$MOUNT_POINT" ]; then
        print_warning "Точка монтирования не существует. Создаю..."
        if sudo mkdir -p "$MOUNT_POINT"; then
            print_success "Точка монтирования создана"
        else
            print_error "Не удалось создать точку монтирования"
            return 1
        fi
    else
        print_success "Точка монтирования существует"
    fi
    return 0
}

# Функция проверки, смонтирован ли уже раздел
is_mounted() {
    mount | grep -q "$MOUNT_POINT"
    return $?
}

# Функция монтирования NFS
mount_nfs() {
    print_status "Монтирование NFS шары..."
    
    if is_mounted; then
        print_warning "Раздел уже смонтирован"
        return 0
    fi
    
    # Монтируем с опциями для совместимости
    if sudo mount -t nfs "$NFS_SERVER:$NFS_SHARE" "$MOUNT_POINT" -o nfsvers=3,timeo=10,retrans=3; then
        print_success "NFS раздел успешно смонтирован"
        return 0
    else
        print_error "Ошибка монтирования NFS раздела"
        return 1
    fi
}

# Функция отмонтирования NFS
umount_nfs() {
    print_status "Отмонтирование NFS шары..."
    
    if ! is_mounted; then
        print_warning "Раздел не смонтирован"
        return 0
    fi
    
    # Проверяем, есть ли открытые файлы в каталоге
    if lsof "$MOUNT_POINT" 2>/dev/null | grep -q .; then
        print_warning "Обнаружены открытые файлы. Закрываю..."
        # Пытаемся принудительно отмонтировать
        if sudo umount -l "$MOUNT_POINT"; then
            print_success "Раздел отмонтирован (принудительно)"
            return 0
        fi
    fi
    
    # Обычное отмонтирование
    if sudo umount "$MOUNT_POINT"; then
        print_success "NFS раздел успешно отмонтирован"
        return 0
    else
        print_error "Ошибка отмонтирования"
        return 1
    fi
}

# Функция показа содержимого
show_content() {
    if is_mounted; then
        print_status "Содержимое $MOUNT_POINT:"
        echo ""
        ls -lah "$MOUNT_POINT"
        echo ""
        
        if [ -d "$MOUNT_POINT/ISO" ]; then
            print_status "Доступные ISO образы:"
            ls -lh "$MOUNT_POINT/ISO/" 2>/dev/null || echo "  Нет файлов"
        fi
        
        if [ -d "$MOUNT_POINT/Drivers" ]; then
            print_status "Доступные драйверы:"
            ls -lh "$MOUNT_POINT/Drivers/" 2>/dev/null || echo "  Нет файлов"
        fi
    else
        print_warning "Раздел не смонтирован"
    fi
}

# Функция проверки статуса
check_status() {
    echo ""
    echo "========================================="
    echo "Статус NFS подключения"
    echo "========================================="
    
    if is_mounted; then
        print_success "NFS раздел смонтирован в $MOUNT_POINT"
        df -h "$MOUNT_POINT" 2>/dev/null
    else
        print_warning "NFS раздел не смонтирован"
    fi
    
    echo ""
    echo "Доступность NFS сервера:"
    if ping -c 1 -W 1 "$NFS_SERVER" > /dev/null 2>&1; then
        echo "  ✓ Сервер доступен"
    else
        echo "  ✗ Сервер недоступен"
    fi
    
    if showmount -e "$NFS_SERVER" 2>/dev/null | grep -q "$NFS_SHARE"; then
        echo "  ✓ NFS экспорт найден"
    else
        echo "  ✗ NFS экспорт не найден"
    fi
    echo "========================================="
}

# Функция копирования файла в NFS
copy_to_nfs() {
    if ! is_mounted; then
        print_error "NFS раздел не смонтирован. Сначала выполните монтирование (опция 1)"
        return 1
    fi
    
    local source_file="$1"
    local target_dir="$2"
    
    if [ ! -f "$source_file" ]; then
        print_error "Файл $source_file не существует"
        return 1
    fi
    
    case "$target_dir" in
        "ISO")
            target_path="$MOUNT_POINT/ISO/"
            ;;
        "Drivers")
            target_path="$MOUNT_POINT/Drivers/"
            ;;
        *)
            print_error "Неверная директория. Используйте ISO или Drivers"
            return 1
            ;;
    esac
    
    print_status "Копирование файла в $target_dir..."
    if cp "$source_file" "$target_path"; then
        print_success "Файл скопирован в $target_path"
        return 0
    else
        print_error "Ошибка копирования"
        return 1
    fi
}

# Функция очистки лога
clean_log() {
    if [ -f "$LOG_FILE" ]; then
        rm "$LOG_FILE"
        print_success "Лог очищен"
    else
        print_warning "Лог файл не существует"
    fi
}

# Меню
show_menu() {
    echo ""
    echo "========================================="
    echo "      NFS Manager - Управление шарой"
    echo "========================================="
    echo "1. Подключить NFS раздел"
    echo "2. Отключить NFS раздел"
    echo "3. Показать содержимое"
    echo "4. Проверить статус"
    echo "5. Копировать файл в ISO директорию"
    echo "6. Копировать файл в Drivers директорию"
    echo "7. Очистить лог"
    echo "0. Выход"
    echo "========================================="
}

# Основной цикл
main() {
    while true; do
        show_menu
        read -p "Выберите опцию (0-7): " choice
        
        case $choice in
            1)
                log "Запрошено подключение NFS"
                check_nfs_server && check_mount_point && mount_nfs
                if is_mounted; then
                    print_success "NFS раздел готов к работе"
                fi
                ;;
            2)
                log "Запрошено отключение NFS"
                umount_nfs
                ;;
            3)
                log "Просмотр содержимого"
                show_content
                ;;
            4)
                check_status
                ;;
            5)
                read -p "Введите полный путь к файлу: " file_path
                copy_to_nfs "$file_path" "ISO"
                ;;
            6)
                read -p "Введите полный путь к файлу: " file_path
                copy_to_nfs "$file_path" "Drivers"
                ;;
            7)
                clean_log
                ;;
            0)
                log "Выход из программы"
                print_success "До свидания!"
                exit 0
                ;;
            *)
                print_error "Неверная опция. Попробуйте снова."
                ;;
        esac
        
        echo ""
        read -p "Нажмите Enter для продолжения..."
    done
}

# Запуск скрипта
main
