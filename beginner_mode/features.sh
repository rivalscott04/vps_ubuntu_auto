#!/bin/bash

run_preflight_check() {
    local domain="$1"
    local app_path="$2"
    local app_port="$3"
    local failed=0

    echo "=== Preflight Check ==="
    beginner_note "Cek ini mencegah gagal setup di tengah jalan."

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [[ "$ID" != "ubuntu" ]]; then
            log_warning "OS terdeteksi $ID. Script paling diuji di Ubuntu."
        else
            log_info "OS compatibility: OK ($PRETTY_NAME)"
        fi
    fi

    local mem_mb
    mem_mb=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo 2>/dev/null)
    if [ -n "$mem_mb" ] && [ "$mem_mb" -lt 900 ]; then
        log_warning "RAM rendah (${mem_mb}MB). Disarankan >= 1GB."
    else
        log_info "RAM check: OK (${mem_mb}MB)"
    fi

    local free_mb
    free_mb=$(df -Pm / | awk 'NR==2 {print $4}')
    if [ -n "$free_mb" ] && [ "$free_mb" -lt 2048 ]; then
        log_warning "Disk free rendah (${free_mb}MB). Disarankan >= 2GB."
        failed=1
    else
        log_info "Disk check: OK (${free_mb}MB free)"
    fi

    if [ ! -d "$app_path" ]; then
        log_error "Path aplikasi tidak ada: $app_path"
        failed=1
    else
        log_info "Path check: OK ($app_path)"
    fi

    if [ -n "$app_port" ]; then
        if ss -ltn 2>/dev/null | awk '{print $4}' | rg -n ":${app_port}$" >/dev/null 2>&1; then
            log_warning "Port $app_port sudah dipakai proses lain."
        else
            log_info "Port check: OK ($app_port available)"
        fi
    fi

    if [ -n "$domain" ]; then
        if getent hosts "$domain" >/dev/null 2>&1; then
            log_info "DNS resolve: OK ($domain)"
        else
            log_warning "DNS belum resolve untuk $domain. Lanjut boleh, tapi SSL bisa gagal."
        fi
    fi

    return $failed
}

