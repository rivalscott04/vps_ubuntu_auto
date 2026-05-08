#!/bin/bash

ui_badge() {
    local level="$1"
    case "$level" in
        OK)   echo -e "\033[0;32m[OK]\033[0m" ;;
        WARN) echo -e "\033[1;33m[WARN]\033[0m" ;;
        FAIL) echo -e "\033[0;31m[FAIL]\033[0m" ;;
        INFO) echo -e "\033[0;36m[INFO]\033[0m" ;;
        *) echo "[$level]" ;;
    esac
}

ui_section() {
    local title="$1"
    echo
    echo "========================================="
    echo " $title"
    echo "========================================="
}

ui_step() {
    local current="$1"
    local total="$2"
    local label="$3"
    echo -e "\033[0;36m[$current/$total]\033[0m $label"
}

advanced_action_with_progress() {
    local title="$1"
    local total_steps="$2"
    shift 2

    ui_cmd="$*"
    echo "$(ui_badge INFO) Menjalankan: $title"
    ui_step 1 "$total_steps" "Validasi awal"
    sleep 0.1
    ui_step 2 "$total_steps" "Eksekusi aksi utama"
    eval "$ui_cmd"
    local rc=$?
    if [ "$total_steps" -ge 3 ]; then
        ui_step 3 "$total_steps" "Finalisasi / verifikasi hasil"
        sleep 0.1
    fi
    if [ $rc -eq 0 ]; then
        echo "$(ui_badge OK) Selesai: $title"
    else
        echo "$(ui_badge FAIL) Gagal: $title (kode: $rc)"
    fi
    return $rc
}

run_wordpress_with_progress() {
    echo "$(ui_badge INFO) Menjalankan: Instal WordPress"
    ui_step 1 4 "Validasi dependency web stack (nginx/php)"
    ui_step 2 4 "Menjalankan instalasi WordPress"
    install_wordpress
    local rc=$?
    ui_step 3 4 "Menyiapkan konfigurasi domain/Nginx"
    ui_step 4 4 "Finalisasi dan ringkasan akses"
    [ $rc -eq 0 ] && echo "$(ui_badge OK) Selesai: Instal WordPress" || echo "$(ui_badge FAIL) Gagal: Instal WordPress (kode: $rc)"
    return $rc
}

run_sso_with_progress() {
    echo "$(ui_badge INFO) Menjalankan: Instal & Setup SSO"
    ui_step 1 4 "Validasi dependency Java dan network"
    ui_step 2 4 "Instalasi Keycloak"
    install_sso
    local rc=$?
    ui_step 3 4 "Registrasi service systemd"
    ui_step 4 4 "Finalisasi endpoint login/admin"
    [ $rc -eq 0 ] && echo "$(ui_badge OK) Selesai: Instal & Setup SSO" || echo "$(ui_badge FAIL) Gagal: Instal & Setup SSO (kode: $rc)"
    return $rc
}

run_basic_vps_with_progress() {
    echo "$(ui_badge INFO) Menjalankan: Setup Dasar VPS"
    ui_step 1 4 "Pengecekan awal environment"
    ui_step 2 4 "Update/upgrade paket sistem"
    ui_step 3 4 "Set timezone/hostname/locale"
    ui_step 4 4 "Konfigurasi firewall dan finalisasi"
    setup_basic_vps
    return $?
}

run_ssl_enable_with_progress() {
    echo "$(ui_badge INFO) Menjalankan: Aktifkan SSL Semua Domain"
    ui_step 1 4 "Deteksi domain target"
    ui_step 2 4 "Validasi DNS + akses port 80/443"
    ui_step 3 4 "Issue certificate dengan Certbot"
    ui_step 4 4 "Reload Nginx dan verifikasi"
    offer_ssl_for_all_domains
    return $?
}

run_ssl_remove_with_progress() {
    echo "$(ui_badge INFO) Menjalankan: Hapus SSL Domain"
    ui_step 1 4 "Deteksi domain bersertifikat"
    ui_step 2 4 "Konfirmasi domain yang dihapus"
    ui_step 3 4 "Hapus cert + config SSL"
    ui_step 4 4 "Reload Nginx dan verifikasi"
    hapus_ssl_for_domains
    return $?
}

