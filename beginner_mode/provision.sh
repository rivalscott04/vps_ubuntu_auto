#!/bin/bash

set_profile_defaults() {
    local profile="$1"
    case "$profile" in
        hemat)
            PROFILE_CLIENT_MAX_BODY_SIZE="20M"
            PROFILE_PROXY_TIMEOUT="60s"
            PROFILE_FASTCGI_TIMEOUT="60s"
            PROFILE_UPLOAD_MAX_FILESIZE="20M"
            PROFILE_POST_MAX_SIZE="24M"
            ;;
        high)
            PROFILE_CLIENT_MAX_BODY_SIZE="100M"
            PROFILE_PROXY_TIMEOUT="180s"
            PROFILE_FASTCGI_TIMEOUT="180s"
            PROFILE_UPLOAD_MAX_FILESIZE="100M"
            PROFILE_POST_MAX_SIZE="110M"
            ;;
        *)
            PROFILE_CLIENT_MAX_BODY_SIZE="50M"
            PROFILE_PROXY_TIMEOUT="120s"
            PROFILE_FASTCGI_TIMEOUT="120s"
            PROFILE_UPLOAD_MAX_FILESIZE="50M"
            PROFILE_POST_MAX_SIZE="60M"
            ;;
    esac
}

apply_php_upload_limits() {
    local php_version="$1"
    local upload_max="$2"
    local post_max="$3"
    local php_ini="/etc/php/${php_version}/fpm/php.ini"

    if [ ! -f "$php_ini" ]; then
        log_warning "php.ini tidak ditemukan di $php_ini, skip set upload limit PHP."
        return 0
    fi

    cp "$php_ini" "${php_ini}.bak.$(date +%Y%m%d%H%M%S)"
    sed -i "s/^upload_max_filesize.*/upload_max_filesize = ${upload_max}/" "$php_ini"
    sed -i "s/^post_max_size.*/post_max_size = ${post_max}/" "$php_ini"
    systemctl restart "php${php_version}-fpm" 2>/dev/null || true
    log_info "PHP limits diterapkan: upload_max_filesize=${upload_max}, post_max_size=${post_max}"
}

configure_laravel_runtime() {
    local app_path="$1"
    local run_user="$2"

    if [ ! -d "$app_path" ]; then
        return 1
    fi

    if [ -d "$app_path/storage" ] && [ -d "$app_path/bootstrap/cache" ]; then
        chown -R "${run_user}:www-data" "$app_path/storage" "$app_path/bootstrap/cache" 2>/dev/null
        chmod -R 775 "$app_path/storage" "$app_path/bootstrap/cache" 2>/dev/null
        log_info "Permission Laravel diperbaiki."
    fi

    if [ -f "$app_path/.env.example" ] && [ ! -f "$app_path/.env" ]; then
        cp "$app_path/.env.example" "$app_path/.env"
        chmod 640 "$app_path/.env"
        log_info ".env dibuat dari .env.example"
    fi

    if [ -f "$app_path/artisan" ]; then
        (
            cd "$app_path" || exit 1
            php artisan key:generate --force >/dev/null 2>&1 || true
            php artisan storage:link >/dev/null 2>&1 || true
            php artisan config:cache >/dev/null 2>&1 || true
            php artisan route:cache >/dev/null 2>&1 || true
            php artisan view:cache >/dev/null 2>&1 || true
        )
        log_info "Langkah artisan dasar selesai."
    fi
}

setup_laravel_queue_scheduler() {
    local app_path="$1"
    local service_name="$2"
    local run_user="$3"

    if [ ! -f "$app_path/artisan" ]; then
        return 0
    fi

    cat > "/etc/systemd/system/${service_name}-queue.service" <<EOF
[Unit]
Description=Laravel Queue Worker (${service_name})
After=network.target

[Service]
Type=simple
User=${run_user}
WorkingDirectory=${app_path}
ExecStart=/usr/bin/php artisan queue:work --sleep=3 --tries=3 --timeout=120
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable "${service_name}-queue.service" >/dev/null 2>&1 || true
    systemctl restart "${service_name}-queue.service" >/dev/null 2>&1 || true

    (
        crontab -l 2>/dev/null | rg -v "artisan schedule:run" || true
        echo "* * * * * cd ${app_path} && php artisan schedule:run >> /dev/null 2>&1"
    ) | crontab -
    log_info "Queue worker + scheduler Laravel diaktifkan."
}

