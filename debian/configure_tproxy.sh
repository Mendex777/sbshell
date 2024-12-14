#!/bin/sh

# Конфигурационные параметры
TPROXY_PORT=7895  # Соответствует значению, определенному в sing-box
ROUTING_MARK=666  # Соответствует значению, определенному в sing-box
PROXY_FWMARK=1
PROXY_ROUTE_TABLE=100
INTERFACE=$(ip route show default | awk '/default/ {print $5}')

# Резервный набор IP-адресов
ReservedIP4='{ 127.0.0.0/8, 10.0.0.0/8, 100.64.0.0/10, 169.254.0.0/16, 172.16.0.0/12, 192.0.0.0/24, 192.0.2.0/24, 198.18.0.0/15, 198.51.100.0/24, 192.88.99.0/24, 192.168.0.0/16, 203.0.113.0/24, 224.0.0.0/4, 240.0.0.0/4, 255.255.255.255/32 }'
CustomBypassIP='{ 192.168.0.0/16 }'  # Пользовательский набор IP-адресов для обхода

# Чтение текущего режима
MODE=$(grep -oP '(?<=^MODE=).*' /etc/sing-box/mode.conf)

# Очистка специфических правил брандмауэра
clearSingboxRules() {
    nft list table inet sing-box >/dev/null 2>&1 && nft delete table inet sing-box
    ip rule del fwmark $PROXY_FWMARK lookup $PROXY_ROUTE_TABLE 2>/dev/null
    ip route del local default dev "$INTERFACE" table $PROXY_ROUTE_TABLE 2>/dev/null
    echo "Очистка правил брандмауэра, связанных с sing-box"
}

# Применение правил брандмауэра только в режиме TProxy
if [ "$MODE" = "TProxy" ]; then
    echo "Применение правил брандмауэра в режиме TProxy..."

    clearSingboxRules

    # Установка IP-правил и маршрутов
    ip -f inet rule add fwmark $PROXY_FWMARK lookup $PROXY_ROUTE_TABLE
    ip -f inet route add local default dev "$INTERFACE" table $PROXY_ROUTE_TABLE
    sysctl -w net.ipv4.ip_forward=1 > /dev/null

    # Убедиться, что директория существует
    sudo mkdir -p /etc/sing-box/nft

    # Установка правил nftables и IP-маршрутов в режиме TProxy
    cat > /etc/sing-box/nft/nftables.conf <<EOF
table inet sing-box {
    set RESERVED_IPSET {
        type ipv4_addr
        flags interval
        auto-merge
        elements = $ReservedIP4
    }

    chain prerouting_tproxy {
        type filter hook prerouting priority mangle; policy accept;

        # Перенаправление DNS-запросов на локальный порт TProxy
        meta l4proto { tcp, udp } th dport 53 tproxy to :$TPROXY_PORT accept

        # Пользовательский обход адресов
        ip daddr $CustomBypassIP accept

        # Отклонение доступа к локальному порту TProxy
        fib daddr type local meta l4proto { tcp, udp } th dport $TPROXY_PORT reject with icmpx type host-unreachable

        # Обход локальных адресов
        fib daddr type local accept

        # Обход резервных адресов
        ip daddr @RESERVED_IPSET accept

        # Оптимизация установленных TCP-соединений
        meta l4proto tcp socket transparent 1 meta mark set $PROXY_FWMARK accept

        # Перенаправление оставшегося трафика на порт TProxy и установка метки
        meta l4proto { tcp, udp } tproxy to :$TPROXY_PORT meta mark set $PROXY_FWMARK
    }

    chain output_tproxy {
        type route hook output priority mangle; policy accept;

        # Пропуск трафика локального интерфейса
        meta oifname "lo" accept

        # Обход трафика, отправленного локальным sing-box
        meta mark $ROUTING_MARK accept

        # Метка DNS-запросов
        meta l4proto { tcp, udp } th dport 53 meta mark set $PROXY_FWMARK

        # Обход трафика NBNS
        udp dport { netbios-ns, netbios-dgm, netbios-ssn } accept

        # Пользовательский обход адресов
        ip daddr $CustomBypassIP accept

        # Обход локальных адресов
        fib daddr type local accept

        # Обход резервных адресов
        ip daddr @RESERVED_IPSET accept

        # Метка и перенаправление оставшегося трафика
        meta l4proto { tcp, udp } meta mark set $PROXY_FWMARK
    }
}
EOF

    # Применение правил брандмауэра и IP-маршрутов
    nft -f /etc/sing-box/nft/nftables.conf
    ip rule add fwmark $PROXY_FWMARK table $PROXY_ROUTE_TABLE
    ip route add local default dev lo table $PROXY_ROUTE_TABLE

    # Сохранение правил брандмауэра
    nft list ruleset > /etc/nftables.conf

    echo "Правила брандмауэра в режиме TProxy применены."
else
    echo "Текущий режим - TUN, правила брандмауэра не требуются." >/dev/null 2>&1
fi