run_docker_with_progress() {
    echo "$(ui_badge INFO) Menjalankan: Instal & Setup Docker"
    ui_step 1 5 "Install dependency apt/keyring"
    ui_step 2 5 "Tambah repository Docker"
    ui_step 3 5 "Install engine + compose"
    ui_step 4 5 "Enable dan start service"
    ui_step 5 5 "Post-setup group/user dan verifikasi"
    install_docker
    return $?
}

advanced_option_context() {
    local choice="$1"
    case "$choice" in
        1)  echo "Instal PHP + ekstensi. Dampak: install paket baru & service PHP-FPM."; return 0 ;;
        2)  echo "Instal Nginx. Dampak: ubah service web server aktif."; return 0 ;;
        3)  echo "Instal database. Dampak: service DB baru + setup akun."; return 0 ;;
        4)  echo "Instal phpMyAdmin. Dampak: tulis config Nginx dan web path."; return 0 ;;
        5)  echo "Instal Node/Bun runtime. Dampak: install toolchain JavaScript."; return 0 ;;
        6)  echo "Instal FrankenPHP. Dampak: tambah service app server baru."; return 0 ;;
        7)  echo "Instal WordPress. Dampak: tulis file web, Nginx config, opsional SSL."; return 0 ;;
        8)  echo "Setup SSO/Keycloak. Dampak: install Java & service Keycloak."; return 0 ;;
        9)  echo "Konfigurasi web app per domain. Dampak: tulis config Nginx."; return 0 ;;
        10) echo "Path-based routing. Dampak: satu config Nginx untuk banyak app."; return 0 ;;
        11) echo "Optimasi server (placeholder). Dampak: tergantung implementasi."; return 0 ;;
        12) echo "Instal sistem cache (placeholder). Dampak: service cache baru."; return 0 ;;
        13) echo "Security hardening (placeholder). Dampak: kebijakan sistem berubah."; return 0 ;;
        14) echo "Sistem backup (placeholder). Dampak: job backup terjadwal."; return 0 ;;
        15) echo "Setup dasar VPS. Dampak: hostname/timezone/locale/firewall."; return 0 ;;
        16) echo "Tampilkan info sistem. Dampak: read-only."; return 0 ;;
        17) echo "Aktifkan SSL semua domain. Dampak: ubah config Nginx + certbot."; return 0 ;;
        18) echo "Hapus SSL domain. Dampak: hapus cert/config SSL."; return 0 ;;
        19) echo "Konfigurasi systemd Node.js. Dampak: buat/ubah service unit."; return 0 ;;
        20) echo "Konfigurasi PHP. Dampak: ubah parameter PHP runtime."; return 0 ;;
        21) echo "Setting cronjob. Dampak: tambah job terjadwal sistem."; return 0 ;;
        22) echo "Instal Python. Dampak: install runtime + package manager."; return 0 ;;
        23) echo "Setup virtualenv Python. Dampak: buat environment project."; return 0 ;;
        24) echo "Konfigurasi systemd Python. Dampak: buat/ubah service unit."; return 0 ;;
        25) echo "Instal Docker. Dampak: install engine/container runtime."; return 0 ;;
        26) echo "Menu uninstall/cleanup. Dampak: bisa menghapus service/data."; return 0 ;;
        90) echo "Pindah ke Simple Mode."; return 0 ;;
        0)  echo "Keluar dari script."; return 0 ;;
        *)  return 1 ;;
    esac
}

advanced_requires_confirmation() {
    local choice="$1"
    case "$choice" in
        4|7|8|9|10|15|17|18|19|20|21|24|25|26) return 0 ;;
        *) return 1 ;;
    esac
}

