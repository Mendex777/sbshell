#!/bin/bash

# Определить цвета
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # Без цвета

# Обработка сигнала Ctrl+C
trap 'echo -e "\n${RED}Операция отменена, возврат в меню настройки сети.${NC}"; exit 1' SIGINT

# Получить текущие IP-адрес, шлюз и DNS системы
CURRENT_IP=$(ip addr show | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}')
CURRENT_GATEWAY=$(ip route show default | awk '{print $3}')
CURRENT_DNS=$(grep 'nameserver' /etc/resolv.conf | awk '{print $2}')

echo -e "${YELLOW}Текущий IP-адрес: $CURRENT_IP${NC}"
echo -e "${YELLOW}Текущий адрес шлюза: $CURRENT_GATEWAY${NC}"
echo -e "${YELLOW}Текущий DNS-сервер: $CURRENT_DNS${NC}"

# Получить имя сетевого интерфейса
INTERFACE=$(ip -br link show | awk '{print $1}' | grep -v "lo" | head -n 1)
[ -z "$INTERFACE" ] && { echo -e "${RED}Не найден сетевой интерфейс, выход из программы.${NC}"; exit 1; }

echo -e "${YELLOW}Обнаруженный сетевой интерфейс: $INTERFACE${NC}"

while true; do
    # Попросить пользователя ввести статический IP-адрес, шлюз и DNS
    read -rp "Пожалуйста, введите статический IP-адрес: " IP_ADDRESS
    read -rp "Пожалуйста, введите адрес шлюза: " GATEWAY
    read -rp "Пожалуйста, введите адрес DNS-сервера (несколько адресов разделяются пробелом): " DNS_SERVERS

    echo -e "${YELLOW}Ваши введенные конфигурационные данные:${NC}"
    echo -e "IP-адрес: $IP_ADDRESS"
    echo -e "Адрес шлюза: $GATEWAY"
    echo -e "DNS-сервер: $DNS_SERVERS"

    read -rp "Подтвердите введенные конфигурационные данные? (y/n): " confirm_choice
    if [[ "$confirm_choice" =~ ^[Yy]$ ]]; then
        # Путь к конфигурационным файлам
        INTERFACES_FILE="/etc/network/interfaces"
        RESOLV_CONF_FILE="/etc/resolv.conf"

        # Обновить сетевую конфигурацию
        cat > $INTERFACES_FILE <<EOL
# Локальный сетевой интерфейс
auto lo
iface lo inet loopback

# Основной сетевой интерфейс
allow-hotplug $INTERFACE
iface $INTERFACE inet static
    address $IP_ADDRESS
    netmask 255.255.255.0
    gateway $GATEWAY
EOL

        # Обновить файл resolv.conf
        echo > $RESOLV_CONF_FILE
        for dns in $DNS_SERVERS; do
            echo "nameserver $dns" >> $RESOLV_CONF_FILE
        done

        # Перезапустить сетевую службу
        sudo systemctl restart networking

        # Вывести результат конфигурации
        echo -e "${GREEN}Настройка статического IP-адреса и DNS завершена!${NC}"
        break
    else
        echo -e "${RED}Пожалуйста, повторно введите конфигурационные данные.${NC}"
    fi
done
