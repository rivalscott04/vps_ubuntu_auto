#!/bin/bash

# Pastikan script dijalankan sebagai root
if [ "$(id -u)" -ne 0 ]; then
    echo "Script ini harus dijalankan sebagai root. Gunakan sudo."
    exit 1
fi

# Fungsi untuk memastikan paket terinstal
check_and_install_package() {
    if ! dpkg -l | grep -q "^ii  $1 "; then
        echo "Paket $1 belum terinstal. Apakah Anda ingin menginstalnya? (y/n)"
        read -p "Jawaban: " answer
        if [ "$answer" == "y" ]; then
            apt update && apt upgrade -y
            apt install -y $1
        else
            echo "Paket $1 diperlukan untuk menjalankan script ini."
            exit 1
        fi
    fi
}

# Fungsi menambahkan repository PHP Ondřej Surý
add_php_repository() {
    echo "Menambahkan repository PHP Ondřej Surý..."
    check_and_install_package software-properties-common
    add-apt-repository -y ppa:ondrej/php 2>/dev/null

    # Cek apakah repository berhasil ditambahkan
    if ! grep -q "ondrej/php" /etc/apt/sources.list.d/*.list 2>/dev/null; then
        echo "❌ Gagal menambahkan repository PHP dari PPA Ondřej Surý!"
        echo "Solusi yang bisa dicoba:"
        echo "- Pastikan server memiliki akses internet."
        echo "- Jalankan manual: sudo add-apt-repository ppa:ondrej/php"
        echo "- Jika gagal, gunakan PHP bawaan: sudo apt install php php-cli php-fpm"
        exit 1
    fi

    echo "✅ Repository PHP berhasil ditambahkan!"
}

# Fungsi untuk menginstal PHP
install_php() {
    add_php_repository
    apt update

    echo "Pilih versi PHP yang akan diinstall:"
    echo "1. PHP 8.1"
    echo "2. PHP 8.2"
    echo "3. PHP 8.3"
    read -p "Pilihan [1-3]: " php_choice

    case $php_choice in
        1) php_version="8.1" ;;
        2) php_version="8.2" ;;
        3) php_version="8.3" ;;
        *) echo "Pilihan tidak valid"; return ;;
    esac

    echo "Menginstal PHP $php_version..."
    apt install -y php${php_version} php${php_version}-fpm php${php_version}-cli php${php_version}-common \
                   php${php_version}-mysql php${php_version}-zip php${php_version}-gd php${php_version}-mbstring \
                   php${php_version}-curl php${php_version}-xml php${php_version}-bcmath php${php_version}-pgsql \
                   php${php_version}-intl php${php_version}-readline php${php_version}-ldap \
                   php${php_version}-msgpack php${php_version}-igbinary php${php_version}-redis

    if [ $? -eq 0 ]; then
        echo "✅ PHP ${php_version} berhasil diinstall!"
    else
        echo "❌ Gagal menginstall PHP ${php_version}!"
    fi
}

# Fungsi untuk menginstal Web Server
install_webserver() {
    echo "Pilih web server yang akan diinstall:"
    echo "1. Apache"
    echo "2. Nginx"
    read -p "Pilihan [1-2]: " server_choice

    case $server_choice in
        1) check_and_install_package apache2
           a2enmod rewrite
           systemctl restart apache2
           echo "✅ Apache terinstall!"
           ;;
        2) check_and_install_package nginx
           systemctl restart nginx
           echo "✅ Nginx terinstall!"
           ;;
        *) echo "Pilihan tidak valid" ;;
    esac
}

# Fungsi untuk menginstal Node.js & npm
install_nodejs() {
    check_and_install_package curl
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
    apt update && apt install -y nodejs
    npm install -g npm@latest
    echo "✅ Node.js dan npm berhasil diinstall!"
}

# Fungsi untuk menginstal Database (MySQL / PostgreSQL)
install_database() {
    echo "Pilih database yang akan diinstall:"
    echo "1. MySQL"
    echo "2. PostgreSQL"
    read -p "Pilihan [1-2]: " db_choice

    case $db_choice in
        1) check_and_install_package mysql-server
           mysql_secure_installation
           echo "✅ MySQL berhasil diinstall!"
           ;;
        2) check_and_install_package postgresql postgresql-contrib
           echo "✅ PostgreSQL berhasil diinstall!"
           ;;
        *) echo "Pilihan tidak valid" ;;
    esac
}

# Fungsi untuk menginstal phpMyAdmin
install_phpmyadmin() {
    check_and_install_package unzip
    check_and_install_package wget

    read -p "Masukkan alias untuk phpMyAdmin (contoh: pma): " pma_alias
    read -p "Web server yang digunakan (apache/nginx): " web_server

    mkdir -p /var/www/${pma_alias}
    wget -qO /tmp/phpmyadmin.zip https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.zip
    unzip /tmp/phpmyadmin.zip -d /tmp/
    mv /tmp/phpMyAdmin-*-all-languages/* /var/www/${pma_alias}/
    rm -rf /tmp/phpmyadmin.zip /tmp/phpMyAdmin-*-all-languages

    if [ "$web_server" = "nginx" ]; then
        check_and_install_package nginx
        systemctl restart nginx
    elif [ "$web_server" = "apache" ]; then
        check_and_install_package apache2
        systemctl restart apache2
    fi

    echo "✅ phpMyAdmin berhasil diinstall dengan alias '${pma_alias}'!"
}

# Fungsi untuk menginstal FrankenPHP
install_frankenphp() {
    check_and_install_package curl
    curl -sSL https://deb.frankenphp.dev/frankenphp.asc | gpg --dearmor -o /usr/share/keyrings/frankenphp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/frankenphp-archive-keyring.gpg] https://deb.frankenphp.dev jammy main" | tee /etc/apt/sources.list.d/frankenphp.list
    apt update && check_and_install_package frankenphp
    echo "✅ FrankenPHP berhasil diinstall!"
}

# Menu utama
while true; do
    echo "=== Auto Setup VPS Menu ==="
    echo "1. Install PHP (8.1-8.3)"
    echo "2. Install Web Server (Apache/Nginx)"
    echo "3. Install Node.js & npm"
    echo "4. Install Database (MySQL/PostgreSQL)"
    echo "5. Install phpMyAdmin"
    echo "6. Install FrankenPHP"
    echo "7. Konfigurasi Aplikasi Web"
    echo "8. Keluar"
    read -p "Pilihan [1-8]: " choice

    case $choice in
        1) install_php ;;
        2) install_webserver ;;
        3) install_nodejs ;;
        4) install_database ;;
        5) install_phpmyadmin ;;
        6) install_frankenphp ;;
        7) echo "Konfigurasi Aplikasi Web belum tersedia!" ;;
        8) echo "Terima kasih!"; exit 0 ;;
        *) echo "Pilihan tidak valid" ;;
    esac

    read -p "Tekan Enter untuk melanjutkan..."
done
