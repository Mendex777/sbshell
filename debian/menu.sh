#!/bin/bash

#################################################
# Описание: Скрипт для автоматизации установки и настройки sing-box на Debian/Ubuntu/Armbian
# Версия: 1.2.4
# Автор: Youtube: 七尺宇
#################################################

# Определить цвета
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # Без цвета

# Директория для скриптов и файл инициализации
SCRIPT_DIR="/etc/sing-box/scripts"
INITIALIZED_FILE="$SCRIPT_DIR/.initialized"

# Убедиться, что директория для скриптов существует и установить права
sudo mkdir -p "$SCRIPT_DIR"
sudo chown "$(whoami)":"$(whoami)" "$SCRIPT_DIR"

# Базовый URL для скриптов
BASE_URL="https://raw.githubusercontent.com/Mendex777/sbshell/refs/heads/master/debian"

# Список скриптов
SCRIPTS=(
    "check_environment.sh"     # Проверка системной среды
    "set_network.sh"           # Настройка сети
    "check_update.sh"          # Проверка доступных обновлений
    "install_singbox.sh"       # Установка Sing-box
    "manual_input.sh"          # Ручной ввод конфигурации
    "manual_update.sh"         # Ручное обновление конфигурации
    "auto_update.sh"           # Автоматическое обновление конфигурации
    "configure_tproxy.sh"      # Настройка режима TProxy
    "configure_tun.sh"         # Настройка режима TUN
    "start_singbox.sh"         # Ручной запуск Sing-box
    "stop_singbox.sh"          # Ручная остановка Sing-box
    "clean_nft.sh"             # Очистка правил nftables
    "set_defaults.sh"          # Установка конфигурации по умолчанию
    "commands.sh"              # Часто используемые команды
    "switch_mode.sh"           # Переключение режима прокси
    "manage_autostart.sh"      # Настройка автозапуска
    "check_config.sh"          # Проверка конфигурационного файла
    "update_scripts.sh"        # Обновление скриптов
    "menu.sh"                  # Главное меню
)

