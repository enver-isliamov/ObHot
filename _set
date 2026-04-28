#!/bin/bash
set -e

# Цвета для вывода
GREEN='\033\nCPUQuota=30%" > /etc/systemd/system/apt-daily.service.d/override.conf
mkdir -p /etc/systemd/system/apt-daily-upgrade.service.d
echo -e "\nCPUQuota=30%" > /etc/systemd/system/apt-daily-upgrade.service.d/override.conf
systemctl daemon-reload

# 4. Генерация секретов
DB_PASS=$(openssl rand -hex 16)
ADMIN_PASS=$(openssl rand -hex 12)
MT_SECRET=$(openssl rand -hex 16)
X_UUID=$(docker run --rm teddysun/xray xray uuid)
X_KEYS=$(docker run --rm teddysun/xray xray x25519)
X_PRIV=$(echo "$X_KEYS" | awk '/Private/ {print $3}')
X_PUB=$(echo "$X_KEYS" | awk '/Public/ {print $3}')
X_SID=$(openssl rand -hex 8)
MY_IP=$(curl -s https://ifconfig.me)

# 5. Создание.env
cat <<EOF >.env
DB_PASSWORD=$DB_PASS
DB_NAME=marzban
SUDO_USERNAME=admin
SUDO_PASSWORD=$ADMIN_PASS
MARZBAN_ADMIN_PASSWORD=$ADMIN_PASS
XRAY_PRIVATE_KEY=$X_PRIV
XRAY_PUBLIC_KEY=$X_PUB
XRAY_SHORT_ID=$X_SID
XRAY_UUID=$X_UUID
MTPROTO_SECRET=$MT_SECRET
MTPROTO_TAG=telegram
SERVER_IP=$MY_IP
DECOY_DOMAIN=www.microsoft.com
EOF

# 6. Настройка xray_config.json из шаблона
sed -i "s/\${XRAY_PRIVATE_KEY}/$X_PRIV/" xray_config.json
sed -i "s/\${XRAY_SHORT_ID}/$X_SID/" xray_config.json

# 7. Настройка фаервола
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 8443/tcp
ufw allow 3000/tcp
ufw allow 9443/tcp
echo "y" | ufw enable

# 8. Запуск Docker Compose
docker compose up -d

# 9. Создание администратора Marzban (неинтерактивно)
sleep 15
docker exec marzban marzban cli admin import-from-env --yes

echo -e "${GREEN}>>> Установка завершена!${NC}"
echo "Адрес панели: http://$MY_IP:8000/dashboard"
echo "Логин: admin"
echo "Пароль: $ADMIN_PASS"
echo "MTProto ссылка: https://t.me/proxy?server=$MY_IP&port=9443&secret=dd$MT_SECRET"
echo "Xray Reality Public Key: $X_PUB"
