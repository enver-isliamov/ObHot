#!/bin/bash
# 1. Ускорение сети (BBR)
echo -e "net.core.default_qdisc=fq\nnet.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p

# 2. Лимиты на обновления (чтобы сервер не "зависал")
mkdir -p /etc/systemd/system/apt-daily.service.d /etc/systemd/system/apt-daily-upgrade.service.d
printf "\nCPUQuota=30%%" > /etc/systemd/system/apt-daily.service.d/override.conf
printf "\nCPUQuota=30%%" > /etc/systemd/system/apt-daily-upgrade.service.d/override.conf
systemctl daemon-reload

# 3. Установка Nginx и вашего сайта Pomodoro
apt update && apt install nginx docker.io sqlite3 curl -y
mkdir -p /var/www/html/css /var/www/html/js

# Создание HTML (ваша структура)
cat <<EOF > /var/www/html/index.html
<!DOCTYPE html><html><head><title>Focus Timer</title><link rel="stylesheet" href="css/style.css"></head>
<body><div id="pomodoro">...</div><script src="js/script.js"></script></body></html>
EOF
# ПРИМЕЧАНИЕ: Вставьте здесь ваш полный код CSS и JS из файлов HTML.txt, CSS.txt и JS.txt
printf "/* Ваш CSS код */" > /var/www/html/css/style.css
printf "// Ваш JS код" > /var/www/html/js/script.js
systemctl restart nginx

# 4. Установка 3x-ui (Авто-ответы: порт 2053, логин admin, пароль admin)
bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh) <<EOF
y
admin
admin
2053
EOF

# 5. Авто-настройка Reality (Создаем Inbound на порту 443 программно)
# Мы просто подождем 5 секунд, пока создастся пустая база
sleep 5
x-ui stop
# Генерируем ключи для нового Reality на месте
KEYS=$(/usr/local/x-ui/bin/xray x25519)
PRIV_KEY=$(echo "$KEYS" | grep "Private" | awk '{print $3}')
PUB_KEY=$(echo "$KEYS" | grep "Public" | awk '{print $3}')

# Вставляем готовый конфиг Reality в базу данных через SQLite
sqlite3 /etc/x-ui/x-ui.db <<EOF
INSERT INTO inbounds (user_id, remark, port, protocol, settings, stream_settings, tag, sniffing, listen, enable) 
VALUES (1, 'VLESS-REALITY-AUTO', 443, 'vless', 
'{"clients": [{"id": "$(cat /proc/sys/kernel/random/uuid)", "flow": "xtls-rprx-vision", "email": "admin-user"}], "decryption": "none"}', 
'{"network": "tcp", "security": "reality", "realitySettings": {"show": false, "dest": "www.microsoft.com:443", "serverNames": ["www.microsoft.com"], "privateKey": "$PRIV_KEY", "shortIds": ["$(openssl rand -hex 8)"]}, "tcpSettings": {"header": {"type": "none"}}}', 
'vless_reality_443', '{"enabled": true, "destOverride": ["http", "tls"]}', '0.0.0.0', 1);
EOF
x-ui start

# 6. AdGuard Home
curl -s -S -L https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh | sh -s -- -v

# 7. Telegram MTProto Proxy (Docker)
docker run -d --name mtproto -p 9443:443 -e SECRET=$(openssl rand -hex 16) -e TAG=proxy --restart always telegrammessenger/proxy:latest

# 8. Firewall (Открываем всё нужное)
ufw allow 22,80,443,2053,3000,8443,9443/tcp
ufw --force enable

echo "УСТАНОВКА ЗАВЕРШЕНА! Панель: http://IP:2053 (admin/admin)"
