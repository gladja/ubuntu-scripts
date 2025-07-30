#!/bin/bash

set -e

# Цвета
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
RESET="\033[0m"
BOLD="\033[1m"

log() {
    echo -e "${GREEN}[✔]${RESET} ${BOLD}$1${RESET}"
}

info() {
    echo -e "${YELLOW}[i]${RESET} ${BOLD}$1${RESET}"
}

error() {
    echo -e "${RED}[✘]${RESET} ${BOLD}$1${RESET}"
    exit 1
}

# Проверка прав
if [[ "$EUID" -ne 0 ]]; then
    error "Запусти скрипт с правами root (через sudo)"
fi

# Проверка версии
OS_VERSION=$(lsb_release -rs)
if [[ "$OS_VERSION" != "24.04" ]]; then
    error "Скрипт работает только на Ubuntu 24.04"
fi

# Проверка аргумента
if [[ $# -ne 1 ]]; then
    error "Использование: $0 <имя-домена>"
fi

DOMAIN=$1
WEB_ROOT="/var/www/$DOMAIN"
NGINX_CONF="/etc/nginx/sites-enabled/${DOMAIN}.conf"
SSL_CERT_EMAIL="valentin.store@proton.me"

info "Удаляю /var/www/html..."
rm -rf /var/www/html || true

info "Проверка Apache..."
if systemctl is-active --quiet apache2; then
    info "Apache активен. Останавливаю и удаляю..."
    systemctl stop apache2
    systemctl disable apache2
    apt purge apache2* -y || true
else
    info "Apache не работает. Пропускаем."
fi

# Обновление и установка
echo 'grub-pc grub-pc/install_devices multiselect /dev/sda' | debconf-set-selections
echo 'grub-pc grub-pc/install_devices_empty boolean false' | debconf-set-selections

info "Обновляю систему и устанавливаю пакеты..."
apt update && DEBIAN_FRONTEND=noninteractive apt upgrade -y && apt autoremove -y

apt install nginx php php-curl php-mbstring php-xml php-zip php-fpm curl jq certbot python3-certbot-nginx tree -y

info "Запускаю nginx и php-fpm..."
systemctl start nginx
systemctl enable nginx

systemctl start php8.3-fpm
systemctl enable php8.3-fpm

info "Создаю директорию сайта $WEB_ROOT..."
mkdir -p "$WEB_ROOT"
chown -R www-data:www-data "$WEB_ROOT"

info "Удаляю стандартные конфиги nginx..."
rm -f /etc/nginx/sites-enabled/default || true
rm -f "$NGINX_CONF" || true

info "Создаю конфиг nginx для $DOMAIN..."
cat <<EOF > "$NGINX_CONF"
server {
   listen 80;
   listen [::]:80;

   server_name $DOMAIN;
   root $WEB_ROOT;

   index index.html;

   location / {
      try_files \$uri \$uri/ /index.html;
   }

   location ~ /\.ht {
      deny all;
   }
}
EOF

info "Проверка и перезапуск nginx..."
nginx -t && systemctl reload nginx

info "Получаю SSL сертификат через certbot..."
certbot --nginx -d $DOMAIN --non-interactive --agree-tos --email "$SSL_CERT_EMAIL"

info "Финальный перезапуск nginx..."
nginx -t && systemctl reload nginx

log "✅ Домен $DOMAIN успешно настроен"
log " URL: https://$DOMAIN"
log " Папка: $WEB_ROOT"
