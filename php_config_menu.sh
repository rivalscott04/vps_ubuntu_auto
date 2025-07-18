#!/bin/bash

# Deteksi versi PHP-FPM terinstall
PHP_FPM_DIRS=(/etc/php/*/fpm)
PHP_VERSIONS=()
for dir in "${PHP_FPM_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        ver=$(echo "$dir" | awk -F'/' '{print $(NF-1)}')
        PHP_VERSIONS+=("$ver")
    fi
done

if [ ${#PHP_VERSIONS[@]} -eq 0 ]; then
    echo "Tidak ada PHP-FPM terinstall!"
    exit 1
fi

# Pilih versi jika lebih dari satu
if [ ${#PHP_VERSIONS[@]} -eq 1 ]; then
    PHP_VERSION=${PHP_VERSIONS[0]}
else
    echo "Pilih versi PHP-FPM yang ingin dikonfigurasi:"
    select ver in "${PHP_VERSIONS[@]}"; do
        PHP_VERSION=$ver
        break
    done
fi

PHP_INI="/etc/php/$PHP_VERSION/fpm/php.ini"
SERVICE_NAME="php$PHP_VERSION-fpm"

if [ ! -f "$PHP_INI" ]; then
    echo "php.ini tidak ditemukan di $PHP_INI"
    exit 1
fi

while true; do
    echo "\n=== Menu Konfigurasi PHP ($PHP_VERSION) ==="
    echo "1. Ubah memory_limit"
    echo "2. Ubah post_max_size"
    echo "3. Ubah upload_max_filesize"
    echo "4. Restart PHP-FPM"
    echo "5. Keluar"
    read -p "Pilih menu [1-5]: " menu
    case $menu in
        1)
            read -p "Masukkan nilai memory_limit (misal 256M): " val
            sed -i "s/^memory_limit = .*/memory_limit = $val/" "$PHP_INI"
            echo "memory_limit diubah menjadi $val"
            ;;
        2)
            read -p "Masukkan nilai post_max_size (misal 64M): " val
            sed -i "s/^post_max_size = .*/post_max_size = $val/" "$PHP_INI"
            echo "post_max_size diubah menjadi $val"
            ;;
        3)
            read -p "Masukkan nilai upload_max_filesize (misal 64M): " val
            sed -i "s/^upload_max_filesize = .*/upload_max_filesize = $val/" "$PHP_INI"
            echo "upload_max_filesize diubah menjadi $val"
            ;;
        4)
            systemctl restart "$SERVICE_NAME"
            echo "Service $SERVICE_NAME direstart."
            ;;
        5)
            echo "Keluar."
            break
            ;;
        *)
            echo "Menu tidak valid."
            ;;
    esac
done 