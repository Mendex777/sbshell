#!/bin/bash

# Определить цвета
CYAN='\033[0;36m'
GREEN='\033[0;32m'
MAGENTA='\033[0;35m'
RED='\033[0;31m'
NC='\033[0m' # Без цвета

# Директория для скриптов
SCRIPT_DIR="/etc/sing-box/scripts"

# Проверка текущего режима
check_mode() {
    if nft list chain inet sing-box prerouting_tproxy &>/dev/null || nft list chain inet sing-box output_tproxy &>/dev/null; then
        echo "Режим TProxy"
    else
        echo "Режим TUN"
    fi
}

# Применение правил брандмауэра
apply_firewall() {
    MODE=$(grep -oP '(?<=^MODE=).*' /etc/sing-box/mode.conf)
    if [ "$MODE" = "TProxy" ]; then
        bash "$SCRIPT_DIR/configure_tproxy.sh"
    elif [ "$MODE" = "TUN" ]; then
        bash "$SCRIPT_DIR/configure_tun.sh"
    fi
}

# Запуск службы sing-box
start_singbox() {
    echo -e "${CYAN}Проверка, находится ли в непроксированной среде...${NC}"
    STATUS_CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "https://www.google.com")

    if [ "$STATUS_CODE" -eq 200 ]; then
        echo -e "${RED}Текущая сеть находится в проксированной среде, для запуска sing-box требуется прямое подключение, пожалуйста, настройте!${NC}"
        read -rp "Выполнить скрипт настройки сети (пока поддерживается только debian)? (y/n/skip): " network_choice
        if [[ "$network_choice" =~ ^[Yy]$ ]]; then
            bash "$SCRIPT_DIR/set_network.sh"
            STATUS_CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "https://www.google.com")
            if [ "$STATUS_CODE" -eq 200 ]; then
                echo -e "${RED}После изменения настроек сети все еще находится в проксированной среде, пожалуйста, проверьте настройки сети!${NC}"
                exit 1
            fi
        elif [[ "$network_choice" =~ ^[Ss]kip$ ]]; then
            echo -e "${CYAN}Пропуск проверки сети, прямой запуск sing-box.${NC}"
        else
            echo -e "${RED}Пожалуйста, переключитесь в непроксированную среду перед запуском sing-box.${NC}"
            exit 1
        fi
    else
        echo -e "${CYAN}Текущая сеть не является проксированной, можно запускать sing-box.${NC}"
    fi

    apply_firewall

    sudo systemctl restart sing-box &>/dev/null

    if systemctl is-active --quiet sing-box; then
        echo -e "${GREEN}sing-box запущен успешно${NC}"
        mode=$(check_mode)
        echo -e "${MAGENTA}Текущий режим запуска: ${mode}${NC}"
    else
        echo -e "${RED}Запуск sing-box не удался, пожалуйста, проверьте журналы${NC}"
    fi
}

# Попросить пользователя подтвердить запуск
read -rp "Запустить sing-box? (y/n): " confirm_start
if [[ "$confirm_start" =~ ^[Yy]$ ]]; then
    start_singbox
else
    echo -e "${CYAN}Запуск sing-box отменен.${NC}"
    exit 0
fi
