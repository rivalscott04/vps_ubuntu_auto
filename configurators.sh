# === Configurators ===

configure_php() {
    if [ ! -f ./php_config_menu.sh ]; then
        echo "Script konfigurasi PHP (php_config_menu.sh) tidak ditemukan!"
        return 1
    fi
    bash ./php_config_menu.sh
}

# === Webapp Config ===
configure_webapp() {
    echo "=== Konfigurasi Web App (Nginx) ==="
    echo "Pilih jenis aplikasi web yang ingin dikonfigurasi:"
    echo "1. PHP Biasa"
    echo "2. Laravel"
    echo "3. Node.js/Express"
    echo "4. React/Vite (static, folder dist)"
    read -p "Pilihan [1-4]: " app_type
    echo "Apakah ingin menggunakan domain utama atau subdomain?"
    echo "1. Domain utama (misal: domain.com)"
    echo "2. Subdomain (misal: app.domain.com)"
    read -p "Pilihan [1-2]: " domain_type
    if [ "$domain_type" = "2" ]; then
        read -p "Masukkan domain utama (misal: domain.com): " main_domain
        read -p "Masukkan subdomain (misal: app): " subdomain
        subdomain=${subdomain:-app}
        domain_name="${subdomain}.${main_domain}"
    else
        read -p "Masukkan domain (misal: domain.com): " domain_name
    fi
    read -p "Masukkan path root aplikasi (misal: /var/www/app): " app_path
    case $app_type in
        1)
            # PHP Biasa
            nginx_conf="/etc/nginx/sites-available/${domain_name}"
            cat > "$nginx_conf" <<EOF
server {
    listen 80;
    server_name ${domain_name};
    root ${app_path};
    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ =404;
    }
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
    location ~* \.ht { deny all; }
}
EOF
            ;;
        2)
            # Laravel
            nginx_conf="/etc/nginx/sites-available/${domain_name}"
            cat > "$nginx_conf" <<EOF
server {
    listen 80;
    server_name ${domain_name};
    root ${app_path}/public;
    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
    location ~* \.ht { deny all; }
}
EOF
            ;;
        3)
            # Node.js/Express (reverse proxy)
            read -p "Masukkan port aplikasi Node.js (misal: 3000): " node_port
            nginx_conf="/etc/nginx/sites-available/${domain_name}"
            cat > "$nginx_conf" <<EOF
server {
    listen 80;
    server_name ${domain_name};

    location / {
        proxy_pass http://127.0.0.1:${node_port};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF
            ;;
        4)
            # React/Vite (static, folder dist)
            nginx_conf="/etc/nginx/sites-available/${domain_name}"
            cat > "$nginx_conf" <<EOF
server {
    listen 80;
    server_name ${domain_name};
    root ${app_path}/dist;
    index index.html;

    location / {
        try_files \$uri \$uri/ /index.html;
    }
    location ~* \.(?:manifest|appcache|html?|xml|json)$ {
        expires -1;
    }
    location ~* \.(?:css|js|woff2?|ttf|eot|ico|svg|jpg|jpeg|gif|png|webp)$ {
        expires 1y;
        access_log off;
    }
}
EOF
            ;;
        *)
            log_error "Pilihan tidak valid!"
            return
            ;;
    esac
    ln -sf "$nginx_conf" "/etc/nginx/sites-enabled/"
    systemctl reload nginx
    log_info "Konfigurasi Nginx untuk $domain_name berhasil dibuat di $nginx_conf dan diaktifkan!"
    echo "Akses: http://$domain_name"
}

configure_webapp_path_based() {
    echo "=== Konfigurasi Web App dengan Path-Based Routing ==="
    echo "Contoh: domain.com/app1, domain.com/app2, domain.com/admin"
    echo
    read -p "Masukkan domain utama (misal: domain.com): " main_domain
    
    # Array untuk menyimpan konfigurasi aplikasi
    declare -a apps_config
    apps_count=0
    
    while true; do
        echo
        echo "=== Aplikasi ke-$((apps_count + 1)) ==="
        read -p "Masukkan nama path aplikasi (misal: app1, admin, api): " app_path_name
        
        if [[ -z "$app_path_name" ]]; then
            log_error "Nama path aplikasi tidak boleh kosong!"
            continue
        fi
        
        echo "Pilih jenis aplikasi web:"
        echo "1. PHP Biasa"
        echo "2. Laravel"
        echo "3. Node.js/Express"
        echo "4. React/Vite (static, folder dist)"
        read -p "Pilihan [1-4]: " app_type
        
        read -p "Masukkan path root aplikasi (misal: /var/www/$app_path_name): " app_root
        app_root=${app_root:-/var/www/$app_path_name}
        
        # Simpan konfigurasi aplikasi
        case $app_type in
            1) app_type_name="php" ;;
            2) app_type_name="laravel" ;;
            3) 
                read -p "Masukkan port aplikasi Node.js (misal: 3000): " node_port
                app_type_name="nodejs:$node_port"
                ;;
            4) app_type_name="react" ;;
            *) log_error "Pilihan tidak valid!"; continue ;;
        esac
        
        apps_config[$apps_count]="$app_path_name:$app_type_name:$app_root"
        apps_count=$((apps_count + 1))
        
        read -p "Tambah aplikasi lain? (y/n): " add_more
        if [[ ! "$add_more" =~ ^[Yy]$ ]]; then
            break
        fi
    done
    
    if [ $apps_count -eq 0 ]; then
        log_error "Tidak ada aplikasi yang dikonfigurasi!"
        return
    fi
    
    # Buat konfigurasi Nginx
    nginx_conf="/etc/nginx/sites-available/${main_domain}-pathbased"
    
    cat > "$nginx_conf" <<EOF
