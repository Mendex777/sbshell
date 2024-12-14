#!/bin/bash

# Определить цвета
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # Без цвета

# Директория для скриптов
SCRIPT_DIR="/etc/sing-box/scripts"

# Остановка службы sing-box
stop_singbox() {
    sudo systemctl stop sing-box

    if ! systemctl is-active --quiet sing-box; then
        echo -e "${GREEN}sing-box остановлен${NC}"

        # Попросить пользователя подтвердить очистку правил брандмауэра
        read -rp "Очистить правила брандмауэра? (y/n): " confirm_cleanup
        if [[ "$confirm_cleanup" =~ ^[Yy]$ ]]; then
            echo -e "${CYAN}Выполнение очистки правил брандмауэра...${NC}"
            bash "$SCRIPT_DIR/clean_nft.sh"
            echo -e "${GREEN}Очистка правил брандмауэра завершена${NC}"
        else
            echo -e "${CYAN}Очистка правил брандмауэра отменена.${NC}"
        fi

    else
        echo -e "${RED}Остановка sing-box не удалась, проверьте журналы${NC}"
    fi
}

# Попросить пользователя подтвердить остановку
read -rp "Остановить sing-box? (y/n): " confirm_stop
if [[ "$confirm_stop" =~ ^[Yy]$ ]]; then
    stop_singbox
else
    echo -e "${CYAN}Остановка sing-box отменена.${NC}"
    exit 0
fi
