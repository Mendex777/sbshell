#!/bin/bash

# Определить цвета
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # Без цвета

# Файл с ручным вводом конфигурации
MANUAL_FILE="/etc/sing-box/manual.conf"
DEFAULTS_FILE="/etc/sing-box/defaults.conf"

# Получить текущий режим
MODE=$(grep -oP '(?<=^MODE=).*' /etc/sing-box/mode.conf)

# Функция для запроса ввода параметров у пользователя
prompt_user_input() {
    while true; do
        read -rp "Пожалуйста, введите адрес бэкенда (оставьте пустым для использования значения по умолчанию): " BACKEND_URL
        if [ -z "$BACKEND_URL" ]; then
            BACKEND_URL=$(grep BACKEND_URL "$DEFAULTS_FILE" 2>/dev/null | cut -d'=' -f2-)
            if [ -z "$BACKEND_URL" ]; then
                echo -e "${RED}Значение по умолчанию не установлено, пожалуйста, установите его в меню!${NC}"
                continue
            fi
            echo -e "${CYAN}Используется адрес бэкенда по умолчанию: $BACKEND_URL${NC}"
        fi
        break
    done

    while true; do
        read -rp "Пожалуйста, введите адрес подписки (оставьте пустым для использования значения по умолчанию): " SUBSCRIPTION_URL
        if [ -z "$SUBSCRIPTION_URL" ]; then
            SUBSCRIPTION_URL=$(grep SUBSCRIPTION_URL "$DEFAULTS_FILE" 2>/dev/null | cut -d'=' -f2-)
            if [ -z "$SUBSCRIPTION_URL" ]; then
                echo -e "${RED}Значение по умолчанию не установлено, пожалуйста, установите его в меню!${NC}"
                continue
            fi
            echo -e "${CYAN}Используется адрес подписки по умолчанию: $SUBSCRIPTION_URL${NC}"
        fi
        break
    done

    while true; do
        read -rp "Пожалуйста, введите адрес конфигурационного файла (оставьте пустым для использования значения по умолчанию): " TEMPLATE_URL
        if [ -z "$TEMPLATE_URL" ]; then
            if [ "$MODE" = "TProxy" ]; then
                TEMPLATE_URL=$(grep TPROXY_TEMPLATE_URL "$DEFAULTS_FILE" 2>/dev/null | cut -d'=' -f2-)
                if [ -z "$TEMPLATE_URL" ]; then
                    echo -e "${RED}Значение по умолчанию не установлено, пожалуйста, установите его в меню!${NC}"
                    continue
                fi
                echo -e "${CYAN}Используется адрес конфигурационного файла TProxy по умолчанию: $TEMPLATE_URL${NC}"
            elif [ "$MODE" = "TUN" ]; then
                TEMPLATE_URL=$(grep TUN_TEMPLATE_URL "$DEFAULTS_FILE" 2>/dev/null | cut -d'=' -f2-)
                if [ -z "$TEMPLATE_URL" ]; then
                    echo -e "${RED}Значение по умолчанию не установлено, пожалуйста, установите его в меню!${NC}"
                    continue
                fi
                echo -e "${CYAN}Используется адрес конфигурационного файла TUN по умолчанию: $TEMPLATE_URL${NC}"
            else
                echo -e "${RED}Неизвестный режим: $MODE${NC}"
                exit 1
            fi
        fi
        break
    done
}

while true; do
    prompt_user_input

    # Показать введенные пользователем конфигурационные данные
    echo -e "${CYAN}Ваши введенные конфигурационные данные:${NC}"
    echo "Адрес бэкенда: $BACKEND_URL"
    echo "Адрес подписки: $SUBSCRIPTION_URL"
    echo "Адрес конфигурационного файла: $TEMPLATE_URL"

    read -rp "Подтвердите введенные конфигурационные данные? (y/n): " confirm_choice
    if [[ "$confirm_choice" =~ ^[Yy]$ ]]; then
        # Обновить файл с ручным вводом конфигурации
        cat > "$MANUAL_FILE" <<EOF
BACKEND_URL=$BACKEND_URL
SUBSCRIPTION_URL=$SUBSCRIPTION_URL
TEMPLATE_URL=$TEMPLATE_URL
EOF

        echo "Ручной ввод конфигурации обновлен"

        # Построить полный URL конфигурационного файла
        FULL_URL="${BACKEND_URL}/config/${SUBSCRIPTION_URL}&file=${TEMPLATE_URL}"
        echo "Сгенерирован полный URL подписки: $FULL_URL"

        while true; do
            # Скачать и проверить конфигурационный файл
            if curl -L --connect-timeout 10 --max-time 30 "$FULL_URL" -o /etc/sing-box/config.json; then
                echo "Конфигурационный файл загружен и проверен успешно!"
                if ! sing-box check -c /etc/sing-box/config.json; then
                    echo "Проверка конфигурационного файла не удалась"
                    exit 1
                fi
                break
            else
                echo "Загрузка конфигурационного файла не удалась"
                read -rp "Загрузка не удалась, повторить попытку? (y/n): " retry_choice
                if [[ "$retry_choice" =~ ^[Nn]$ ]]; then
                    exit 1
                fi
            fi
        done

        break
    else
        echo -e "${RED}Пожалуйста, повторно введите конфигурационные данные.${NC}"
    fi
done
