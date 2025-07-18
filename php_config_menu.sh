#!/bin/bash

# Warna
GREEN='\033[1;32m'
RED='\033[1;31m'
CYAN='\033[1;36m'
NC='\033[0m'

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
    echo -e "${RED}Tidak ada PHP-FPM terinstall!${NC}"
    exit 1
fi

# Pilih versi jika lebih dari satu
if [ ${#PHP_VERSIONS[@]} -eq 1 ]; then
    PHP_VERSION=${PHP_VERSIONS[0]}
else
    echo "========================================="
    echo "| Pilih versi PHP-FPM yang ingin dikonfigurasi: |"
    echo "========================================="
    select ver in "${PHP_VERSIONS[@]}"; do
        PHP_VERSION=$ver
        break
    done
fi

PHP_INI="/etc/php/$PHP_VERSION/fpm/php.ini"
SERVICE_NAME="php$PHP_VERSION-fpm"

if [ ! -f "$PHP_INI" ]; then
    echo -e "${RED}php.ini tidak ditemukan di $PHP_INI${NC}"
    exit 1
fi

while true; do
    clear
    echo "========================================="
    echo "|      MENU KONFIGURASI PHP ($PHP_VERSION)      |"
    echo "========================================="
    echo "| 1. Tampilkan Info Setting PHP Saat Ini        |"
    echo "| 2. Ubah memory_limit                        |"
    echo "| 3. Ubah post_max_size                       |"
    echo "| 4. Ubah upload_max_filesize                 |"
    echo "| 5. Ubah max_execution_time                  |"
    echo "| 6. Ubah max_input_time                      |"
    echo "| 7. Restart PHP-FPM                          |"
    echo "| 8. Keluar                                   |"
    echo "========================================="
    read -p "Pilih menu [1-8]: " menu
    case $menu in
        1)
            # Baca settingan saat ini
            mem=$(grep -E '^memory_limit[ ]*=' "$PHP_INI" | awk -F'= ' '{print $2}')
            post=$(grep -E '^post_max_size[ ]*=' "$PHP_INI" | awk -F'= ' '{print $2}')
            upload=$(grep -E '^upload_max_filesize[ ]*=' "$PHP_INI" | awk -F'= ' '{print $2}')
            exec=$(grep -E '^max_execution_time[ ]*=' "$PHP_INI" | awk -F'= ' '{print $2}')
            input=$(grep -E '^max_input_time[ ]*=' "$PHP_INI" | awk -F'= ' '{print $2}')
            echo -e "${CYAN}========================================="
            echo -e "|   Setting PHP Saat Ini ($PHP_VERSION)        |"
            echo -e "========================================="
            printf "| %-25s : %-10s |
" "memory_limit" "$mem"
            printf "| %-25s : %-10s |
" "post_max_size" "$post"
            printf "| %-25s : %-10s |
" "upload_max_filesize" "$upload"
            printf "| %-25s : %-10s |
" "max_execution_time" "$exec"
            printf "| %-25s : %-10s |
" "max_input_time" "$input"
            echo -e "=========================================${NC}"
            echo "1. Kembali ke menu utama"
            echo "2. Keluar"
            read -p "Pilih [1-2]: " subm
            if [ "$subm" = "2" ]; then
                echo "Keluar."
                break
            fi
            ;;
        2)
            read -p "Masukkan nilai memory_limit (misal 256M): " val
            if [[ ! $val =~ ^[0-9]+[MmGg]$ ]]; then
                echo -e "${RED}Input tidak valid. Contoh: 256M atau 1G${NC}"
            else
                sed -i "s/^memory_limit = .*/memory_limit = $val/" "$PHP_INI"
                echo -e "${GREEN}memory_limit diubah menjadi $val${NC}"
            fi
            read -p "Tekan Enter untuk kembali ke menu..." _
            ;;
        3)
            read -p "Masukkan nilai post_max_size (misal 64M): " val
            if [[ ! $val =~ ^[0-9]+[MmGg]$ ]]; then
                echo -e "${RED}Input tidak valid. Contoh: 64M atau 1G${NC}"
            else
                sed -i "s/^post_max_size = .*/post_max_size = $val/" "$PHP_INI"
                echo -e "${GREEN}post_max_size diubah menjadi $val${NC}"
            fi
            read -p "Tekan Enter untuk kembali ke menu..." _
            ;;
        4)
            read -p "Masukkan nilai upload_max_filesize (misal 64M): " val
            if [[ ! $val =~ ^[0-9]+[MmGg]$ ]]; then
                echo -e "${RED}Input tidak valid. Contoh: 64M atau 1G${NC}"
            else
                sed -i "s/^upload_max_filesize = .*/upload_max_filesize = $val/" "$PHP_INI"
                echo -e "${GREEN}upload_max_filesize diubah menjadi $val${NC}"
            fi
            read -p "Tekan Enter untuk kembali ke menu..." _
            ;;
        5)
            read -p "Masukkan nilai max_execution_time (detik, contoh: 300): " val
            if [[ ! $val =~ ^[0-9]+$ ]] || [ $val -le 0 ]; then
                echo -e "${RED}Input harus berupa angka positif!${NC}"
            else
                sed -i "s/^max_execution_time = .*/max_execution_time = $val/" "$PHP_INI"
                echo -e "${GREEN}max_execution_time diubah menjadi $val${NC}"
            fi
            read -p "Tekan Enter untuk kembali ke menu..." _
            ;;
        6)
            read -p "Masukkan nilai max_input_time (detik, contoh: 300): " val
            if [[ ! $val =~ ^[0-9]+$ ]] || [ $val -le 0 ]; then
                echo -e "${RED}Input harus berupa angka positif!${NC}"
            else
                sed -i "s/^max_input_time = .*/max_input_time = $val/" "$PHP_INI"
                echo -e "${GREEN}max_input_time diubah menjadi $val${NC}"
            fi
            read -p "Tekan Enter untuk kembali ke menu..." _
            ;;
        7)
            systemctl restart "$SERVICE_NAME"
            echo -e "${GREEN}Service $SERVICE_NAME berhasil direstart.${NC}"
            read -p "Tekan Enter untuk kembali ke menu..." _
            ;;
        8)
            echo "Keluar."
            break
            ;;
        *)
            echo -e "${RED}Menu tidak valid.${NC}"
            read -p "Tekan Enter untuk kembali ke menu..." _
            ;;
    esac
done 