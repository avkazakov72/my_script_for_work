#!/bin/bash

# ============================================
# Скрипт управления Docker для Debian 13
# Расположение: ~/scripts/docker_works.sh
# ============================================

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Сброс цвета

# Функция проверки, запущен ли Docker
is_docker_running() {
    systemctl is-active --quiet docker
}

# Функция проверки наличия команды
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Функция 1: Проверка системы на наличие необходимых пакетов и программ
check_system() {
    echo -e "\n${BLUE}=== Проверка системы ===${NC}\n"
    
    echo "Проверка наличия Docker..."
    if command_exists docker; then
        echo -e "${GREEN}[OK]${NC} Docker установлен: $(docker --version)"
    else
        echo -e "${RED}[ОШИБКА]${NC} Docker не установлен"
        echo "Для установки Docker на Debian 13 выполните:"
        echo "  sudo apt update"
        echo "  sudo apt install docker.io docker-compose-plugin"
    fi
    
    echo ""
    echo "Проверка наличия Docker Compose..."
    if docker compose version >/dev/null 2>&1; then
        echo -e "${GREEN}[OK]${NC} Docker Compose (plugin) доступен"
    elif command_exists docker-compose; then
        echo -e "${GREEN}[OK]${NC} docker-compose (standalone) доступен"
    else
        echo -e "${YELLOW}[ПРЕДУПРЕЖДЕНИЕ]${NC} Docker Compose не найден"
    fi
    
    echo ""
    echo "Проверка состояния systemd..."
    if systemctl list-unit-files | grep -q docker.service; then
        echo -e "${GREEN}[OK]${NC} Служба docker.service зарегистрирована в systemd"
    else
        echo -e "${RED}[ОШИБКА]${NC} Служба docker.service не найдена"
    fi
    
    echo ""
    echo "Проверка прав пользователя..."
    if groups "$USER" | grep -q docker; then
        echo -e "${GREEN}[OK]${NC} Пользователь $USER входит в группу docker"
    else
        echo -e "${YELLOW}[ПРЕДУПРЕЖДЕНИЕ]${NC} Пользователь $USER НЕ входит в группу docker"
        echo "  Для добавления: sudo usermod -aG docker $USER"
        echo "  После добавления требуется перелогин."
    fi
}

# Функция 2: Текущее состояние работы Docker
show_status() {
    echo -e "\n${BLUE}=== Текущее состояние Docker ===${NC}\n"
    
    # Статус службы
    echo "--- Статус службы systemd ---"
    if is_docker_running; then
        echo -e "${GREEN}Docker ЗАПУЩЕН${NC}"
        systemctl status docker --no-pager -l | head -n 10
    else
        echo -e "${RED}Docker ОСТАНОВЛЕН${NC}"
        systemctl status docker --no-pager -l | head -n 10
    fi
    
    # Запущенные контейнеры
    echo ""
    echo "--- Запущенные контейнеры ---"
    if is_docker_running; then
        if [ -n "$(docker ps -q 2>/dev/null)" ]; then
            docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}"
        else
            echo "Нет запущенных контейнеров"
        fi
    else
        echo "Docker остановлен — информация о контейнерах недоступна"
    fi
}

# Функция 3: Запуск Docker
start_docker() {
    echo -e "\n${BLUE}=== Запуск Docker ===${NC}\n"
    
    if is_docker_running; then
        echo -e "${YELLOW}Docker уже запущен.${NC}"
        return
    fi
    
    echo "Запуск службы docker..."
    sudo systemctl start docker
    
    sleep 2
    
    if is_docker_running; then
        echo -e "${GREEN}Docker успешно запущен.${NC}"
    else
        echo -e "${RED}Не удалось запустить Docker.${NC}"
        echo "Проверьте журнал: journalctl -u docker.service -n 20"
    fi
}

# Функция 4: Остановка Docker
stop_docker() {
    echo -e "\n${BLUE}=== Остановка Docker ===${NC}\n"
    
    if ! is_docker_running; then
        echo -e "${YELLOW}Docker уже остановлен.${NC}"
        return
    fi
    
    echo "Внимание! Все запущенные контейнеры будут остановлены."
    read -p "Вы уверены? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Отменено."
        return
    fi
    
    echo "Остановка службы docker..."
    sudo systemctl stop docker
    
    sleep 2
    
    if ! is_docker_running; then
        echo -e "${GREEN}Docker успешно остановлен.${NC}"
    else
        echo -e "${RED}Не удалось остановить Docker.${NC}"
    fi
}

# Функция 5: Установленные контейнеры и образы
list_containers_images() {
    echo -e "\n${BLUE}=== Контейнеры и образы ===${NC}\n"
    
    if ! is_docker_running; then
        echo -e "${RED}Docker остановлен. Запустите его для просмотра информации.${NC}"
        return
    fi
    
    echo "--- Все контейнеры (включая остановленные) ---"
    if [ -n "$(docker ps -aq 2>/dev/null)" ]; then
        docker ps -a --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}"
    else
        echo "Контейнеры отсутствуют"
    fi
    
    echo ""
    echo "--- Образы ---"
    if [ -n "$(docker images -q 2>/dev/null)" ]; then
        docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}"
    else
        echo "Образы отсутствуют"
    fi
}

# Главное меню
show_menu() {
    clear
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}       Управление Docker (Debian 13)       ${NC}"
    echo -e "${BLUE}============================================${NC}"
    
    if is_docker_running; then
        echo -e " Статус: ${GREEN}Docker ЗАПУЩЕН${NC}"
    else
        echo -e " Статус: ${RED}Docker ОСТАНОВЛЕН${NC}"
    fi
    
    echo -e "${BLUE}============================================${NC}"
    echo " 1) Проверка системы на наличие пакетов"
    echo " 2) Текущее состояние работы Docker"
    echo " 3) Запуск Docker"
    echo " 4) Остановка Docker"
    echo " 5) Установленные контейнеры и образы"
    echo " 6) Выход"
    echo -e "${BLUE}============================================${NC}"
    echo -n " Выберите пункт (1-6): "
}

# Основной цикл
main() {
    while true; do
        show_menu
        read choice
        
        case "$choice" in
            1) check_system ;;
            2) show_status ;;
            3) start_docker ;;
            4) stop_docker ;;
            5) list_containers_images ;;
            6)
                echo ""
                echo "Выход из скрипта."
                if is_docker_running; then
                    echo -e "${YELLOW}Docker остаётся запущенным.${NC}"
                fi
                exit 0
                ;;
            *)
                echo -e "${RED}Неверный выбор. Введите число от 1 до 6.${NC}"
                ;;
        esac
        
        echo ""
        echo -n "Нажмите Enter для продолжения..."
        read -r
    done
}

# Запуск
main