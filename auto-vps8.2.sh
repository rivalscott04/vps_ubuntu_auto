#!/bin/bash

# Pastikan script dijalankan sebagai root
if [ "$(id -u)" -ne 0 ]; then
    echo "Script ini harus dijalankan sebagai root. Gunakan sudo."
    exit 1
fi

# Fungsi untuk memastikan paket tertentu sudah terinstal
check_and_install_package() {
    if ! dpkg -l | grep -q "^ii  $1 "; then
        echo "Paket $1 belum terinstal. Apakah Anda ingin menginstalnya? (y/n)"
        read -p "Jawaban: " answer
        if [ "$answer" == "y" ]; then
            apt update && apt upgrade -y
            apt install -y $1
        else
            echo "Paket $1 diperlukan untuk menjalankan fitur ini."
            exit 1
        fi
    fi
}

# Fungsi untuk menambahkan PPA hanya jika belum ada
add_ppa_if_needed() {
    local ppa_name=$1
    local ppa_list="/etc/apt/sources.list.d/${ppa_name}*.list"

    if ls $ppa_list 1> /dev/null 2>&1; then
        echo "✅ PPA $ppa_name sudah ditambahkan, tidak perlu menambahkan ulang."
    else
        echo "🔄 Menambahkan PPA $ppa_name..."
        add-apt-repository -y ppa:$ppa_name
        apt update && apt upgrade -y
    fi
}

# Fungsi untuk menambahkan PPA Web Server
add_webserver_ppa() {
    echo "🔧 Menyesuaikan PPA untuk Web Server..."

    if dpkg -l | grep -q "apache2"; then
        add_ppa_if_needed "ondrej/apache2"
    elif dpkg -l | grep -q "nginx"; then
        echo "Pilih versi Nginx yang akan diinstall:"
        echo "1. Nginx Mainline (ppa:ondrej/nginx-mainline)"
        echo "2. Nginx Stable (ppa:ondrej/nginx)"
        read -p "Pilihan [1-2]: " nginx_choice

        case $nginx_choice in
            1) add_ppa_if_needed "ondrej/nginx-mainline" ;;
            2) add_ppa_if_needed "ondrej/nginx" ;;
            *) echo "Pilihan tidak valid, menggunakan default (Stable)."
               add_ppa_if_needed "ondrej/nginx" ;;
        esac
    fi
}

# Fungsi untuk menambahkan PPA PHP
add_php_repository() {
    echo "🔧 Menyesuaikan PPA untuk PHP..."
    add_ppa_if_needed "ondrej/php"
}

# Fungsi untuk menginstal PHP
install_php() {
    add_webserver_ppa
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

    apt install -y php${php_version} php${php_version}-fpm php${php_version}-cli \
                   php${php_version}-common php${php_version}-mysql php${php_version}-zip \
                   php${php_version}-gd php${php_version}-mbstring php${php_version}-curl \
                   php${php_version}-xml php${php_version}-bcmath php${php_version}-pgsql \
                   php${php_version}-intl php${php_version}-readline php${php_version}-ldap \
                   php${php_version}-msgpack php${php_version}-igbinary php${php_version}-redis

    echo "✅ PHP ${php_version} berhasil diinstall!"
}

# Fungsi untuk mengonfigurasi PHP
configure_php() {
    if ! command -v php &> /dev/null; then
        echo "❌ PHP belum diinstall! Silakan install PHP terlebih dahulu."
        return
    fi

    php_version=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
    php_ini_file="/etc/php/${php_version}/fpm/php.ini"

    if [ ! -f "$php_ini_file" ]; then
        echo "❌ File php.ini tidak ditemukan di $php_ini_file"
        return
    fi

    echo "🔧 Konfigurasi PHP ($php_ini_file)"
    
    read -p "Masukkan batas memori (default: 256M): " memory_limit
    memory_limit=${memory_limit:-256M}

    read -p "Masukkan batas ukuran file upload (default: 50M): " upload_max_filesize
    upload_max_filesize=${upload_max_filesize:-50M}

    read -p "Masukkan batas ukuran post (default: 50M): " post_max_size
    post_max_size=${post_max_size:-50M}

    read -p "Aktifkan error reporting? (On/Off, default: On): " display_errors
    display_errors=${display_errors:-On}

    read -p "Pilih level error reporting (default: E_ALL): " error_reporting
    error_reporting=${error_reporting:-E_ALL}

    read -p "Masukkan zona waktu (contoh: Europe/Paris, default: UTC): " timezone
    timezone=${timezone:-UTC}

    sed -i "s/^memory_limit = .*/memory_limit = $memory_limit/" $php_ini_file
    sed -i "s/^upload_max_filesize = .*/upload_max_filesize = $upload_max_filesize/" $php_ini_file
    sed -i "s/^post_max_size = .*/post_max_size = $post_max_size/" $php_ini_file
    sed -i "s/^display_errors = .*/display_errors = $display_errors/" $php_ini_file
    sed -i "s/^error_reporting = .*/error_reporting = $error_reporting/" $php_ini_file
    sed -i "s|^;date.timezone =.*|date.timezone = $timezone|" $php_ini_file

    systemctl restart php${php_version}-fpm

    echo "✅ Konfigurasi PHP berhasil diperbarui!"
}

# Menu utama
while true; do
    echo "=== Auto Setup VPS Menu ==="
    echo "1. Install PHP (8.1-8.3)"
    echo "2. Install Web Server (Apache/Nginx)"
    echo "3. Install Database (MySQL/PostgreSQL)"
    echo "4. Install phpMyAdmin"
    echo "5. Install Node.js & npm (BELUM TERSEDIA)"
    echo "6. Install FrankenPHP (BELUM TERSEDIA)"
    echo "7. Konfigurasi Aplikasi Web (BELUM TERSEDIA)"
    echo "8. Konfigurasi PHP"
    echo "9. Keluar"
    read -p "Pilihan [1-9]: " choice

    case $choice in
        1) install_php ;;
        2) install_webserver ;;
        3) install_database ;;
        4) install_phpmyadmin ;;
        5) echo "🚀 Installasi Node.js belum tersedia!" ;;
        6) echo "🚀 Installasi FrankenPHP belum tersedia!" ;;
        7) echo "🚀 Konfigurasi Aplikasi Web belum tersedia!" ;;
        8) configure_php ;;
        9) echo "Terima kasih!"; exit 0 ;;
        *) echo "Pilihan tidak valid" ;;
    esac

    read -p "Tekan Enter untuk melanjutkan..."
done
