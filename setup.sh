#!/bin/bash
# ВАШИ НАСТРОЙКИ (обязательно измените)
GITHUB_USER="enver-isliamov"
REPO_NAME="ObHot"

# 1. Ускорение сети (BBR)
echo -e "net.core.default_qdisc=fq\nnet.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p

# 2. Лимиты на CPU для системных обновлений
mkdir -p /etc/systemd/system/apt-daily.service.d /etc/systemd/system/apt-daily-upgrade.service.d
printf "\nCPUQuota=30%%" > /etc/systemd/system/apt-daily.service.d/override.conf
printf "\nCPUQuota=30%%" > /etc/systemd/system/apt-daily-upgrade.service.d/override.conf
systemctl daemon-reload

# 3. Установка окружения (Nginx, Docker, SQLite, Git)
apt update && apt install nginx docker.io sqlite3 git curl -y

# 4. Клонирование вашего сайта с GitHub
# Мы скачиваем только папку website из вашего репозитория
rm -rf /var/www/html/*
git clone https://github.com/$GITHUB_USER/$REPO_NAME.git /tmp/vpn-repo
cp -r /tmp/vpn-repo/website/* /var/www/html/
chown -r www-data:www-data /var/www/html
systemctl restart nginx

# 5. Установка 3x-ui (Порт 2053, логин admin, пароль admin)
bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh) <<EOF
y
admin
admin
2053
EOF

# 6. Программное создание первого Reality-ключа (Порт 443)
sleep 5
x-ui stop
KEYS=$(/usr/local/x-ui/bin/xray x25519)
PRIV_KEY=$(echo "$KEYS" | grep "Private" | awk '{print $3}')
# Внедряем настройки прямо в базу данных
sqlite3 /etc/x-ui/x-ui.db <<EOF
INSERT INTO inbounds (user_id, remark, port, protocol, settings, stream_settings, tag, sniffing, listen, enable) 
VALUES (1, 'VLESS-REALITY-AUTO', 443, 'vless', 
'{"clients": [{"id": "$(cat /proc/sys/kernel/random/uuid)", "flow": "xtls-rprx-vision", "email": "admin-user"}], "decryption": "none"}', 
'{"network": "tcp", "security": "reality", "realitySettings": {"show": false, "dest": "www.microsoft.com:443", "serverNames": ["www.microsoft.com"], "privateKey": "$PRIV_KEY", "shortIds": ["$(openssl rand -hex 8)"]}, "tcpSettings": {"header": {"type": "none"}}}', 
'vless_reality_443', '{"enabled": true, "destOverride": ["http", "tls"]}', '0.0.0.0', 1);
EOF
x-ui start

# 7. AdGuard Home (Автоматическая установка)
curl -s -S -L https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh | sh -s -- -v

# 8. Telegram MTProto Proxy (Docker)
docker run -d --name mtproto -p 9443:443 -e SECRET=$(openssl rand -hex 16) -e TAG=proxy --restart always telegrammessenger/proxy:latest

# 9. Firewall (Открываем порты)
ufw allow 22,80,443,2053,3000,8443,9443/tcp
ufw --force enable

echo "ГОТОВО! Ваш сайт-маскировка и VPN развернуты."
