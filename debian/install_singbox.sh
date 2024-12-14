#!/bin/bash

# Определить цвета
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # Без цвета

# Проверить, установлен ли sing-box
if command -v sing-box &> /dev/null; then
    echo -e "${CYAN}sing-box уже установлен, пропуск шага установки${NC}"
else
    # Добавить официальный GPG-ключ и репозиторий
    sudo mkdir -p /etc/apt/keyrings
    sudo curl -fsSL https://sing-box.app/gpg.key -o /etc/apt/keyrings/sagernet.asc
    sudo chmod a+r /etc/apt/keyrings/sagernet.asc
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/sagernet.asc] https://deb.sagernet.org/ * *" | sudo tee /etc/apt/sources.list.d/sagernet.list > /dev/null

    # Всегда обновлять список пакетов
    echo "Обновление списка пакетов, пожалуйста, подождите..."
    sudo apt-get update -qq > /dev/null 2>&1

    # Предложить пользователю обновить систему
    while true; do
        read -rp "Обновить систему? (y/n): " upgrade_choice
        case $upgrade_choice in
            [Yy]*)
                echo "Обновление системы, пожалуйста, подождите..."
                sudo apt-get upgrade -yq > /dev/null 2>&1
                echo "Обновление завершено"
                break
                ;;
            [Nn]*)
                echo "Пропуск обновления системы."
                break
                ;;
            *)
                echo -e "${RED}Неверный выбор, пожалуйста, введите y или n.${NC}"
                ;;
        esac
    done

    # Выбор установки стабильной или тестовой версии
    while true; do
        read -rp "Пожалуйста, выберите версию для установки (1: стабильная, 2: тестовая): " version_choice
        case $version_choice in
            1)
                echo "Установка стабильной версии..."
                sudo apt-get install sing-box -yq > /dev/null 2>&1
                echo "Установка завершена"
                break
                ;;
            2)
                echo "Установка тестовой версии..."
                sudo apt-get install sing-box-beta -yq > /dev/null 2>&1
                echo "Установка завершена"
                break
                ;;
            *)
                echo -e "${RED}Неверный выбор, пожалуйста, введите 1 или 2.${NC}"
                ;;
        esac
    done

    if command -v sing-box &> /dev/null; then
        sing_box_version=$(sing-box version | grep 'sing-box version' | awk '{print $3}')
        echo -e "${CYAN}sing-box установлен успешно, версия:${NC} $sing_box_version"
    else
        echo -e "${RED}Установка sing-box не удалась, пожалуйста, проверьте журналы или настройки сети${NC}"
    fi
fi
