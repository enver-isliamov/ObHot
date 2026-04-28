#!/bin/bash
# 1. Системные оптимизации и BBR
echo -e "net.core.default_qdisc=fq\nnet.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p
mkdir -p /etc/systemd/system/apt-daily.service.d /etc/systemd/system/apt-daily-upgrade.service.d
printf "\n\nCPUQuota=30%%" > /etc/systemd/system/apt-daily.service.d/override.conf
printf "\n\nCPUQuota=30%%" > /etc/systemd/system/apt-daily-upgrade.service.d/override.conf
systemctl daemon-reload

# 2. Исправление конфликта порта 53 для AdGuard Home
systemctl stop systemd-resolved
systemctl disable systemd-resolved
echo "nameserver 1.1.1.1" > /etc/resolv.conf

# 3. Установка Docker
curl -fsSL https://get.docker.com | sh
systemctl enable --now docker

# 4. Загрузка вашего репозитория ObHot
rm -rf /opt/ObHot
git clone https://github.com/enver-isliamov/ObHot.git /opt/ObHot
cd /opt/ObHot

# 5. Генерация секретов
MT_SECRET=$(openssl rand -hex 16)
sed -i "s/MT_SECRET_PLACEHOLDER/$MT_SECRET/g" docker-compose.yml

# 6. Открытие портов (включая SSH из Turn 17: 42781)
apt install ufw -y
ufw allow 22,80,443,2053,3000,8443,9443,42781/tcp
ufw --force enable

# 7. Запуск стека
docker compose up -d

echo "УСТАНОВКА ЗАВЕРШЕНА!"
echo "VPN Панель: http://IP:2053 (admin/admin)"
echo "AdGuard: http://IP:3000"
echo "MTProto Secret: $MT_SECRET (порт 9443)"
