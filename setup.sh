#!/bin/bash
# Установка Docker
curl -fsSL https://get.docker.com | sh
# Клонирование вашего репозитория ObHot
git clone https://github.com/enver-isliamov/ObHot.git /opt/vpn-stack
cd /opt/vpn-stack
# Запуск всего стека
docker compose up -d
