#!/bin/bash

prompt_install_dependency() {
    local dep_name="$1"
    local install_cmd="$2"
    read -r -p "Dependency '${dep_name}' belum ada. Install otomatis sekarang? (y/n): " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
        beginner_note "Menjalankan installer otomatis untuk ${dep_name}."
        eval "$install_cmd"
        return $?
    fi
    return 1
}

ensure_stack_dependencies() {
    local app_type="$1"
    local ok=0
    local php_ver

    if ! command -v nginx >/dev/null 2>&1; then
        prompt_install_dependency "Nginx" "install_webserver" || ok=1
    fi

    case "$app_type" in
        laravel|php)
            php_ver=$(detect_installed_php_version)
            if [ -z "$php_ver" ] || [ ! -S "/var/run/php/php${php_ver}-fpm.sock" ]; then
                prompt_install_dependency "PHP-FPM" "install_php" || ok=1
            fi
            ;;
        nodejs|nextjs|react-static|svelte-static)
            if ! command -v node >/dev/null 2>&1; then
                prompt_install_dependency "Node.js runtime" "_install_nodejs_npm" || ok=1
            fi
            ;;
        wordpress)
            php_ver=$(detect_installed_php_version)
            if [ -z "$php_ver" ] || [ ! -S "/var/run/php/php${php_ver}-fpm.sock" ]; then
                prompt_install_dependency "PHP-FPM" "install_php" || ok=1
            fi
            if ! command -v mysql >/dev/null 2>&1 && ! command -v mariadb >/dev/null 2>&1; then
                prompt_install_dependency "Database (MariaDB/MySQL)" "install_database" || true
            fi
            ;;
    esac

    return $ok
}

check_php_extension_loaded() {
    local ext="$1"
    php -m 2>/dev/null | rg -n "^${ext}$" >/dev/null 2>&1
}

ensure_laravel_requirements() {
    local app_path="$1"
    local missing=0

    if [ ! -f "$app_path/composer.json" ]; then
        log_warning "composer.json tidak ditemukan. Pastikan ini benar project Laravel."
    fi

    if ! command -v composer >/dev/null 2>&1; then
        prompt_install_dependency "Composer" "safe_apt_update && safe_apt_install composer" || missing=1
    fi

    local required_exts=("mbstring" "openssl" "pdo" "tokenizer" "xml" "ctype" "json" "bcmath")
    local ext
    for ext in "${required_exts[@]}"; do
        if ! check_php_extension_loaded "$ext"; then
            log_warning "Ekstensi PHP belum aktif: $ext"
            missing=1
        fi
    done

    if [ "$missing" -ne 0 ]; then
        log_warning "Requirement Laravel belum lengkap. Kamu bisa lanjut, tapi ada risiko runtime error."
        read -r -p "Tetap lanjut setup? (y/n): " ans
        [[ "$ans" =~ ^[Yy]$ ]] || return 1
    fi

    if command -v composer >/dev/null 2>&1 && [ -f "$app_path/composer.json" ]; then
        read -r -p "Jalankan 'composer install' sekarang (jika vendor belum ada)? (y/n): " do_compose
        if [[ "$do_compose" =~ ^[Yy]$ ]]; then
            (cd "$app_path" && composer install --no-interaction --prefer-dist) || {
                log_warning "composer install gagal. Cek konfigurasi/project lock."
            }
        fi
    fi

    return 0
}

ensure_node_requirements() {
    local app_path="$1"
    local app_type="$2"

    if [ ! -f "$app_path/package.json" ]; then
        log_warning "package.json tidak ditemukan."
        return 1
    fi

    if ! command -v npm >/dev/null 2>&1; then
        prompt_install_dependency "npm" "_install_nodejs_npm" || return 1
    fi

    if [ "$app_type" = "nextjs" ]; then
        if ! rg -n "\"next\"" "$app_path/package.json" >/dev/null 2>&1; then
            log_warning "Next.js dipilih, tapi dependency 'next' tidak terdeteksi di package.json."
        fi
    fi

    read -r -p "Jalankan install dependencies JS sekarang (npm install)? (y/n): " do_npm
    if [[ "$do_npm" =~ ^[Yy]$ ]]; then
        (cd "$app_path" && npm install) || {
            log_warning "npm install gagal. Cek koneksi atau package config."
        }
    fi
    return 0
}
