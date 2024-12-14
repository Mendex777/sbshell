#!/bin/bash

# Определить цвета
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # Без цвета

# Директория для скриптов и временная директория
SCRIPT_DIR="/etc/sing-box/scripts"
TEMP_DIR="/tmp/sing-box"

# Базовый URL для скриптов
BASE_URL="https://raw.githubusercontent.com/Mendex777/sbshell/refs/heads/master/debian"

# URL для скачивания меню скрипта
MENU_SCRIPT_URL="$BASE_URL/menu.sh"

# Уведомить пользователя о проверке версии
echo -e "${CYAN}Проверка версии, пожалуйста, подождите...${NC}"

# Убедиться, что директории для скриптов и временная директория существуют и установить права
sudo mkdir -p "$SCRIPT_DIR"
sudo mkdir -p "$TEMP_DIR"
sudo chown "$(whoami)":"$(whoami)" "$SCRIPT_DIR"
sudo chown "$(whoami)":"$(whoami)" "$TEMP_DIR"

# Скачать удаленный скрипт во временную директорию
wget -q -O "$TEMP_DIR/menu.sh" "$MENU_SCRIPT_URL"

# Проверить, успешно ли скачался скрипт
if ! [ -f "$TEMP_DIR/menu.sh" ]; then
    echo -e "${RED}Скачивание удаленного скрипта не удалось, проверьте соединение с интернетом.${NC}"
    exit 1
fi

# Получить локальную и удаленную версии скрипта
LOCAL_VERSION=$(grep '^# 版本:' "$SCRIPT_DIR/menu.sh" | awk '{print $3}')
REMOTE_VERSION=$(grep '^# 版本:' "$TEMP_DIR/menu.sh" | awk '{print $3}')

# Проверить, успешно ли получена удаленная версия
if [ -z "$REMOTE_VERSION" ]; then
    echo -e "${RED}Получение удаленной версии не удалось, проверьте соединение с интернетом.${NC}"
    read -rp "Повторить попытку? (y/n): " retry_choice
    if [[ "$retry_choice" =~ ^[Yy]$ ]]; then
        wget -q -O "$TEMP_DIR/menu.sh" "$MENU_SCRIPT_URL"
        REMOTE_VERSION=$(grep '^# 版本:' "$TEMP_DIR/menu.sh" | awk '{print $3}')
        if [ -z "$REMOTE_VERSION" ]; then
            echo -e "${RED}Получение удаленной версии не удалось, проверьте соединение с интернетом и повторите попытку. Возврат в меню.${NC}"
            rm -rf "$TEMP_DIR"
            exit 1
        fi
    else
        echo -e "${RED}Проверьте соединение с интернетом и повторите попытку. Возврат в меню.${NC}"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
fi

# Вывести обнаруженные версии
echo -e "${CYAN}Обнаруженные версии: локальная версия $LOCAL_VERSION, удаленная версия $REMOTE_VERSION${NC}"

# Сравнить номера версий
if [ "$LOCAL_VERSION" == "$REMOTE_VERSION" ]; then
    echo -e "${GREEN}Скрипт уже обновлен до последней версии.${NC}"
    rm -rf "$TEMP_DIR"
    exit 0
else
    echo -e "${RED}Обнаружена новая версия, подготовка к обновлению.${NC}"
fi

# Список скриптов
SCRIPTS=(
    "check_environment.sh"
    "set_network.sh"
    "check_update.sh"
    "install_singbox.sh"
    "manual_input.sh"
    "manual_update.sh"
    "auto_update.sh"
    "configure_tproxy.sh"
    "configure_tun.sh"
    "start_singbox.sh"
    "stop_singbox.sh"
    "clean_nft.sh"
    "set_defaults.sh"
    "commands.sh"
    "switch_mode.sh"
    "manage_autostart.sh"
    "check_config.sh"
    "update_scripts.sh"
    "menu.sh"
)

# Скачать и настроить один скрипт с логикой повторных попыток
download_script() {
    local SCRIPT="$1"
    local RETRIES=3
    local RETRY_DELAY=5

    for ((i=1; i<=RETRIES; i++)); do
        if wget -q -O "$SCRIPT_DIR/$SCRIPT" "$BASE_URL/$SCRIPT"; then
            chmod +x "$SCRIPT_DIR/$SCRIPT"
            return 0
        else
            sleep "$RETRY_DELAY"
        fi
    done

    echo -e "${RED}Скачивание $SCRIPT не удалось, проверьте соединение с интернетом.${NC}"
    return 1
}

# Параллельное скачивание скриптов
parallel_download_scripts() {
    local pids=()
    for SCRIPT in "${SCRIPTS[@]}"; do
        download_script "$SCRIPT" &
        pids+=("$!")
    done

    for pid in "${pids[@]}"; do
        wait "$pid"
    done
}

# Обычное обновление
function regular_update() {
    echo -e "${CYAN}Очистка кэша, пожалуйста, подождите...${NC}"
    rm -f "$SCRIPT_DIR"/*.sh
    echo -e "${CYAN}Выполнение обычного обновления, пожалуйста, подождите...${NC}"
    parallel_download_scripts
    echo -e "${CYAN}Обновление скриптов завершено.${NC}"
}

# Сброс и обновление
function reset_update() {
    echo -e "${RED}Остановка sing-box и сброс всех данных, пожалуйста, подождите...${NC}"
    sudo bash "$SCRIPT_DIR/clean_nft.sh"
    sudo rm -rf /etc/sing-box
    echo -e "${CYAN}Папка sing-box удалена.${NC}"
    echo -e "${CYAN}Повторное скачивание скриптов, пожалуйста, подождите...${NC}"
    bash <(curl -s "$MENU_SCRIPT_URL")
}

# Уведомить пользователя и подтвердить выбор
echo -e "${CYAN}Пожалуйста, выберите способ обновления:${NC}"
echo -e "${GREEN}1. Обычное обновление${NC}"
echo -e "${GREEN}2. Сброс и обновление${NC}"
read -rp "Пожалуйста, выберите действие: " update_choice

case $update_choice in
    1)
        echo -e "${RED}Обычное обновление обновляет только содержимое скриптов. Новые скрипты будут выполнены только после повторного выполнения меню.${NC}"
        read -rp "Продолжить обычное обновление? (y/n): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            regular_update
        else
            echo -e "${CYAN}Обычное обновление отменено.${NC}"
        fi
        ;;
    2)
        echo -e "${RED}Sing-box будет остановлен, все данные будут сброшены, и будет выполнена начальная настройка.${NC}"
        read -rp "Продолжить сброс и обновление? (y/n): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            reset_update
        else
            echo -e "${CYAN}Сброс и обновление отменено.${NC}"
        fi
        ;;
    *)
        echo -e "${RED}Неверный выбор${NC}"
        ;;
esac

# Очистка временной директории
rm -rf "$TEMP_DIR"
