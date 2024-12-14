#!/bin/bash

# Определить цвета
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # Без цвета

echo -e "${GREEN}Настройка автозапуска...${NC}"
echo "Пожалуйста, выберите действие (1: Включить автозапуск, 2: Отключить автозапуск)"
read -rp "(1/2): " autostart_choice

apply_firewall() {
    MODE=$(grep -oP '(?<=^MODE=).*' /etc/sing-box/mode.conf)
    if [ "$MODE" = "TProxy" ]; then
        echo "Применение правил брандмауэра в режиме TProxy..."
        bash /etc/sing-box/scripts/configure_tproxy.sh
    elif [ "$MODE" = "TUN" ]; then
        echo "Применение правил брандмауэра в режиме TUN..."
        bash /etc/sing-box/scripts/configure_tun.sh
    else
        echo "Неверный режим, пропуск применения правил брандмауэра."
        exit 1
    fi
}

case $autostart_choice in
    1)
        # Проверить, включен ли уже автозапуск
        if systemctl is-enabled sing-box.service >/dev/null 2>&1 && systemctl is-enabled nftables-singbox.service >/dev/null 2>&1; then
            echo -e "${GREEN}Автозапуск уже включен, действие не требуется.${NC}"
            exit 0  # Вернуться в главное меню
        fi

        echo -e "${GREEN}Включение автозапуска...${NC}"

        # Удалить старый конфигурационный файл, чтобы избежать дублирования конфигурации
        sudo rm -f /etc/systemd/system/nftables-singbox.service

        # Создать файл nftables-singbox.service
        sudo bash -c 'cat > /etc/systemd/system/nftables-singbox.service <<EOF
[Unit]
Description=Apply nftables rules for Sing-Box
After=network.target

[Service]
ExecStart=/etc/sing-box/scripts/manage_autostart.sh apply_firewall
Type=oneshot
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF'

        # Изменить файл sing-box.service
        sudo bash -c "sed -i '/After=network.target nss-lookup.target network-online.target/a After=nftables-singbox.service' /usr/lib/systemd/system/sing-box.service"
        sudo bash -c "sed -i '/^Requires=/d' /usr/lib/systemd/system/sing-box.service"
        sudo bash -c "sed -i '/

\[Unit\]

/a Requires=nftables-singbox.service' /usr/lib/systemd/system/sing-box.service"

        # Включить и запустить службы
        sudo systemctl daemon-reload
        sudo systemctl enable nftables-singbox.service sing-box.service
        sudo systemctl start nftables-singbox.service sing-box.service
        cmd_status=$?

        if [ "$cmd_status" -eq 0 ]; then
            echo -e "${GREEN}Автозапуск успешно включен.${NC}"
        else
            echo -e "${RED}Не удалось включить автозапуск.${NC}"
        fi
        ;;
    2)
        # Проверить, отключен ли уже автозапуск
        if ! systemctl is-enabled sing-box.service >/dev/null 2>&1 && ! systemctl is-enabled nftables-singbox.service >/dev/null 2>&1; then
            echo -e "${GREEN}Автозапуск уже отключен, действие не требуется.${NC}"
            exit 0  # Вернуться в главное меню
        fi

        echo -e "${RED}Отключение автозапуска...${NC}"

        # Отключить и остановить службы
        sudo systemctl disable sing-box.service
        sudo systemctl disable nftables-singbox.service
        sudo systemctl stop sing-box.service
        sudo systemctl stop nftables-singbox.service

        # Удалить файл nftables-singbox.service
        sudo rm -f /etc/systemd/system/nftables-singbox.service

        # Восстановить файл sing-box.service
        sudo bash -c "sed -i '/After=nftables-singbox.service/d' /usr/lib/systemd/system/sing-box.service"
        sudo bash -c "sed -i '/Requires=nftables-singbox.service/d' /usr/lib/systemd/system/sing-box.service"

        # Перезагрузить systemd
        sudo systemctl daemon-reload
        cmd_status=$?

        if [ "$cmd_status" -eq 0 ]; then
            echo -e "${GREEN}Автозапуск успешно отключен.${NC}"
        else
            echo -e "${RED}Не удалось отключить автозапуск.${NC}"
        fi
        ;;
    *)
        echo -e "${RED}Неверный выбор${NC}"
        ;;
esac

# Вызвать функцию применения правил брандмауэра
if [ "$1" = "apply_firewall" ]; then
    apply_firewall
fi