advanced_execute_choice() {
    local choice="$1"
    case "$choice" in
        1) install_php ;;
        2) install_webserver ;;
        3) install_database ;;
        4) install_phpmyadmin ;;
        5) install_nodejs ;;
        6) install_frankenphp ;;
        7) run_wordpress_with_progress ;;
        8) run_sso_with_progress ;;
        9) configure_webapp ;;
        10) configure_webapp_path_based ;;
        11) optimize_server ;;
        12) install_cache_system ;;
        13) security_hardening ;;
        14) setup_backup_system ;;
        15) run_basic_vps_with_progress ;;
        16) bash ./systeminfo.sh ;;
        17) run_ssl_enable_with_progress ;;
        18) run_ssl_remove_with_progress ;;
        19) configure_nodejs_systemd ;;
        20) configure_php ;;
        21) configure_cronjob ;;
        22) install_python ;;
        23) setup_venv ;;
        24) configure_python_systemd ;;
        25) run_docker_with_progress ;;
        26) cleanup_menu ;;
        99) setup_basic_vps ;;
        90) return 10 ;;
        0) return 0 ;;
        *) log_error "Pilihan tidak valid"; return 1 ;;
    esac
}

advanced_mode_menu() {
while true; do
    clear
    ui_section "Advanced Mode - Menu Utama VPS Auto Setup"
    echo "┌───────────────────────────────────────────────┬───────────────────────────────────────────────┬───────────────────────────────────────────────┐"
    printf "│ %-37s │ %-37s │ %-37s │\n" "--- Instalasi Dasar ---" "--- Optimasi & Keamanan ---" "--- Utilitas ---"
    echo "├───────────────────────────────────────────────┼───────────────────────────────────────────────┼───────────────────────────────────────────────┤"
    printf "│ %-37s │ %-37s │ %-37s │\n" "1. Instal PHP" "11. Optimasi Server" "16. Tampilkan Info Sistem"
    printf "│ %-37s │ %-37s │ %-37s │\n" "2. Instal Nginx" "12. Instal Sistem Cache" "17. Aktifkan SSL Semua Domain"
    printf "│ %-37s │ %-37s │ %-37s │\n" "3. Instal Database" "13. Security Hardening" "18. Hapus SSL Domain"
    printf "│ %-37s │ %-37s │ %-37s │\n" "4. Instal phpMyAdmin" "14. Sistem Backup" "19. Konfigurasi systemd Node.js"
    printf "│ %-37s │ %-37s │ %-37s │\n" "5. Instal Node.js & npm" "15. Setup Dasar VPS" "20. Konfigurasi PHP"
    printf "│ %-37s │ %-37s │ %-37s │\n" "6. Instal FrankenPHP" "" "21. Setting Cron Job"
    printf "│ %-37s │ %-37s │ %-37s │\n" "7. Instal WordPress" "" "22. Instal Python"
    printf "│ %-37s │ %-37s │ %-37s │\n" "8. Instal & Setup SSO" "" "23. Setup Virtual Environment (venv)"
    printf "│ %-37s │ %-37s │ %-37s │\n" "9. Konfigurasi Aplikasi Web" "" "24. Konfigurasi systemd Python"
    printf "│ %-37s │ %-37s │ %-37s │\n" "10. Konfigurasi Routing Berbasis Path" "" "25. Instal & Setup Docker"
    printf "│ %-37s │ %-37s │ %-37s │\n" "" "" "26. Menu Hapus (uninstall)"
    echo "├───────────────────────────────────────────────┴───────────────────────────────────────────────┴───────────────────────────────────────────────┤"
    printf "│ %-111s │\n" "90. Pindah ke Simple Mode"
    printf "│ %-111s │\n" "0. Keluar"
    echo "└───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘"
    read -p "Pilihan [0-26/90]: " choice

    if advanced_option_context "$choice" >/dev/null 2>&1; then
        echo
        if advanced_requires_confirmation "$choice"; then
            echo "$(ui_badge WARN) $(advanced_option_context "$choice")"
            read -r -p "Lanjutkan aksi ini? (y/n): " adv_ok
            if [[ ! "$adv_ok" =~ ^[Yy]$ ]]; then
                log_info "Aksi dibatalkan."
                echo
                read -p "Tekan Enter untuk melanjutkan..."
                continue
            fi
        else
            echo "$(ui_badge INFO) $(advanced_option_context "$choice")"
        fi
    fi

    advanced_execute_choice "$choice"
    adv_result=$?
    if [ "$adv_result" -eq 10 ]; then
        return 10
    fi
    if [ "$adv_result" -eq 0 ] && [ "$choice" = "0" ]; then
        return 0
    fi

    echo
    read -p "Tekan Enter untuk melanjutkan..."
done
}
