#!/bin/bash

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

PMA_VERSION="5.2.1"

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Jalankan sebagai root: sudo bash $0${NC}"
  exit 1
fi

clear
echo -e "${CYAN}"
echo "=================================================="
echo "        🚀 AUTO INSTALL PHPMYADMIN (IP PUBLIK)      "
echo "        Nginx + PHP-FPM + MariaDB (Standalone)      "
echo "=================================================="
echo -e "${NC}"

read -p "👤 Masukkan username database MySQL baru: " DBUSER
read -s -p "🔑 Masukkan password untuk user [$DBUSER]: " DBPASS
echo ""
read -p "🌐 Port akses phpMyAdmin [8080]: " PMA_PORT
PMA_PORT=${PMA_PORT:-8080}

if [[ "$DBPASS" == *"'"* ]]; then
  echo -e "${RED}Password tidak boleh mengandung tanda petik tunggal (').${NC}"
  exit 1
fi

# Deteksi IP publik VPS
PUBLIC_IP=$(curl -s -4 --max-time 5 ifconfig.me || curl -s -4 --max-time 5 icanhazip.com || hostname -I | awk '{print $1}')

echo -e "\n${YELLOW}========================================"
echo "🔧 Mulai Proses Instalasi phpMyAdmin..."
echo "📍 Alamat     : http://$PUBLIC_IP:$PMA_PORT"
echo "👤 DB User    : $DBUSER"
echo "========================================${NC}\n"
sleep 2

echo -e "${CYAN}📦 Menginstal dependensi...${NC}"
export DEBIAN_FRONTEND=noninteractive
apt update
apt install -y wget unzip curl openssl nginx php-fpm php-mysql php-mbstring php-xml php-zip php-curl php-gd mariadb-server

PHPV=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
PHP_SOCK="/run/php/php${PHPV}-fpm.sock"

echo -e "${CYAN}📥 Mengunduh phpMyAdmin $PMA_VERSION...${NC}"
cd /tmp
wget -q "https://files.phpmyadmin.net/phpMyAdmin/${PMA_VERSION}/phpMyAdmin-${PMA_VERSION}-all-languages.zip" || { echo -e "${RED}Gagal mengunduh phpMyAdmin.${NC}"; exit 1; }
unzip -q -o "phpMyAdmin-${PMA_VERSION}-all-languages.zip"
rm -rf /usr/share/phpmyadmin
mv "phpMyAdmin-${PMA_VERSION}-all-languages" /usr/share/phpmyadmin
rm -f "phpMyAdmin-${PMA_VERSION}-all-languages.zip"

echo -e "${CYAN}⚙️  Konfigurasi phpMyAdmin...${NC}"
cd /usr/share/phpmyadmin
cp config.sample.inc.php config.inc.php
BLOWFISH=$(openssl rand -hex 16)
sed -i "s|\['blowfish_secret'\] = ''|['blowfish_secret'] = '$BLOWFISH'|g" config.inc.php
echo "\$cfg['TempDir'] = '/tmp';" >> config.inc.php
echo "\$cfg['ExecTimeLimit'] = 0;" >> config.inc.php

echo -e "${CYAN}📈 Menaikkan batas upload PHP (import SQL besar)...${NC}"
cat > /etc/php/${PHPV}/fpm/conf.d/99-phpmyadmin.ini <<EOF
upload_max_filesize = 1024M
post_max_size = 1024M
memory_limit = 1024M
max_execution_time = 900
max_input_time = 900
EOF

echo -e "${CYAN}🌐 Konfigurasi Nginx...${NC}"
cat > /etc/nginx/sites-available/phpmyadmin <<EOF
server {
    listen ${PMA_PORT};
    listen [::]:${PMA_PORT};
    server_name _;

    root /usr/share/phpmyadmin;
    index index.php;

    client_max_body_size 1024M;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:${PHP_SOCK};
        fastcgi_read_timeout 900;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF
ln -sf /etc/nginx/sites-available/phpmyadmin /etc/nginx/sites-enabled/phpmyadmin

echo -e "${CYAN}🔒 Mengatur permission...${NC}"
chown -R www-data:www-data /usr/share/phpmyadmin
chmod -R 755 /usr/share/phpmyadmin

echo -e "${CYAN}🗄️  Konfigurasi MariaDB...${NC}"
systemctl enable --now mariadb
mysql -u root <<MYSQL_SCRIPT
CREATE USER IF NOT EXISTS '$DBUSER'@'localhost' IDENTIFIED BY '$DBPASS';
GRANT ALL PRIVILEGES ON *.* TO '$DBUSER'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;
MYSQL_SCRIPT

# Buka firewall jika ufw aktif
if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
  echo -e "${CYAN}🧱 Membuka port $PMA_PORT di UFW...${NC}"
  ufw allow ${PMA_PORT}/tcp
fi

echo -e "${CYAN}🔄 Restart layanan...${NC}"
nginx -t && systemctl enable --now nginx && systemctl restart nginx
systemctl restart php${PHPV}-fpm

echo -e "\n${GREEN}✅ Instalasi Selesai!${NC}"
echo -e "🌐 Akses phpMyAdmin: ${CYAN}http://$PUBLIC_IP:$PMA_PORT${NC}"
echo -e "👤 Username MySQL  : ${YELLOW}$DBUSER${NC}"
echo -e "📦 Batas upload    : 1024 MB"
echo -e "${YELLOW}⚠️  Jika tidak bisa dibuka, pastikan port $PMA_PORT diizinkan di firewall/security group provider VPS.${NC}"
echo ""