quick_setup_wizard() {
    echo "=== Quick Setup Wizard ==="
    beginner_note "Wizard ini menggabungkan detect, preflight, setup, dan ringkasan."

    local domain app_path use_detect app_type_choice app_type app_port profile php_version run_user project_root

    while true; do
        read -r -p "Masukkan domain (contoh: app.domain.com): " domain
        if is_valid_domain "$domain"; then
            break
        fi
        log_error "Domain tidak valid."
    done

    while true; do
        read -r -p "Masukkan path project atau root monorepo (contoh: /var/www/app): " project_root
        if [ -d "$project_root" ]; then
            break
        fi
        log_error "Path tidak ditemukan."
    done

    app_path="$project_root"
    select_project_from_candidates "$project_root"
    if [ -n "$SELECTED_PROJECT_PATH" ]; then
        app_path="$SELECTED_PROJECT_PATH"
        if [ "$SELECTED_PROJECT_TYPE" != "unknown" ]; then
            app_type="$SELECTED_PROJECT_TYPE"
        fi
    fi

    read -r -p "Gunakan Auto Detect project? (y/n) [y]: " use_detect
    use_detect=${use_detect:-y}

    if [[ "$use_detect" =~ ^[Yy]$ ]]; then
        detect_app_type "$app_path"
        show_detection_result
        app_type="$DETECTED_TYPE"
    else
        app_type="unknown"
    fi

    if [ "$app_type" = "unknown" ]; then
        echo "Pilih stack manual:"
        echo "1) laravel  2) php  3) nodejs  4) nextjs  5) react-static  6) svelte-static  7) wordpress"
        read -r -p "Pilihan [1-7]: " app_type_choice
        case "$app_type_choice" in
            1) app_type="laravel" ;;
            2) app_type="php" ;;
            3) app_type="nodejs" ;;
            4) app_type="nextjs" ;;
            5) app_type="react-static" ;;
            6) app_type="svelte-static" ;;
            7) app_type="wordpress" ;;
            *) log_warning "Pilihan tidak valid, fallback ke php"; app_type="php" ;;
        esac
    fi

    ensure_stack_dependencies "$app_type"
    if [ $? -ne 0 ]; then
        log_error "Dependency minimum belum lengkap. Setup dihentikan."
        return 1
    fi

    case "$app_type" in
        laravel)
            ensure_laravel_requirements "$app_path" || return 1
            ;;
        nodejs|nextjs|react-static|svelte-static)
            ensure_node_requirements "$app_path" "$app_type" || return 1
            ;;
    esac

    if [ "$app_type" = "nodejs" ] || [ "$app_type" = "nextjs" ]; then
        while true; do
            app_port=$(prompt_with_default "Masukkan port aplikasi" "3000")
            if is_valid_port "$app_port"; then
                break
            fi
            log_error "Port tidak valid."
        done
    fi

    echo "Pilih profile performa:"
    echo "1) Hemat  2) Normal  3) High Traffic"
    read -r -p "Pilihan [1-3]: " profile_opt
    case "$profile_opt" in
        1) profile="hemat" ;;
        3) profile="high" ;;
        *) profile="normal" ;;
    esac
    set_profile_defaults "$profile"

    run_preflight_check "$domain" "$app_path" "$app_port"
    if [ $? -ne 0 ]; then
        read -r -p "Preflight ada error kritikal. Lanjut tetap? (y/n): " proceed
        [[ "$proceed" =~ ^[Yy]$ ]] || return 1
    fi

    php_version=$(detect_installed_php_version)
    run_user=$(prompt_with_default "Jalankan app sebagai user" "www-data")

    echo "=== Dry Run ==="
    echo "- Stack: $app_type"
    echo "- Domain: $domain"
    echo "- Path: $app_path"
    echo "- Profile: $profile"
    echo "- Upload max Nginx/PHP: ${PROFILE_CLIENT_MAX_BODY_SIZE}/${PROFILE_UPLOAD_MAX_FILESIZE}"
    [ -n "$app_port" ] && echo "- App port: $app_port"
    read -r -p "Lanjut eksekusi? (y/n): " go
    [[ "$go" =~ ^[Yy]$ ]] || return 1

    backup_config_snapshot "$domain" "$php_version"

    if ! render_nginx_for_app "$domain" "$app_path" "$app_type" "$app_port" "$php_version"; then
        return 1
    fi

    if [ -n "$php_version" ] && { [ "$app_type" = "laravel" ] || [ "$app_type" = "php" ] || [ "$app_type" = "wordpress" ]; }; then
        apply_php_upload_limits "$php_version" "$PROFILE_UPLOAD_MAX_FILESIZE" "$PROFILE_POST_MAX_SIZE"
    fi

    if [ "$app_type" = "laravel" ]; then
        configure_laravel_runtime "$app_path" "$run_user"
        local service_stub
        service_stub=$(echo "$domain" | tr '.' '-')
        setup_laravel_queue_scheduler "$app_path" "$service_stub" "$run_user"
    fi

    echo "=== Ringkasan Setup ==="
    echo "Aplikasi aktif di: http://${domain}"
    echo "Upload max aktif (target): ${PROFILE_CLIENT_MAX_BODY_SIZE}"
    echo "Queue Laravel: $([ "$app_type" = "laravel" ] && echo "aktif" || echo "tidak relevan")"
    echo "Scheduler Laravel: $([ "$app_type" = "laravel" ] && echo "aktif" || echo "tidak relevan")"
    echo "Next step: cek SSL dari menu advanced (opsi SSL massal)."
}