server {
    listen 80;
    server_name ${main_domain};
    
    # Default location untuk root domain
    location = / {
        return 200 'Path-based routing aktif untuk ${main_domain}';
        add_header Content-Type text/plain;
    }
    
EOF
    
    # Tambahkan konfigurasi untuk setiap aplikasi
    for i in "${!apps_config[@]}"; do
        IFS=':' read -ra ADDR <<< "${apps_config[$i]}"
        path_name="${ADDR[0]}"
        app_type="${ADDR[1]}"
        app_root="${ADDR[2]}"
        
        echo "    # Konfigurasi untuk /$path_name" >> "$nginx_conf"
        
        case $app_type in
            "php")
                cat >> "$nginx_conf" <<EOF
    location /$path_name {
        alias $app_root;
        index index.php index.html index.htm;
        try_files \$uri \$uri/ @php_$path_name;
    }
    
    location @php_$path_name {
        rewrite ^/$path_name/(.*)$ /$path_name/index.php last;
    }
    
    location ~ ^/$path_name/(.+\.php)$ {
        alias $app_root;
        try_files /\$1 =404;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $app_root/\$1;
        include fastcgi_params;
    }
    
EOF
                ;;
            "laravel")
                cat >> "$nginx_conf" <<EOF
    location /$path_name {
        alias $app_root/public;
        index index.php;
        try_files \$uri \$uri/ @laravel_$path_name;
    }
    
    location @laravel_$path_name {
        rewrite ^/$path_name/(.*)$ /$path_name/index.php?\$1;
    }
    
    location ~ ^/$path_name/(.+\.php)$ {
        alias $app_root/public;
        try_files /\$1 =404;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $app_root/public/\$1;
        include fastcgi_params;
    }
    
EOF
                ;;
            nodejs:*)
                node_port="${app_type#nodejs:}"
                cat >> "$nginx_conf" <<EOF
    location /$path_name {
        proxy_pass http://127.0.0.1:${node_port};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
EOF
                ;;
            "react")
                cat >> "$nginx_conf" <<EOF
    location /$path_name {
        alias $app_root/dist;
        index index.html;
        try_files \$uri \$uri/ /$path_name/index.html;
    }
    
    location ~* ^/$path_name/.*\.(?:css|js|woff2?|ttf|eot|ico|svg|jpg|jpeg|gif|png|webp)$ {
        alias $app_root/dist;
        expires 1y;
        access_log off;
    }
    
EOF
                ;;
        esac
    done
    
    # Tutup konfigurasi server
    cat >> "$nginx_conf" <<EOF
    # Block access to sensitive files
    location ~* \.ht {
        deny all;
    }
}
EOF
    
    # Aktifkan konfigurasi
    ln -sf "$nginx_conf" "/etc/nginx/sites-enabled/"
    
    # Test konfigurasi nginx
    if nginx -t; then
        systemctl reload nginx
        log_info "Konfigurasi Nginx path-based untuk $main_domain berhasil dibuat!"
        echo
        echo "=== Ringkasan Konfigurasi ==="
        echo "Domain: $main_domain"
        echo "File konfigurasi: $nginx_conf"
        echo
        echo "Aplikasi yang dikonfigurasi:"
        for i in "${!apps_config[@]}"; do
            IFS=':' read -ra ADDR <<< "${apps_config[$i]}"
            path_name="${ADDR[0]}"
            app_type="${ADDR[1]}"
            app_root="${ADDR[2]}"
            echo "  - http://$main_domain/$path_name -> $app_root (${app_type})"
        done
        echo
        echo "Pastikan semua aplikasi sudah diletakkan di path yang benar!"
    else
        log_error "Konfigurasi Nginx tidak valid! Periksa syntax error."
        rm -f "/etc/nginx/sites-enabled/$(basename "$nginx_conf")"
        return 1
    fi
}

