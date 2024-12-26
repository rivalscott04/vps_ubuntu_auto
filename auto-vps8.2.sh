#!/bin/bash

# Pastikan script dijalankan dengan hak akses root
if [ "$(id -u)" -ne 0 ]; then
  echo "Script ini harus dijalankan sebagai root. Gunakan sudo."
  exit 1
fi

echo "Mulai instalasi auto setup VPS Ubuntu/Debian dengan PHP 8.2..."

# Update dan upgrade sistem
echo "Mengupdate sistem..."
apt update && apt upgrade -y

# Install git
echo "Menginstall git..."
apt install -y git

# Install nginx
echo "Menginstall nginx..."
apt install -y nginx

# Install MySQL
echo "Menginstall MySQL..."
apt install -y mysql-server
# Opsional: amankan MySQL (berinteraksi langsung)
echo "Mengamankan instalasi MySQL..."
mysql_secure_installation

# Tambahkan repositori untuk PHP 8.2
echo "Menambahkan repositori PHP 8.2..."
apt install -y software-properties-common
add-apt-repository -y ppa:ondrej/php
apt update

# Install PHP 8.2 dan ekstensi yang diperlukan
echo "Menginstall PHP 8.2 dan ekstensi yang diperlukan..."
apt install -y php8.2 php8.2-fpm php8.2-cli php8.2-mysql php8.2-curl php8.2-mbstring php8.2-xml php8.2-bcmath php8.2-json php8.2-tokenizer php8.2-zip php8.2-gd

# Konfigurasi nginx untuk mendukung PHP
echo "Mengkonfigurasi nginx untuk PHP..."
cat > /etc/nginx/sites-available/default <<EOL
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /var/www/html;
    index index.php index.html index.htm;

    server_name _;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.2-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOL

# Restart layanan untuk memastikan semuanya berjalan
echo "Merestart layanan..."
systemctl restart nginx
systemctl restart php8.2-fpm
systemctl restart mysql

# Konfigurasi firewall untuk nginx (opsional)
echo "Mengkonfigurasi firewall untuk nginx..."
ufw allow 'Nginx Full'
ufw reload

# Output informasi versi perangkat lunak yang terinstal
echo "Instalasi selesai. Versi perangkat lunak yang terinstal:"
echo "Git: $(git --version)"
echo "Nginx: $(nginx -v 2>&1)"
echo "MySQL: $(mysql --version)"
echo "PHP: $(php -v)"

echo "Auto setup selesai! VPS siap digunakan."
