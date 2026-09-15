#!/bin/bash
# ============================================
# Запуск MAX в Docker с полной подготовкой
# Расположение: ~/scripts/max_work.sh
# ============================================

set -e  # Прерывать при ошибках

# ------- Настройки -------
PROJECT_DIR="$HOME/docker/max-docker"
COMPOSE_FILE="$PROJECT_DIR/docker-compose.yaml"
IMAGE_NAME="max-docker-max-messenger"
CONTAINER_NAME="max-messenger"
USER_ID="$(id -u)"

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ------- Функции -------
info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()   { echo -e "${RED}[ERR]${NC} $*" >&2; }

# 1. Проверка, что Docker установлен
check_docker_installed() {
    if ! command -v docker >/dev/null 2>&1; then
        err "Docker не установлен. Установите: sudo apt install docker.io docker-compose"
        exit 1
    fi
    ok "Docker установлен: $(docker --version)"
}

# 2. Проверка и запуск Docker daemon
ensure_docker_running() {
    if systemctl is-active --quiet docker; then
        ok "Docker daemon уже запущен"
        return 0
    fi

    info "Docker daemon не запущен. Запускаем..."
    if ! sudo systemctl start docker; then
        err "Не удалось запустить Docker. Проверьте: systemctl status docker"
        exit 1
    fi

    # Ждём, пока daemon поднимется
    for i in {1..10}; do
        if docker info >/dev/null 2>&1; then
            ok "Docker daemon запущен"
            return 0
        fi
        sleep 1
    done

    err "Docker daemon не отвечает после запуска"
    exit 1
}

# 3. Проверка наличия образа MAX
ensure_image_built() {
    if docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
        ok "Образ $IMAGE_NAME найден"
        return 0
    fi

    warn "Образ $IMAGE_NAME отсутствует. Собираем..."
    if [ ! -f "$COMPOSE_FILE" ]; then
        err "Не найден $COMPOSE_FILE"
        exit 1
    fi

    cd "$PROJECT_DIR"
    if ! docker-compose build; then
        err "Сборка образа не удалась"
        exit 1
    fi
    ok "Образ собран"
}

# 4. Проверка, что графическая сессия доступна
ensure_x11_ready() {
    if [ -z "$DISPLAY" ]; then
        err "Переменная DISPLAY не установлена. Запускайте скрипт из графической сессии."
        exit 1
    fi

    if [ ! -S /tmp/.X11-unix/X0 ] && [ ! -S "/tmp/.X11-unix/X${DISPLAY#:}" ]; then
        warn "X11-сокет не найден, но продолжаем — возможно, используется Wayland"
    fi

    info "Разрешаем X11-доступ для Docker..."
    xhost +local:docker >/dev/null
    ok "X11-доступ разрешён"
}

# 5. Проверка D-Bus (для keyring)
ensure_dbus_ready() {
    local bus_path="/run/user/$USER_ID/bus"
    if [ ! -S "$bus_path" ]; then
        warn "D-Bus сокет не найден: $bus_path"
        warn "Авторизация в MAX не будет сохраняться. Запустите скрипт из графической сессии."
    else
        ok "D-Bus сокет найден: $bus_path"
    fi
}

# 6. Остановка старого контейнера, если остался
cleanup_old_container() {
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        warn "Найден старый контейнер $CONTAINER_NAME. Удаляем..."
        docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
    fi
}

# 7. Запуск контейнера и ожидание выхода
run_max() {
    info "Запускаем MAX..."
    cd "$PROJECT_DIR"

    # docker-compose up в foreground — ждём, пока пользователь не закроет MAX
    if docker-compose up; then
        ok "MAX завершён"
    else
        warn "MAX завершился с ненулевым кодом"
    fi
}

# 8. Остановка и удаление контейнера
cleanup_after_exit() {
    info "Останавливаем и удаляем контейнер..."
    cd "$PROJECT_DIR"
    docker-compose down >/dev/null 2>&1 || true
    ok "Контейнер удалён"
}

# 9. Отзыв X11-разрешения
revoke_x11() {
    info "Отзываем X11-доступ для Docker..."
    xhost -local:docker >/dev/null 2>&1 || true
    ok "X11-доступ отозван"
}

# 10. (Опционально) Остановка Docker daemon
stop_docker_if_asked() {
    echo ""
    read -r -p "Остановить Docker daemon? (y/N): " answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        info "Останавливаем Docker daemon..."
        sudo systemctl stop docker
        ok "Docker daemon остановлен"
    else
        info "Docker daemon оставлен запущенным"
    fi
}

# ------- Главный поток -------
main() {
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}        Запуск MAX в Docker                 ${NC}"
    echo -e "${BLUE}============================================${NC}"

    check_docker_installed
    ensure_docker_running
    ensure_image_built
    ensure_x11_ready
    ensure_dbus_ready
    cleanup_old_container

    # Trap: гарантированно уберём контейнер и X11-доступ при выходе
    trap 'cleanup_after_exit; revoke_x11' EXIT INT TERM

    run_max

    # После выхода из MAX
    cleanup_after_exit
    revoke_x11

    # Снять trap — уже сделали
    trap - EXIT INT TERM

    stop_docker_if_asked

    echo ""
    ok "Готово. Хорошего дня!"
}

main "$@"