# Скачать и настроить один скрипт с логикой повторных попыток и ведения журнала
download_script() {
    local SCRIPT="$1"
    local RETRIES=5  # Увеличить количество попыток
    local RETRY_DELAY=5

    for ((i=1; i<=RETRIES; i++)); do
        if wget -q -O "$SCRIPT_DIR/$SCRIPT" "$BASE_URL/$SCRIPT"; then
            chmod +x "$SCRIPT_DIR/$SCRIPT"
            return 0
        else
            echo -e "${YELLOW}Скачивание $SCRIPT не удалось, повторная попытка $i/${RETRIES}...${NC}"
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

# Проверка целостности скриптов и скачивание отсутствующих скриптов
check_and_download_scripts() {
    local missing_scripts=()
    for SCRIPT in "${SCRIPTS[@]}"; do
        if [ ! -f "$SCRIPT_DIR/$SCRIPT" ]; then
            missing_scripts+=("$SCRIPT")
        fi
    done

    if [ ${#missing_scripts[@]} -ne 0 ]; then
        echo -e "${CYAN}Скачивание скриптов, пожалуйста, подождите...${NC}"
        for SCRIPT in "${missing_scripts[@]}"; do
            download_script "$SCRIPT" || {
                echo -e "${RED}Скачивание $SCRIPT не удалось, повторить попытку? (y/n): ${NC}"
                read -r retry_choice
                if [[ "$retry_choice" =~ ^[Yy]$ ]]; then
                    download_script "$SCRIPT"
                else
                    echo -e "${RED}Пропуск скачивания $SCRIPT.${NC}"
                fi
            }
        done
    fi
}

# Инициализация
initialize() {
    # Проверка наличия старых скриптов
    if ls "$SCRIPT_DIR"/*.sh 1> /dev/null 2>&1; then
        find "$SCRIPT_DIR" -type f -name "*.sh" ! -name "menu.sh" -exec rm -f {} \;
        rm -f "$INITIALIZED_FILE"
    fi

    # Перезагрузка скриптов
    parallel_download_scripts
    # Другие действия при первом запуске
    auto_setup
    touch "$INITIALIZED_FILE"
}

# Автоматическая настройка
auto_setup() {
    systemctl is-active --quiet sing-box && sudo systemctl stop sing-box
    bash "$SCRIPT_DIR/check_environment.sh"
    command -v sing-box &> /dev/null || bash "$SCRIPT_DIR/install_singbox.sh" || bash "$SCRIPT_DIR/check_update.sh"
    bash "$SCRIPT_DIR/switch_mode.sh"
    bash "$SCRIPT_DIR/manual_input.sh"
    bash "$SCRIPT_DIR/start_singbox.sh"
}

# Проверка необходимости инициализации
if [ ! -f "$INITIALIZED_FILE" ]; then
    echo -e "${CYAN}Вход в режим инициализации, нажмите Enter для продолжения или введите skip для пропуска${NC}"
    read -r init_choice
    if [[ "$init_choice" =~ ^[Ss]kip$ ]]; then
        echo -e "${CYAN}Пропуск инициализации, переход в меню...${NC}"
    else
        initialize
    fi
fi

# Добавление псевдонима в .bashrc, если он уже существует, не добавлять
if ! grep -q "alias sb=" ~/.bashrc; then
    echo "alias sb='bash $SCRIPT_DIR/menu.sh menu'" >> ~/.bashrc
fi

# Создание ярлыка скрипта
if [ ! -f /usr/local/bin/sb ]; then
    echo -e '#!/bin/bash\nbash /etc/sing-box/scripts/menu.sh menu' | sudo tee /usr/local/bin/sb >/dev/null
    sudo chmod +x /usr/local/bin/sb
fi

# Отображение меню
show_menu() {
    echo -e "${CYAN}=========== Меню управления Sbshell ===========${NC}"
    echo -e "${GREEN}1. Переключение режима Tproxy/Tun${NC}"
    echo -e "${GREEN}2. Ручное обновление конфигурационного файла${NC}"
    echo -e "${GREEN}3. Автоматическое обновление конфигурационного файла${NC}"
    echo -e "${GREEN}4. Ручной запуск sing-box${NC}"
    echo -e "${GREEN}5. Ручная остановка sing-box${NC}"
    echo -e "${GREEN}6. Установка/обновление sing-box${NC}"
    echo -e "${GREEN}7. Установка параметров по умолчанию${NC}"
    echo -e "${GREEN}8. Настройка автозапуска${NC}"
    echo -e "${GREEN}9. Настройка сети (только для debian)${NC}"
    echo -e "${GREEN}10. Часто используемые команды${NC}"
    echo -e "${GREEN}11. Обновление скриптов${NC}"
    echo -e "${GREEN}0. Выход${NC}"
    echo -e "${CYAN}=======================================${NC}"
}

# Обработка выбора пользователя
handle_choice() {
    read -rp "Пожалуйста, выберите действие: " choice
    case $choice in
        1)
            bash "$SCRIPT_DIR/switch_mode.sh"
            bash "$SCRIPT_DIR/manual_input.sh"
            bash "$SCRIPT_DIR/start_singbox.sh"
            ;;
        2)
            bash "$SCRIPT_DIR/manual_update.sh"
            ;;
        3)
            bash "$SCRIPT_DIR/auto_update.sh"
            ;;
        4)
            bash "$SCRIPT_DIR/start_singbox.sh"
            ;;
        5)
            bash "$SCRIPT_DIR/stop_singbox.sh"
            ;;
        6)
            if command -v sing-box &> /dev/null; then
                bash "$SCRIPT_DIR/check_update.sh"
            else
                bash "$SCRIPT_DIR/install_singbox.sh"
            fi
            ;;
        7)
            bash "$SCRIPT_DIR/set_defaults.sh"
            ;;
        8)
            bash "$SCRIPT_DIR/manage_autostart.sh"
            ;;
        9)
            bash "$SCRIPT_DIR/set_network.sh"
            ;;
        10)
            bash "$SCRIPT_DIR/commands.sh"
            ;;
        11)
            bash "$SCRIPT_DIR/update_scripts.sh"
            ;;
        0)
            exit 0
            ;;
        *)
            echo -e "${RED}Неверный выбор${NC}"
            ;;
    esac
}

# Основной цикл
while true; do
    show_menu
    handle_choice
done
