#!/bin/bash

# Определить цвета
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # Без цвета

# Файл с ручным вводом конфигурации
MANUAL_FILE="/etc/sing-box/manual.conf"

# Создать скрипт для автоматического обновления
cat > /etc/sing-box/update-singbox.sh <<EOF
#!/bin/bash

# Чтение ручных параметров конфигурации
BACKEND_URL=\$(grep BACKEND_URL $MANUAL_FILE | cut -d'=' -f2-)
SUBSCRIPTION_URL=\$(grep SUBSCRIPTION_URL $MANUAL_FILE | cut -d'=' -f2-)
TEMPLATE_URL=\$(grep TEMPLATE_URL $MANUAL_FILE | cut -d'=' -f2-)

# Создание полного URL конфигурационного файла
FULL_URL="\${BACKEND_URL}/config/\${SUBSCRIPTION_URL}&file=\${TEMPLATE_URL}"

# Резервное копирование текущего конфигурационного файла
[ -f "/etc/sing-box/config.json" ] && cp /etc/sing-box/config.json /etc/sing-box/config.json.backup

# Загрузка и проверка нового конфигурационного файла
if curl -L --connect-timeout 10 --max-time 30 "\$FULL_URL" -o /etc/sing-box/config.json; then
    if ! sing-box check -c /etc/sing-box/config.json; then
        echo "Проверка нового конфигурационного файла не удалась, восстановление резервной копии..."
        [ -f "/etc/sing-box/config.json.backup" ] && cp /etc/sing-box/config.json.backup /etc/sing-box/config.json
    fi
else
    echo "Загрузка конфигурационного файла не удалась, восстановление резервной копии..."
    [ -f "/etc/sing-box/config.json.backup" ] && cp /etc/sing-box/config.json.backup /etc/sing-box/config.json
fi

# Перезапуск службы sing-box
systemctl restart sing-box
EOF

chmod a+x /etc/sing-box/update-singbox.sh

# Предоставить меню для настройки интервала времени
while true; do
    read -rp "Введите интервал обновления в часах (1-23 часа, по умолчанию 12 часов): " interval_choice
    interval_choice=${interval_choice:-12}

    if [[ "$interval_choice" =~ ^[1-9]$|^1[0-9]$|^2[0-3]$ ]]; then
        break
    else
        echo -e "${RED}Неверный ввод, пожалуйста, введите значение от 1 до 23 часов.${NC}"
    fi
done

# Проверить, существует ли уже задание cron
if crontab -l 2>/dev/null | grep -q '/etc/sing-box/update-singbox.sh'; then
    echo -e "${RED}Обнаружено существующее задание автообновления.${NC}"
    read -rp "Перенастроить задание автообновления? (y/n): " confirm_reset
    if [[ "$confirm_reset" =~ ^[Yy]$ ]]; then
        crontab -l 2>/dev/null | grep -v '/etc/sing-box/update-singbox.sh' | crontab -
        echo "Старое задание автообновления удалено."
    else
        echo -e "${CYAN}Сохранено существующее задание автообновления. Возврат в меню.${NC}"
        exit 0
    fi
fi

# Добавить новое задание cron
(crontab -l 2>/dev/null; echo "0 */$interval_choice * * * /etc/sing-box/update-singbox.sh") | crontab -
systemctl restart cron

echo "Задание автообновления установлено, выполняется каждые $interval_choice часов"