health_check_app() {
    local domain app_path php_version
    echo "=== Cek Aplikasi Saya ==="
    read -r -p "Masukkan domain aplikasi: " domain
    read -r -p "Masukkan path aplikasi (opsional): " app_path

    php_version=$(detect_installed_php_version)
    echo "- Nginx: $(systemctl is-active nginx 2>/dev/null || echo inactive)"
    if [ -n "$php_version" ]; then
        echo "- PHP-FPM (${php_version}): $(systemctl is-active php${php_version}-fpm 2>/dev/null || echo inactive)"
    fi
    echo "- DB MySQL/MariaDB: $(systemctl is-active mysql 2>/dev/null || systemctl is-active mariadb 2>/dev/null || echo inactive)"
    echo "- SSL cert: $([ -d "/etc/letsencrypt/live/${domain}" ] && echo OK || echo belum)"

    local conf="/etc/nginx/sites-available/${domain}"
    [ -f "$conf" ] || conf="/etc/nginx/sites-enabled/${domain}"
    if [ -f "$conf" ]; then
        local body_limit
        body_limit=$(rg -n "client_max_body_size" "$conf" -o 2>/dev/null | awk '{print $2}' | tail -n1)
        echo "- Nginx client_max_body_size: ${body_limit:-tidak diset (default 1M)}"
    fi

    if [ -n "$app_path" ] && [ -f "$app_path/artisan" ]; then
        if [ -d "$app_path/storage" ] && [ ! -w "$app_path/storage" ]; then
            echo "- Probable issue: permission storage Laravel"
        fi
    fi

    echo "- Diagnosa cepat:"
    echo "  * Jika error 413: naikkan client_max_body_size + post_max_size + upload_max_filesize"
    echo "  * Jika error 502: cek service app/PHP-FPM dan socket/port mismatch"
    echo "  * Jika error 500 Laravel: cek permission storage/bootstrap/cache"
}

auto_fix_common() {
    local app_path domain php_version
    echo "=== Perbaiki Cepat ==="
    read -r -p "Masukkan domain aplikasi: " domain
    read -r -p "Masukkan path app Laravel (opsional): " app_path
    php_version=$(detect_installed_php_version)

    if nginx -t >/dev/null 2>&1; then
        systemctl reload nginx
        log_info "Nginx config valid, reload sukses."
    else
        log_error "Nginx config masih error. Jalankan nginx -t untuk detail."
    fi

    if [ -n "$php_version" ]; then
        systemctl restart "php${php_version}-fpm" 2>/dev/null || true
    fi
    systemctl restart nginx 2>/dev/null || true

    if [ -n "$app_path" ] && [ -f "$app_path/artisan" ]; then
        configure_laravel_runtime "$app_path" "www-data"
        log_info "Auto-fix Laravel (permission + storage link + cache) dijalankan."
    fi

    echo "Perbaikan cepat selesai untuk domain: $domain"
}

backup_rollback_menu() {
    echo "=== Backup & Rollback ==="
    echo "1) Buat backup sekarang"
    echo "2) Rollback dari backup"
    echo "0) Kembali"
    read -r -p "Pilihan [0-2]: " opt
    case "$opt" in
        1)
            local domain php_version
            read -r -p "Masukkan domain terkait backup: " domain
            php_version=$(detect_installed_php_version)
            backup_config_snapshot "$domain" "$php_version"
            ;;
        2) rollback_from_backup ;;
        0) return ;;
        *) log_error "Pilihan tidak valid." ;;
    esac
}

simple_mode_menu() {
    while true; do
        clear
        echo "========================================="
        echo " Simple Mode (Beginner Experience)"
        echo "========================================="
        echo "1) Quick Setup Wizard (rekomendasi)"
        echo "2) Preflight Check saja"
        echo "3) Cek Aplikasi Saya (Health Check)"
        echo "4) Perbaiki Cepat (Auto Fix)"
        echo "5) Backup & Rollback"
        echo "6) Toggle Mode Belajar"
        echo "7) Pindah ke Advanced Mode"
        echo "0) Keluar"
        read -r -p "Pilihan [0-7]: " choice
        case "$choice" in
            1) quick_setup_wizard ;;
            2)
                local domain app_path app_port
                read -r -p "Domain: " domain
                read -r -p "Path app: " app_path
                read -r -p "Port app (opsional): " app_port
                run_preflight_check "$domain" "$app_path" "$app_port"
                ;;
            3) health_check_app ;;
            4) auto_fix_common ;;
            5) backup_rollback_menu ;;
            6) toggle_learning_mode ;;
            7) return 10 ;;
            0) return 0 ;;
            *) log_error "Pilihan tidak valid." ;;
        esac
        echo
        read -r -p "Tekan Enter untuk melanjutkan..."
    done
}
