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
chown -R www-data:www-data /var/www/html
systemctl restart nginx

# 5. Установка 3x-ui (через временный файл, чтобы инсталлятор не "съел" stdin у основного скрипта)
TMP_XUI_INSTALLER=$(mktemp)
curl -fsSL https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh -o "$TMP_XUI_INSTALLER"
bash "$TMP_XUI_INSTALLER" < /dev/null
rm -f "$TMP_XUI_INSTALLER"

# Явно приводим панель к ожидаемым настройкам
if command -v x-ui >/dev/null 2>&1; then
  if x-ui setting -username admin -password admin -port 2053; then
    x-ui restart || true
  else
    echo "[WARN] Не удалось автоматически применить admin/admin:2053. Ниже текущие настройки панели:"
    x-ui settings || x-ui setting -show || true
  fi
fi

# 6. Программное создание первого Reality-ключа (Порт 443)
sleep 5
x-ui stop || true

XRAY_BIN=""
if [ -x /usr/local/x-ui/bin/xray ]; then
  XRAY_BIN="/usr/local/x-ui/bin/xray"
elif [ -x /usr/local/x-ui/bin/xray-linux-amd64 ]; then
  XRAY_BIN="/usr/local/x-ui/bin/xray-linux-amd64"
elif command -v xray >/dev/null 2>&1; then
  XRAY_BIN="$(command -v xray)"
fi

if [ -n "$XRAY_BIN" ] && [ -f /etc/x-ui/x-ui.db ]; then
  KEYS=$($XRAY_BIN x25519)
  PRIV_KEY=$(echo "$KEYS" | grep "Private" | awk '{print $3}')

  if [ -n "$PRIV_KEY" ]; then
    sqlite3 /etc/x-ui/x-ui.db <<SQL
INSERT INTO inbounds (user_id, remark, port, protocol, settings, stream_settings, tag, sniffing, listen, enable)
VALUES (1, 'VLESS-REALITY-AUTO', 443, 'vless',
'{"clients": [{"id": "$(cat /proc/sys/kernel/random/uuid)", "flow": "xtls-rprx-vision", "email": "admin-user"}], "decryption": "none"}',
'{"network": "tcp", "security": "reality", "realitySettings": {"show": false, "dest": "www.microsoft.com:443", "serverNames": ["www.microsoft.com"], "privateKey": "'$PRIV_KEY'", "shortIds": ["$(openssl rand -hex 8)"]}, "tcpSettings": {"header": {"type": "none"}}}',
'vless_reality_443', '{"enabled": true, "destOverride": ["http", "tls"]}', '0.0.0.0', 1);
SQL
  else
    echo "[WARN] Не удалось извлечь приватный ключ x25519, пропускаем авто-добавление inbound."
  fi
else
  echo "[WARN] xray/bin или /etc/x-ui/x-ui.db не найден, пропускаем авто-добавление inbound."
fi

x-ui start || true

# 7. AdGuard Home (Автоматическая установка)
curl -s -S -L https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh | sh -s -- -v

# 8. Telegram MTProto Proxy (Docker)
docker run -d --name mtproto -p 9443:443 -e SECRET=$(openssl rand -hex 16) -e TAG=proxy --restart always telegrammessenger/proxy:latest

# 9. Firewall (Открываем порты)
ufw allow 22,80,443,2053,3000,8443,9443/tcp
ufw --force enable

echo "Текущие настройки x-ui (если установлена):"
if command -v x-ui >/dev/null 2>&1; then
  x-ui settings || x-ui setting -show || true
fi

echo "ГОТОВО! Ваш сайт-маскировка и VPN развернуты."
