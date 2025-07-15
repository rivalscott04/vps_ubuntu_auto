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
    printf "%-35s %-35s %-35s\n" "--- Instalasi Dasar ---" "--- Optimasi & Keamanan ---" "--- Utilitas ---"
    printf "%-35s %-35s %-35s\n" "1. Install PHP" "10. Optimasi Server" "14. Tampilkan Informasi Sistem"
    printf "%-35s %-35s %-35s\n" "2. Install Nginx" "11. Instalasi Sistem Cache" "15. Ganti User Root MySQL"
    printf "%-35s %-35s %-35s\n" "3. Install Database" "12. Security Hardening" "16. Aktifkan SSL untuk Semua Domain"
    printf "%-35s %-35s %-35s\n" "4. Install phpMyAdmin" "13. Sistem Backup" "0. Keluar"
    printf "%-35s %-35s %-35s\n" "5. Install Node.js & npm" "" ""
    printf "%-35s %-35s %-35s\n" "6. Install FrankenPHP" "" ""
    printf "%-35s %-35s %-35s\n" "7. Install WordPress" "" ""
    printf "%-35s %-35s %-35s\n" "8. Konfigurasi Aplikasi Web" "" ""
    printf "%-35s %-35s %-35s\n" "9. Konfigurasi PHP" "" ""
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
        16) offer_ssl_for_all_domains ;;
        0) log_info "Terima kasih telah menggunakan script ini!"
           exit 0 ;;
        *) log_error "Pilihan tidak valid" ;;
    esac

    echo
    read -p "Tekan Enter untuk melanjutkan..."
done
