#!/bin/bash
# 1. Системная оптимизация и BBR
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p

# 2. Лимиты на CPU для обновлений
mkdir -p /etc/systemd/system/apt-daily.service.d /etc/systemd/system/apt-daily-upgrade.service.d
printf "\nCPUQuota=30%%" > /etc/systemd/system/apt-daily.service.d/override.conf
printf "\nCPUQuota=30%%" > /etc/systemd/system/apt-daily-upgrade.service.d/override.conf
systemctl daemon-reload

# 3. Установка Nginx и сайта (ваши файлы Pomodoro)
apt update && apt install nginx unzip docker.io curl -y
mkdir -p /var/www/html/css /var/www/html/js
# Код для создания HTML/CSS/JS файлов (я сократил для примера, вставьте свои полные данные)
cat <<EOF > /var/www/html/index.html
<!DOCTYPE html><html><head><title>Focus Timer</title><link rel="stylesheet" href="css/style.css"></head>
<body><div id="pomodoro">...</div><script src="js/script.js"></script></body></html>
EOF
systemctl restart nginx

# 4. Установка 3x-ui и MTProto
bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh) <<EOF
y
admin
admin
2053
EOF
docker run -d --name mtproto -p 9443:443 -e SECRET=f96463ced44a00792c11dbfb8e13015a -e TAG=proxy --restart always telegrammessenger/proxy:latest

# 5. AdGuard Home
curl -s -S -L https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh | sh -s -- -v

# 6. Файрвол
ufw allow 22,80,443,2053,3000,8443,9443/tcp
ufw --force enable