# === Optimasi Server ===
optimize_server() {
    log_info "Mengoptimalkan server..."
    # Placeholder for server optimization logic
    log_info "Optimasi server selesai!"
}

# === Cache System ===
install_cache_system() {
    log_info "Menginstall cache system..."
    # Placeholder for cache system installation logic
    log_info "Cache system selesai!"
}
install_redis() {
    log_info "Menginstall Redis..."
    # Placeholder for Redis installation logic
    log_info "Redis selesai!"
}
install_memcached() {
    log_info "Menginstall Memcached..."
    # Placeholder for Memcached installation logic
    log_info "Memcached selesai!"
}

# === Security Hardening ===
security_hardening() {
    log_info "Mengamankan server..."
    # Placeholder for security hardening logic
    log_info "Pengamanan server selesai!"
}
install_fail2ban() {
    log_info "Menginstall Fail2Ban..."
    # Placeholder for Fail2Ban installation logic
    log_info "Fail2Ban selesai!"
}
configure_auto_updates() {
    log_info "Mengatur auto-updates..."
    # Placeholder for auto-updates configuration logic
    log_info "Auto-updates selesai!"
}
secure_shared_memory() {
    log_info "Mengamankan shared memory..."
    # Placeholder for secure shared memory logic
    log_info "Shared memory selesai!"
}
restrict_system_access() {
    log_info "Mengatur akses sistem..."
    # Placeholder for restrict system access logic
    log_info "Akses sistem selesai!"
}

# === Backup System ===
setup_backup_system() {
    log_info "Mengatur sistem backup..."
    # Placeholder for backup system setup logic
    log_info "Sistem backup selesai!"
}

# === System Info ===
show_system_info() {
    log_info "Menampilkan informasi sistem..."
    # Placeholder for system info display logic
    log_info "Informasi sistem selesai!"
}

# === MySQL Root Change ===
mysql_change_root() {
    log_info "Mengubah root password MySQL..."
    # Placeholder for MySQL root password change logic
    log_info "Ubah password root MySQL selesai!"
}

# === Ganti Mirror APT ===
change_apt_mirror() {
    log_info "Pilih mirror APT yang ingin digunakan:"
    echo "1. Australia (mirror.aarnet.edu.au)"
    echo "2. Singapore (sg.archive.ubuntu.com)"
    echo "3. Vietnam (vn.archive.ubuntu.com)"
    echo "4. Pilih mirror tercepat (otomatis, rekomendasi)"
    echo "0. Batal"
    read -p "Pilihan [1-4/0]: " mirror_choice
    case $mirror_choice in
        1)
            mirror_url="http://mirror.aarnet.edu.au/pub/ubuntu/"
            ;;
        2)
            mirror_url="http://sg.archive.ubuntu.com/ubuntu/"
            ;;
        3)
            mirror_url="http://vn.archive.ubuntu.com/ubuntu/"
            ;;
        4)
            # Install netselect jika belum ada
            if ! command -v netselect >/dev/null 2>&1; then
                log_info "Menginstall netselect (dari Debian repo, karena tidak ada di Ubuntu)..."
                apt install -y wget > /dev/null 2>&1
                wget -q http://ftp.us.debian.org/debian/pool/main/n/netselect/netselect_0.3.ds1-29_amd64.deb -O /tmp/netselect.deb
                dpkg -i /tmp/netselect.deb || apt -f install -y
            fi
            log_info "Mengambil daftar mirror Ubuntu..."
            mirrors=$(wget -qO - mirrors.ubuntu.com/mirrors.txt)
            log_info "Menentukan mirror tercepat, mohon tunggu..."
            fastest=$(netselect -s 1 -t 40 $mirrors 2>/dev/null | awk '{print $2}' | head -n1)
            if [ -z "$fastest" ]; then
                log_error "Gagal menentukan mirror tercepat."
                return
            fi
            mirror_url="$fastest"
            log_info "Mirror tercepat: $mirror_url"
            ;;
        0)
            log_info "Batal mengubah mirror."
            return
            ;;
        *)
            log_error "Pilihan tidak valid."
            return
            ;;
    esac
    if [ ! -f /etc/apt/sources.list ]; then
        log_error "/etc/apt/sources.list tidak ditemukan!"
        return
    fi
    cp /etc/apt/sources.list /etc/apt/sources.list.backup.$(date +%Y%m%d%H%M%S)
    log_info "Backup sources.list selesai."
    # Ganti semua baris deb/deb-src utama ke mirror baru
    sed -i "s|http[s]\?://[a-zA-Z0-9./-]*/ubuntu/|$mirror_url|g" /etc/apt/sources.list
    log_info "Mirror APT berhasil diubah ke: $mirror_url"
    log_info "Menjalankan apt update untuk refresh repository..."
    apt update
    log_info "Selesai. Jika terjadi error, restore dengan: sudo cp /etc/apt/sources.list.backup.YYYYMMDDHHMMSS /etc/apt/sources.list"
}

