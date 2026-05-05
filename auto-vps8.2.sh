#!/bin/bash

# Source helper files
source "$(dirname "$0")/advanced_mode/bootstrap.sh"
source "$(dirname "$0")/beginner_mode.sh"

# Pastikan script dijalankan sebagai root
if [ "$(id -u)" -ne 0 ]; then
    log_error "Script ini harus dijalankan sebagai root. Gunakan sudo."
    exit 1
fi

while true; do
    clear
    echo "=================================="
    echo " VPS Auto Setup - Pilih Mode"
    echo "=================================="
    echo "1) Simple Mode (Recommended)"
    echo "2) Advanced Mode"
    echo "0) Keluar"
    read -r -p "Pilihan [0-2]: " mode_choice

    case "$mode_choice" in
        1)
            simple_mode_menu
            mode_result=$?
            if [ "$mode_result" -eq 0 ]; then
                log_info "Terima kasih telah menggunakan script ini!"
                exit 0
            fi
            ;;
        2)
            advanced_mode_menu
            mode_result=$?
            if [ "$mode_result" -eq 0 ]; then
                log_info "Terima kasih telah menggunakan script ini!"
                exit 0
            fi
            ;;
        0)
            log_info "Terima kasih telah menggunakan script ini!"
            exit 0
            ;;
        *)
            log_error "Pilihan tidak valid."
            read -r -p "Tekan Enter untuk melanjutkan..."
            ;;
    esac
done
