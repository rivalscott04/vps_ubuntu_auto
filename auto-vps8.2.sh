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
    echo "*** HARUS! Setup Dasar VPS (Update, Hostname, Timezone, Locale, Firewall) ***"
    echo "=============================="
    # Cek status setup dasar VPS
    setup_done=1
    missing=""
    [ -f /etc/vps_setup_done_update ] || { setup_done=0; missing+="Update & Upgrade, "; }
    [ -f /etc/vps_setup_done_hostname ] || { setup_done=0; missing+="Hostname, "; }
    [ -f /etc/vps_setup_done_timezone ] || { setup_done=0; missing+="Timezone, "; }
    [ -f /etc/vps_setup_done_locale ] || { setup_done=0; missing+="Locale, "; }
    [ -f /etc/vps_setup_done_ufw ] || { setup_done=0; missing+="UFW (Firewall), "; }
    if [ $setup_done -eq 0 ]; then
        echo -e "\e[1;33m[WAJIB]\e[0m Anda harus menyelesaikan Setup Dasar VPS sebelum menggunakan menu lain."
        echo "Langkah belum selesai: ${missing%, }"
        echo
        echo "99. Setup Dasar VPS (Update, Hostname, Timezone, Locale, Firewall)"
        echo "0. Keluar"
        echo "=============================="
        read -p "Pilihan [99/0]: " choice
        case $choice in
            99) setup_basic_vps ;;
            0) log_info "Terima kasih telah menggunakan script ini!"; exit 0 ;;
            *) log_error "Pilihan tidak valid. Selesaikan Setup Dasar VPS terlebih dahulu!" ;;
        esac
        echo
        read -p "Tekan Enter untuk melanjutkan..."
        continue
    fi
    # Jika setup dasar sudah selesai, tampilkan menu lengkap
    printf "%-35s %-35s %-35s\n" "--- Instalasi Dasar ---" "--- Optimasi & Keamanan ---" "--- Utilitas ---"
    printf "%-35s %-35s %-35s\n" "1. Install PHP" "10. Optimasi Server" "14. Tampilkan Informasi Sistem"
    printf "%-35s %-35s %-35s\n" "2. Install Nginx" "11. Instalasi Sistem Cache" "15. Ganti User Root MySQL"
    printf "%-35s %-35s %-35s\n" "3. Install Database" "12. Security Hardening" "16. Aktifkan SSL untuk Semua Domain"
    printf "%-35s %-35s %-35s\n" "4. Install phpMyAdmin" "13. Sistem Backup" ""
    printf "%-35s %-35s %-35s\n" "5. Install Node.js & npm" "" ""
    printf "%-35s %-35s %-35s\n" "6. Install FrankenPHP" "" "18. Cek Ekstensi PHP Terinstall"
    printf "%-35s %-35s %-35s\n" "7. Install WordPress" "" ""
    printf "%-35s %-35s %-35s\n" "8. Konfigurasi Aplikasi Web" "" ""
    printf "%-35s %-35s %-35s\n" "9. Konfigurasi PHP" "" ""
    printf "%-105s\n" "0. Keluar"
    echo "=============================="
    read -p "Pilihan [0-16]: " choice
    case $choice in
        99) setup_basic_vps ;;
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
        14) bash ./systeminfo.sh ;;
        15) mysql_change_root ;;
        16) offer_ssl_for_all_domains ;;
        18) check_installed_php_extensions ;;
        0) log_info "Terima kasih telah menggunakan script ini!"
           exit 0 ;;
        *) log_error "Pilihan tidak valid" ;;
    esac
    echo
    read -p "Tekan Enter untuk melanjutkan..."
done