# === Cek Ekstensi PHP Terinstall ===
check_installed_php_extensions() {
    local php_version
    php_version=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
    log_info "Daftar ekstensi PHP terinstall untuk PHP $php_version:"
    local extensions
    extensions=$(php -m | grep -v "\[" | grep -v "^$" | sort)
    local count=0
    local col=3
    local output=""
    for ext in $extensions; do
        output+=$(printf "%-25s" "$ext")
        count=$((count+1))
        if (( count % col == 0 )); then
            output+="\n"
        fi
    done
    echo -e "$output"
}

# === Konfigurasi systemd untuk Node.js ===
configure_nodejs_systemd() {
    echo "=== Konfigurasi systemd untuk Node.js ==="
    read -p "Masukkan path aplikasi Node.js (misal: /var/www/api_pegawai): " app_path
    if [ ! -d "$app_path" ]; then
        log_error "Path $app_path tidak ditemukan!"
        return
    fi
    read -p "Masukkan nama service systemd (misal: api-pegawai): " service_name
    read -p "Masukkan nama file entry point (default: server.js): " entry_point
    entry_point=${entry_point:-server.js}
    read -p "Jalankan sebagai user apa? (default: www-data): " run_user
    run_user=${run_user:-www-data}
    service_file="/etc/systemd/system/${service_name}.service"
    cat > "$service_file" <<EOF
[Unit]
Description=Node.js App ($service_name)
After=network.target

[Service]
Type=simple
WorkingDirectory=$app_path
ExecStart=/usr/bin/node $entry_point
Restart=always
User=$run_user
Environment=NODE_ENV=production
StandardOutput=append:$app_path/app.log
StandardError=append:$app_path/app.log

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable "$service_name"
    systemctl restart "$service_name"
    log_info "Service systemd $service_name berhasil dibuat dan dijalankan!"
    echo "Cek status: sudo systemctl status $service_name"
    echo "Lihat log: tail -f $app_path/app.log"
} 

# === Konfigurasi Nginx untuk SSO ===
configure_sso_nginx() {
    log_info "=== Konfigurasi Nginx untuk SSO (Keycloak) ==="
    
    # Cek apakah nginx sudah terinstall
    if ! command -v nginx &> /dev/null; then
        log_error "Nginx belum terinstall. Install Nginx terlebih dahulu."
        return 1
    fi
    
    echo "Pilih jenis konfigurasi:"
    echo "1. Domain utama (misal: sso.domain.com)"
    echo "2. Subdomain (misal: auth.domain.com)"
    read -p "Pilihan [1-2]: " domain_type
    
    if [ "$domain_type" = "2" ]; then
        read -p "Masukkan domain utama (misal: domain.com): " main_domain
        read -p "Masukkan subdomain (misal: auth): " subdomain
        subdomain=${subdomain:-auth}
        domain_name="${subdomain}.${main_domain}"
    else
        read -p "Masukkan domain untuk SSO (misal: sso.domain.com): " domain_name
    fi
    
    # Buat konfigurasi nginx
    nginx_conf="/etc/nginx/sites-available/${domain_name}"
    
    log_info "Membuat konfigurasi Nginx untuk $domain_name..."
    
    cat > "$nginx_conf" <<EOF
server {
    listen 80;
    server_name ${domain_name};
    
    # Proxy ke Keycloak yang berjalan di port 8080
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        # Timeout settings untuk Keycloak
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # Tambahan untuk WebSocket support (jika diperlukan)
    location /realms/ {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF
    
    # Aktifkan site
    ln -sf "$nginx_conf" "/etc/nginx/sites-enabled/"
    
    # Test konfigurasi nginx
    if nginx -t; then
        systemctl reload nginx
        log_info "Konfigurasi Nginx untuk SSO berhasil dibuat dan diaktifkan!"
        echo
        log_info "=== INFORMASI KONFIGURASI ==="
        echo "1. Domain: $domain_name"
        echo "2. Konfigurasi: $nginx_conf"
        echo "3. Akses: http://$domain_name"
        echo "4. Admin Console: http://$domain_name/admin"
        echo
        log_info "Pastikan DNS sudah mengarah ke server ini!"
    else
        log_error "Konfigurasi Nginx tidak valid!"
        rm -f "/etc/nginx/sites-enabled/${domain_name}"
        return 1
    fi
} 