render_nginx_for_app() {
    local domain="$1"
    local app_path="$2"
    local app_type="$3"
    local app_port="$4"
    local php_version="$5"
    local conf="/etc/nginx/sites-available/${domain}"

    case "$app_type" in
        laravel)
            cat > "$conf" <<EOF
server {
    listen 80;
    server_name ${domain};
    root ${app_path}/public;
    index index.php index.html;
    client_max_body_size ${PROFILE_CLIENT_MAX_BODY_SIZE};

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php${php_version}-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_read_timeout ${PROFILE_FASTCGI_TIMEOUT};
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF
            ;;
        php|wordpress)
            cat > "$conf" <<EOF
server {
    listen 80;
    server_name ${domain};
    root ${app_path};
    index index.php index.html;
    client_max_body_size ${PROFILE_CLIENT_MAX_BODY_SIZE};

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php${php_version}-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_read_timeout ${PROFILE_FASTCGI_TIMEOUT};
    }
}
EOF
            ;;
        nextjs|nodejs)
            cat > "$conf" <<EOF
server {
    listen 80;
    server_name ${domain};
    client_max_body_size ${PROFILE_CLIENT_MAX_BODY_SIZE};

    location / {
        proxy_pass http://127.0.0.1:${app_port};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout ${PROFILE_PROXY_TIMEOUT};
        proxy_send_timeout ${PROFILE_PROXY_TIMEOUT};
    }
}
EOF
            ;;
        react-static|svelte-static)
            cat > "$conf" <<EOF
server {
    listen 80;
    server_name ${domain};
    root ${app_path}/dist;
    index index.html;
    client_max_body_size ${PROFILE_CLIENT_MAX_BODY_SIZE};

    location / {
        try_files \$uri \$uri/ /index.html;
    }
}
EOF
            ;;
        *)
            log_error "Jenis app belum didukung wizard: $app_type"
            return 1
            ;;
    esac

    ln -sf "$conf" "/etc/nginx/sites-enabled/"
    if nginx -t >/dev/null 2>&1; then
        systemctl reload nginx
        log_info "Nginx config aktif: $conf"
        return 0
    fi

    log_error "Konfigurasi Nginx tidak valid."
    return 1
}

backup_config_snapshot() {
    local domain="$1"
    local php_version="$2"
    local ts
    ts=$(date +%Y%m%d%H%M%S)
    local backup_dir="/var/backups/vps_auto"
    mkdir -p "$backup_dir"

    local conf_a="/etc/nginx/sites-available/${domain}"
    local conf_e="/etc/nginx/sites-enabled/${domain}"
    [ -f "$conf_a" ] && cp "$conf_a" "${backup_dir}/${domain}.nginx.available.${ts}.bak"
    [ -f "$conf_e" ] && cp "$conf_e" "${backup_dir}/${domain}.nginx.enabled.${ts}.bak"

    if [ -n "$php_version" ] && [ -f "/etc/php/${php_version}/fpm/php.ini" ]; then
        cp "/etc/php/${php_version}/fpm/php.ini" "${backup_dir}/php${php_version}.ini.${ts}.bak"
    fi
    log_info "Backup snapshot dibuat di ${backup_dir}"
}

rollback_from_backup() {
    local backup_dir="/var/backups/vps_auto"
    if [ ! -d "$backup_dir" ]; then
        log_warning "Belum ada backup snapshot."
        return 1
    fi

    echo "File backup tersedia:"
    ls -1 "$backup_dir" | tail -n 20
    read -r -p "Masukkan path file backup nginx untuk restore: " backup_file
    if [ ! -f "$backup_file" ]; then
        log_error "File backup tidak ditemukan."
        return 1
    fi

    read -r -p "Restore ke file target (contoh /etc/nginx/sites-available/domain.com): " restore_target
    cp "$backup_file" "$restore_target"
    if nginx -t >/dev/null 2>&1; then
        systemctl reload nginx
        log_info "Rollback berhasil dan nginx direload."
    else
        log_error "Rollback menimbulkan config error, periksa manual."
    fi
}
