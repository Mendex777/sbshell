#!/bin/bash

# Конфигурационные параметры
PROXY_FWMARK=1
PROXY_ROUTE_TABLE=100
INTERFACE=$(ip route show default | awk '/default/ {print $5}')

# Чтение текущего режима
MODE=$(grep -oP '(?<=^MODE=).*' /etc/sing-box/mode.conf)

# Очистка правил брандмауэра в режиме TProxy
clearTProxyRules() {
    nft list table inet sing-box >/dev/null 2>&1 && nft delete table inet sing-box
    ip rule del fwmark $PROXY_FWMARK lookup $PROXY_ROUTE_TABLE 2>/dev/null
    ip route del local default dev "$INTERFACE" table $PROXY_ROUTE_TABLE 2>/dev/null
    echo "Очистка правил брандмауэра в режиме TProxy"
}

if [ "$MODE" = "TUN" ]; then
    echo "Применение правил брандмауэра в режиме TUN..."

    # Очистка правил брандмауэра в режиме TProxy
    clearTProxyRules

    # Убедиться, что директория существует
    sudo mkdir -p /etc/sing-box/tun

    # Установка конкретной конфигурации для режима TUN
    cat > /etc/sing-box/tun/nftables.conf <<EOF
# Очистка существующих правил nftables и применение новой конфигурации
flush ruleset
table inet filter {
    chain input { type filter hook input priority 0; policy accept; }
    chain forward { type filter hook forward priority 0; policy accept; }
    chain output { type filter hook output priority 0; policy accept; }
}
EOF

    # Применение правил брандмауэра
    nft -f /etc/sing-box/tun/nftables.conf

    # Сохранение правил брандмауэра
    nft list ruleset > /etc/nftables.conf

    echo "Правила брандмауэра в режиме TUN применены."
else
    echo "Текущий режим не является режимом TUN, пропуск конфигурации правил брандмауэра." >/dev/null 2>&1
fi
