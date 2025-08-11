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
    echo "*** Menu Utama VPS Auto Setup ***"
    echo "=============================="
    # Tampilkan menu lengkap dalam tabel penuh
    echo "┌───────────────────────────────────────────────┬───────────────────────────────────────────────┬───────────────────────────────────────────────┐"
    printf "│ %-37s │ %-37s │ %-37s │\n" "--- Instalasi Dasar ---" "--- Optimasi & Keamanan ---" "--- Utilitas ---"
    echo "├───────────────────────────────────────────────┼───────────────────────────────────────────────┼───────────────────────────────────────────────┤"
    printf "│ %-37s │ %-37s │ %-37s │\n" "1. Instal PHP" "11. Optimasi Server" "16. Tampilkan Info Sistem"
    printf "│ %-37s │ %-37s │ %-37s │\n" "2. Instal Nginx" "12. Instal Sistem Cache" "17. Aktifkan SSL Semua Domain"
    printf "│ %-37s │ %-37s │ %-37s │\n" "3. Instal Database" "13. Security Hardening" "18. Hapus SSL Domain"
    printf "│ %-37s │ %-37s │ %-37s │\n" "4. Instal phpMyAdmin" "14. Sistem Backup" "19. Konfigurasi systemd Node.js"
    printf "│ %-37s │ %-37s │ %-37s │\n" "5. Instal Node.js & npm" "15. Setup Dasar VPS" "20. Konfigurasi PHP"
    printf "│ %-37s │ %-37s │ %-37s │\n" "6. Instal FrankenPHP" "" "21. Setting Cron Job"
    printf "│ %-37s │ %-37s │ %-37s │\n" "7. Instal WordPress" "" ""
    printf "│ %-37s │ %-37s │ %-37s │\n" "8. Instal & Setup SSO" "" ""
    printf "│ %-37s │ %-37s │ %-37s │\n" "9. Konfigurasi Aplikasi Web" "" ""
    printf "│ %-37s │ %-37s │ %-37s │\n" "10. Konfigurasi Routing Berbasis Path" "" ""
    echo "├───────────────────────────────────────────────┴───────────────────────────────────────────────┴───────────────────────────────────────────────┤"
    printf "│ %-111s │\n" "0. Keluar"
    echo "└───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘"
    read -p "Pilihan [0-21]: " choice
    case $choice in
        1) install_php ;;
        2) install_webserver ;;
        3) install_database ;;
        4) install_phpmyadmin ;;
        5) install_nodejs ;;
        6) install_frankenphp ;;
        7) install_wordpress ;;
        8) install_sso ;;
        9) configure_webapp ;;
        10) configure_webapp_path_based ;;
        11) optimize_server ;;
        12) install_cache_system ;;
        13) security_hardening ;;
        14) setup_backup_system ;;
        15) setup_basic_vps ;;
        16) bash ./systeminfo.sh ;;
        17) offer_ssl_for_all_domains ;;
        18) hapus_ssl_for_domains ;;
        19) configure_nodejs_systemd ;;
        20) configure_php ;;
        21) configure_cronjob ;;
        99) setup_basic_vps ;;
        0) log_info "Terima kasih telah menggunakan script ini!"
           exit 0 ;;
        *) log_error "Pilihan tidak valid" ;;
    esac
    echo
    read -p "Tekan Enter untuk melanjutkan..."
done
