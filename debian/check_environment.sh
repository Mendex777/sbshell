#!/bin/bash

# Убедиться, что скрипт запущен с правами root
if [ "$(id -u)" != "0" ]; then
    echo "Ошибка: Этот скрипт требует прав root"
    exit 1
fi

# Проверить, установлен ли sing-box
if command -v sing-box &> /dev/null; then
    current_version=$(sing-box version | grep 'sing-box version' | awk '{print $3}')
    echo "sing-box установлен, версия: $current_version"
else
    echo "sing-box не установлен"
fi

# Проверить и включить IP-пересылку
ipv4_forward=$(sysctl net.ipv4.ip_forward | awk '{print $3}')
ipv6_forward=$(sysctl net.ipv6.conf.all.forwarding | awk '{print $3}')

if [ "$ipv4_forward" -eq 1 ] && [ "$ipv6_forward" -eq 1 ]; then
    echo "IP-пересылка уже включена"
else
    echo "Включение IP-пересылки..."
    sudo sed -i '/net.ipv4.ip_forward/s/^#//;/net.ipv6.conf.all.forwarding/s/^#//' /etc/sysctl.conf
    sudo sysctl -p
    echo "IP-пересылка успешно включена"
fi
