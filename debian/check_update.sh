#!/bin/bash

# Определить цвета
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # Без цвета

echo "Проверка последней версии sing-box..."
# Обновить информацию о пакетах
sudo apt-get update -qq > /dev/null 2>&1

# Проверить версию sing-box
if command -v sing-box &> /dev/null; then
    current_version=$(sing-box version | grep 'sing-box version' | awk '{print $3}')
    echo -e "${CYAN}Текущая установленная версия sing-box:${NC} $current_version"

    # Получить информацию о последней стабильной и тестовой версиях
    stable_version=$(apt-cache policy sing-box | grep Candidate | awk '{print $2}')
    beta_version=$(apt-cache policy sing-box-beta | grep Candidate | awk '{print $2}')

    echo -e "${CYAN}Последняя стабильная версия:${NC} $stable_version"
    echo -e "${CYAN}Последняя тестовая версия:${NC} $beta_version"

    # Предоставить опцию для переключения версий
    while true; do
        read -rp "Переключить версию (1: стабильная, 2: тестовая) (текущая версия: $current_version, нажмите Enter для отмены): " switch_choice
        case $switch_choice in
            1)
                echo "Выбрано переключение на стабильную версию"
                sudo apt-get install sing-box -y
                break
                ;;
            2)
                echo "Выбрано переключение на тестовую версию"
                sudo apt-get install sing-box-beta -y
                break
                ;;
            '')
                echo "Переключение версии не выполнено"
                break
                ;;
            *)
                echo -e "${RED}Неверный выбор, пожалуйста, введите 1 или 2.${NC}"
                ;;
        esac
    done
else
    echo -e "${RED}sing-box не установлен${NC}"
fi
