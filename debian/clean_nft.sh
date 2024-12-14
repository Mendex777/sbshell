#!/bin/bash

# Очистить правила брандмауэра и остановить службу
sudo systemctl stop sing-box
nft flush ruleset

echo "Служба sing-box остановлена, правила брандмауэра очищены."
