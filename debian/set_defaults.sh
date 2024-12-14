#!/bin/bash

DEFAULTS_FILE="/etc/sing-box/defaults.conf"

# Попросить пользователя ввести параметры, если они пусты, использовать значения по умолчанию
read -rp "Пожалуйста, введите адрес бэкенда: " BACKEND_URL
BACKEND_URL=${BACKEND_URL:-$(grep BACKEND_URL $DEFAULTS_FILE | cut -d '=' -f2)}

read -rp "Пожалуйста, введите адрес подписки: " SUBSCRIPTION_URL
SUBSCRIPTION_URL=${SUBSCRIPTION_URL:-$(grep SUBSCRIPTION_URL $DEFAULTS_FILE | cut -d '=' -f2)}

read -rp "Пожалуйста, введите адрес конфигурационного файла TProxy: " TPROXY_TEMPLATE_URL
TPROXY_TEMPLATE_URL=${TPROXY_TEMPLATE_URL:-$(grep TPROXY_TEMPLATE_URL $DEFAULTS_FILE | cut -d '=' -f2)}

read -rp "Пожалуйста, введите адрес конфигурационного файла TUN: " TUN_TEMPLATE_URL
TUN_TEMPLATE_URL=${TUN_TEMPLATE_URL:-$(grep TUN_TEMPLATE_URL $DEFAULTS_FILE | cut -d '=' -f2)}

# Обновить файл конфигурации по умолчанию
cat > $DEFAULTS_FILE <<EOF
BACKEND_URL=$BACKEND_URL
SUBSCRIPTION_URL=$SUBSCRIPTION_URL
TPROXY_TEMPLATE_URL=$TPROXY_TEMPLATE_URL
TUN_TEMPLATE_URL=$TUN_TEMPLATE_URL
EOF

echo "Конфигурация по умолчанию обновлена"
