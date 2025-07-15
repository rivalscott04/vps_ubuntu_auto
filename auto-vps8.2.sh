#!/bin/bash

# Source helper files
source "$(dirname "$0")/utils.sh"
source "$(dirname "$0")/installers.sh"
source "$(dirname "$0")/configurators.sh"

# Pastikan script dijalankan sebagai root
if [ "$(id -u)" -ne 0 ]; then
    log_error "Script ini harus dijalankan sebagai root. Gunakan sudo."
    exit 1
fi

while true; do
    clear
    echo "=============================="
    echo "     Auto Setup VPS Menu     "
    echo "=============================="
    echo "--- Instalasi Dasar ---"
    echo "1. Install PHP"
    echo "2. Install Nginx"
    echo "3. Install Database"
    echo "4. Install phpMyAdmin"
    echo "5. Install Node.js & npm"
    echo "6. Install FrankenPHP"
    echo "7. Install WordPress"
    echo "8. Konfigurasi Aplikasi Web"
    echo "9. Konfigurasi PHP"
    echo
    echo "--- Optimasi & Keamanan ---"
    echo "10. Optimasi Server"
    echo "11. Instalasi Sistem Cache"
    echo "12. Security Hardening"
    echo "13. Sistem Backup"
    echo
    echo "--- Utilitas ---"
    echo "14. Tampilkan Informasi Sistem"
    echo "15. Ganti User Root MySQL"
    echo "0. Keluar"
    echo "=============================="
    read -p "Pilihan [0-15]: " choice

    case $choice in
        1) install_php ;;
        2) install_webserver ;;
        3) install_database ;;
        4) install_phpmyadmin ;;
        5) install_nodejs ;;
        6) install_frankenphp ;;
        7) install_wordpress ;;
        8) configure_webapp ;;
        9) configure_php ;;
        10) optimize_server ;;
        11) install_cache_system ;;
        12) security_hardening ;;
        13) setup_backup_system ;;
        14) show_system_info ;;
        15) mysql_change_root ;;
        0) log_info "Terima kasih telah menggunakan script ini!"
           exit 0 ;;
        *) log_error "Pilihan tidak valid" ;;
    esac

    echo
    read -p "Tekan Enter untuk melanjutkan..."
done
