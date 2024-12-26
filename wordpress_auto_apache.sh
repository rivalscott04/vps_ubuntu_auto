#!/bin/bash

# Cek apakah script dijalankan sebagai root
if [ "$EUID" -ne 0 ]; then
    echo "Mohon jalankan script ini sebagai root."
    exit 1
fi

# Variabel
PHP_VERSION=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
PHP_INI="/etc/php/$PHP_VERSION/apache2/php.ini"

# Meminta input nama website dari pengguna
read -p "Masukkan nama website Anda: " WEBSITE_NAME
WP_DIR="/var/www/html/$WEBSITE_NAME"

# Meminta input untuk konfigurasi PHP
read -p "Masukkan memory_limit (contoh: 256M): " MEMORY_LIMIT
read -p "Masukkan max_execution_time (contoh: 300): " MAX_EXECUTION_TIME
read -p "Masukkan max_upload_filesize (contoh: 64M): " MAX_UPLOAD_FILESIZE

# Cek versi PHP
if [[ "$PHP_VERSION" == "8.2" || "$PHP_VERSION" == "8.1" ]]; then
    echo "PHP versi $PHP_VERSION terdeteksi. Melakukan konfigurasi tambahan..."
    sed -i "s/^memory_limit = .*/memory_limit = $MEMORY_LIMIT/" $PHP_INI
    sed -i "s/^max_execution_time = .*/max_execution_time = $MAX_EXECUTION_TIME/" $PHP_INI
    sed -i "s/^upload_max_filesize = .*/upload_max_filesize = $MAX_UPLOAD_FILESIZE/" $PHP_INI
    sed -i "s/^post_max_size = .*/post_max_size = $MAX_UPLOAD_FILESIZE/" $PHP_INI
    systemctl restart apache2
else
    echo "PHP versi $PHP_VERSION terdeteksi. Tidak ada konfigurasi tambahan dilakukan."
fi

# Unduh dan ekstrak WordPress
wget https://wordpress.org/latest.zip -O /tmp/wordpress.zip
unzip /tmp/wordpress.zip -d /tmp/
mv /tmp/wordpress/* $WP_DIR
rm -rf /tmp/wordpress
chown -R www-data:www-data $WP_DIR
chmod -R 755 $WP_DIR

# Selesai
echo "Instalasi WordPress selesai! Akses situs Anda melalui URL: http://$(hostname -I | awk '{print $1}')/$WEBSITE_NAME"
