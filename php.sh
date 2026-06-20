#!/bin/bash

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

clear
echo -e "${CYAN}"
echo "=================================================="
echo "          🚀 AUTO INSTALL PHPMYADMIN v1.0      "
echo "     Subdirectory Installer (e.g., domain.com/phpmyadmin)"
echo "             by Spacehost Cloud                  "
echo "=================================================="
echo -e "${NC}"

read -p "👤 Masukkan username database MySQL: " DBUSER
read -p "🔑 Masukkan password untuk user MySQL [$DBUSER]: " DBPASS

echo -e "\n${YELLOW}========================================"
echo "🔧 Mulai Proses Instalasi phpMyAdmin..."
echo "📍 Lokasi     : /phpmyadmin"
echo "👤 DB User    : $DBUSER"
echo "🔐 DB Password: $DBPASS"
echo "========================================${NC}\n"
sleep 2

echo -e "${CYAN}📦 Menginstal dependensi...${NC}"
sudo apt update
sudo apt install -y wget unzip php php-fpm php-mysql mariadb-server > /dev/null

echo -e "${CYAN}📥 Mengunduh phpMyAdmin...${NC}"
wget -q https://files.phpmyadmin.net/phpMyAdmin/5.2.1/phpMyAdmin-5.2.1-all-languages.zip
unzip -q phpMyAdmin-5.2.1-all-languages.zip
sudo mv phpMyAdmin-5.2.1-all-languages /usr/share/phpmyadmin
rm -rf phpMyAdmin-5.2.1-all-languages*

echo -e "${CYAN}⚙️  Konfigurasi phpMyAdmin...${NC}"
cd /usr/share/phpmyadmin
cp config.sample.inc.php config.inc.php
BLOWFISH=$(openssl rand -base64 32)
sed -i "s|\['blowfish_secret'\] = ''|['blowfish_secret'] = '$BLOWFISH'|g" config.inc.php
echo "\$cfg['TempDir'] = '/tmp';" >> config.inc.php

echo -e "${CYAN}🔗 Membuat symlink ke direktori Pterodactyl...${NC}"
sudo ln -s /usr/share/phpmyadmin /var/www/pterodactyl/public/phpmyadmin

echo -e "${CYAN}🔒 Mengatur permission...${NC}"
sudo chown -R www-data:www-data /usr/share/phpmyadmin
sudo chmod -R 755 /usr/share/phpmyadmin

echo -e "${CYAN}🗄️  Konfigurasi MySQL...${NC}"
sudo mysql -u root <<MYSQL_SCRIPT
CREATE USER IF NOT EXISTS '$DBUSER'@'%' IDENTIFIED BY '$DBPASS';
GRANT ALL PRIVILEGES ON *.* TO '$DBUSER'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
MYSQL_SCRIPT

echo -e "${CYAN}🔓 Membuka akses remote MySQL...${NC}"
sudo sed -i "s/^bind-address\s*=.*/bind-address = 0.0.0.0/" /etc/mysql/mariadb.conf.d/50-server.cnf
sudo systemctl restart mysql mariadb

echo -e "\n${GREEN}✅ Instalasi Selesai!${NC}"
echo -e "🌐 Akses phpMyAdmin: ${CYAN}https://domain-anda.com/phpmyadmin${NC}"
echo -e "👤 Username MySQL  : ${YELLOW}$DBUSER${NC}"
echo -e "🔐 Password MySQL  : ${YELLOW}$DBPASS${NC}"
echo ""