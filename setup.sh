#!/bin/bash

echo "🔄 Оновлення системи..."
apt update && apt upgrade -y && apt autoremove -y

echo "🌐 Встановлення Nginx..."
apt install nginx -y

echo "🐘 Встановлення PHP і необхідних модулів..."
apt install php php-curl php-mbstring php-xml php-zip php-fpm -y

echo "▶️ Запуск і увімкнення PHP-FPM (8.3)..."
systemctl start php8.3-fpm
systemctl enable php8.3-fpm

echo "🔐 Встановлення Certbot для HTTPS..."
apt install certbot python3-certbot-nginx -y

echo "✅ Успішно завершено!"
