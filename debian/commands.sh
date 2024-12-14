#!/bin/bash

# Определить цвета
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # Без цвета

# Просмотр правил брандмауэра
function view_firewall_rules() {
    echo -e "${YELLOW}Просмотр правил брандмауэра...${NC}"
    sudo nft list ruleset
    read -rp "Нажмите Enter для возврата в подменю..."
}

# Показать журналы
function view_logs() {
    echo -e "${YELLOW}Показ журналов...${NC}"
    sudo journalctl -u sing-box --output cat -e
    read -rp "Нажмите Enter для возврата в подменю..."
}

# Живые журналы
function live_logs() {
    echo -e "${YELLOW}Живые журналы...${NC}"
    sudo journalctl -u sing-box -f --output=cat
    read -rp "Нажмите Enter для возврата в подменю..."
}

# Проверка конфигурационного файла
function check_config() {
    echo -e "${YELLOW}Проверка конфигурационного файла...${NC}"
    bash /etc/sing-box/scripts/check_config.sh
    read -rp "Нажмите Enter для возврата в подменю..."
}

# Опции подменю
function show_submenu() {
    echo -e "${CYAN}=========== Опции подменю ===========${NC}"
    echo -e "${MAGENTA}1. Просмотр правил брандмауэра${NC}"
    echo -e "${MAGENTA}2. Показ журналов${NC}"
    echo -e "${MAGENTA}3. Живые журналы${NC}"
    echo -e "${MAGENTA}4. Проверка конфигурационного файла${NC}"
    echo -e "${MAGENTA}0. Возврат в главное меню${NC}"
    echo -e "${CYAN}===================================${NC}"
}

# Обработка ввода пользователя
function handle_submenu_choice() {
    while true; do
        read -rp "Пожалуйста, выберите действие: " choice
        case $choice in
            1) view_firewall_rules ;;
            2) view_logs ;;
            3) live_logs ;;
            4) check_config ;;
            0) return 0 ;;
            *) echo -e "${RED}Неверный выбор${NC}" ;;
        esac
        show_submenu
    done
    return 0  # Убедиться, что функция завершается с возвратом 0
}

# Показать и обработать подменю
menu_active=true
while $menu_active; do
    show_submenu
    handle_submenu_choice
    choice_returned=$?  # Захватить возвращаемое значение функции
    if [[ $choice_returned -eq 0 ]]; then
        menu_active=false
    fi
done
