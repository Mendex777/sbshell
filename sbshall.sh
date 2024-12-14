#!/bin/bash

# Определить URL для загрузки основного скрипта
MAIN_SCRIPT_URL="https://ghp.ci/https://raw.githubusercontent.com/qichiyuhub/sbshell/refs/heads/master/debian/menu.sh"

# Директория для загрузки скрипта
SCRIPT_DIR="/etc/sing-box/scripts"

# Определить цвета
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # Без цвета

# Проверить, установлен ли sudo
if ! command -v sudo &> /dev/null; then
    echo -e "${RED}sudo не установлен.${NC}"
    read -rp "Установить sudo? (y/n): " install_sudo
    if [[ "$install_sudo" =~ ^[Yy]$ ]]; then
        apt-get update
        apt-get install -y sudo
        if ! command -v sudo &> /dev/null; then
            echo -e "${RED}Не удалось установить sudo, пожалуйста, установите sudo вручную и запустите этот скрипт снова.${NC}"
            exit 1
        fi
        echo -e "${GREEN}sudo установлен успешно.${NC}"
    else
        echo -e "${RED}Скрипт не может продолжить выполнение без sudo.${NC}"
        exit 1
    fi
fi

# Список зависимостей для проверки
DEPENDENCIES=("wget" "nftables")

# Проверить и установить отсутствующие зависимости
for DEP in "${DEPENDENCIES[@]}"; do
    if [ "$DEP" == "nftables" ]; then
        CHECK_CMD="nft --version"
    else
        CHECK_CMD="wget --version"
    fi

    if ! $CHECK_CMD &> /dev/null; then
        echo -e "${RED}$DEP не установлен.${NC}"
        read -rp "Установить $DEP? (y/n): " install_dep
        if [[ "$install_dep" =~ ^[Yy]$ ]]; then
            sudo apt-get update
            sudo apt-get install -y "$DEP"
            if ! $CHECK_CMD &> /dev/null; then
                echo -e "${RED}Не удалось установить $DEP, пожалуйста, установите $DEP вручную и запустите этот скрипт снова.${NC}"
                exit 1
            fi
            echo -e "${GREEN}$DEP установлен успешно.${NC}"
        else
            echo -e "${RED}Скрипт не может продолжить выполнение без $DEP.${NC}"
            exit 1
        fi
    fi
done

# Проверить, поддерживается ли система
if [[ "$(uname -s)" != "Linux" ]]; then
    echo -e "${RED}Текущая система не поддерживает выполнение этого скрипта.${NC}"
    exit 1
fi

# Проверить дистрибутив
if grep -qi 'debian' /etc/os-release; then
    echo -e "${GREEN}Система Debian, поддерживается выполнение этого скрипта.${NC}"
elif grep -qi 'ubuntu' /etc/os-release; then
    echo -e "${GREEN}Система Ubuntu, поддерживается выполнение этого скрипта.${NC}"
elif grep -qi 'armbian' /etc/os-release; then
    echo -e "${GREEN}Система Armbian, поддерживается выполнение этого скрипта.${NC}"
elif grep -qi 'openwrt' /etc/os-release; then
    echo "Система OpenWRT, поддержка в будущих версиях."
    # Зарезервировано для операций OpenWRT
    echo -e "${RED}Версия OpenWRT пока не поддерживается, ожидайте.${NC}"
    exit 1
else
    echo -e "${RED}Текущая система не является Debian/Ubuntu/Armbian, не поддерживается выполнение этого скрипта.${NC}"
    exit 1
fi

# Убедиться, что директория скрипта существует, и установить права
sudo mkdir -p "$SCRIPT_DIR"
sudo chown "$(whoami)":"$(whoami)" "$SCRIPT_DIR"

# Загрузить и выполнить основной скрипт
wget -q -O "$SCRIPT_DIR/menu.sh" "$MAIN_SCRIPT_URL"
echo -e "${GREEN}Скрипт загружается, пожалуйста, подождите...${NC}"
echo -e "${YELLOW}Внимание: при установке и обновлении singbox используйте прокси-среду, при запуске singbox обязательно отключите прокси!${NC}"

if ! [ -f "$SCRIPT_DIR/menu.sh" ]; then
    echo -e "${RED}Не удалось загрузить основной скрипт, проверьте соединение с интернетом.${NC}"
    exit 1
fi

chmod +x "$SCRIPT_DIR/menu.sh"
bash "$SCRIPT_DIR/menu.sh"
