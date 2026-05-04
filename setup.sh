#!/bin/bash
# ВАШИ НАСТРОЙКИ
GITHUB_USER="enver-isliamov"
REPO_NAME="ObHot"

# 1. Ускорение сети (BBR)
echo -e "net.core.default_qdisc=fq\nnet.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p

# 2. Лимиты на CPU (30%)
mkdir -p /etc/systemd/system/apt-daily.service.d /etc/systemd/system/apt-daily-upgrade.service.d
printf "[Service]\nCPUQuota=30%%" > /etc/systemd/system/apt-daily.service.d/override.conf
printf "[Service]\nCPUQuota=30%%" > /etc/systemd/system/apt-daily-upgrade.service.d/override.conf
systemctl daemon-reload

# 3. Установка окружения
apt update && apt install nginx docker.io sqlite3 git curl -y

# 4. Клонирование сайта
rm -rf /var/www/html/*
rm -rf /tmp/vpn-repo
git clone https://github.com/$GITHUB_USER/$REPO_NAME.git /tmp/vpn-repo
cp -r /tmp/vpn-repo/website/* /var/www/html/
chown -R www-data:www-data /var/www/html
systemctl restart nginx

# 5. Установка 3x-ui
TMP_XUI_INSTALLER=$(mktemp)
curl -fsSL https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh -o "$TMP_XUI_INSTALLER"
bash "$TMP_XUI_INSTALLER" < /dev/null
rm -f "$TMP_XUI_INSTALLER"

# Настройка доступа к панели
if command -v x-ui >/dev/null 2>&1; then
  # Используем флаги -u и -p для установки админа
  x-ui setting -u admin -p admin -port 2053
  x-ui restart || true
fi

# 6. Создание Reality-ключа (Порт 443)
sleep 5
x-ui stop || true

XRAY_BIN="/usr/local/x-ui/bin/xray"
[ ! -f "$XRAY_BIN" ] && XRAY_BIN="/usr/local/x-ui/bin/xray-linux-amd64"

if [ -f "$XRAY_BIN" ] && [ -f /etc/x-ui/x-ui.db ]; then
  # Генерация ключей и параметров
  KEYS=$($XRAY_BIN x25519)
  PRIV_KEY=$(echo "$KEYS" | sed -n "s/.*[Pp]rivate[^:]*:[[:space:]]*//p" | head -n1 | tr -d "\r")
  UUID=$(cat /proc/sys/kernel/random/uuid)
  SHORT_ID=$(openssl rand -hex 8)

  if [ -n "$PRIV_KEY" ]; then
    sqlite3 /etc/x-ui/x-ui.db <<SQL
INSERT INTO inbounds (user_id, remark, port, protocol, settings, stream_settings, tag, sniffing, listen, enable)
VALUES (1, 'VLESS-REALITY-AUTO', 443, 'vless',
'{"clients": [{"id": "$UUID", "flow": "xtls-rprx-vision", "email": "admin-user"}], "decryption": "none"}',
'{"network": "tcp", "security": "reality", "realitySettings": {"show": false, "dest": "www.microsoft.com:443", "serverNames": ["www.microsoft.com"], "privateKey": "$PRIV_KEY", "shortIds": ["$SHORT_ID"]}, "tcpSettings": {"header": {"type": "none"}}}',
'vless_reality_443', '{"enabled": true, "destOverride": ["http", "tls"]}', '0.0.0.0', 1);
SQL
  fi
fi
x-ui start || true

# 7. AdGuard Home
echo "Освобождаем порт 53..."
systemctl stop systemd-resolved
systemctl disable systemd-resolved
rm -f /etc/resolv.conf
printf "nameserver 8.8.8.8\nnameserver 1.1.1.1" > /etc/resolv.conf
# Блокируем файл от изменений системой
chattr +i /etc/resolv.conf 2>/dev/null || true

curl -s -S -L https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh | sh -s -- -v -r

# 8. MTProto Proxy
docker run -d --name mtproto -p 9443:443 -e SECRET=$(openssl rand -hex 16) -e TAG=proxy --restart always telegrammessenger/proxy:latest

# 9. Firewall (Безопасный порядок)
echo "Настраиваем правила UFW..."
ufw allow 22/tcp
ufw allow 80,443,2022,2053,2096,2443,3000,8443,9443/tcp
ufw allow 443,2022,2053,2443/udp
ufw --force enable
ufw reload

echo "ГОТОВО! Ваш сайт и VPN развернуты."
x-ui settings || true
