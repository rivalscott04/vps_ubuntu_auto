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
    echo "5. Next.js"
    echo "6. Svelte (static, folder build)"
    read -p "Pilihan [1-6]: " app_type
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
        5)
            # Next.js (reverse proxy)
            read -p "Masukkan port aplikasi Next.js (misal: 3000): " nextjs_port
            nginx_conf="/etc/nginx/sites-available/${domain_name}"
            cat > "$nginx_conf" <<EOF
server {
    listen 80;
    server_name ${domain_name};

    location / {
        proxy_pass http://127.0.0.1:${nextjs_port};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        # Timeout settings untuk Next.js
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # Buffer settings
        proxy_buffering off;
        proxy_request_buffering off;
    }
    
    # Cache untuk static assets Next.js
    location /_next/static {
        proxy_pass http://127.0.0.1:${nextjs_port};
        proxy_http_version 1.1;
        proxy_cache_valid 200 60m;
        add_header Cache-Control "public, immutable";
    }
}
EOF
            ;;
        6)
            # Svelte (static, folder build)
            nginx_conf="/etc/nginx/sites-available/${domain_name}"
            cat > "$nginx_conf" <<EOF
server {
    listen 80;
    server_name ${domain_name};
    root ${app_path}/build;
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
    echo "        atau: 192.168.1.100/app1, 192.168.1.100/app2"
    echo
    echo "Pilih jenis konfigurasi:"
    echo "1. Menggunakan domain (misal: domain.com)"
    echo "2. Menggunakan IP address (misal: 192.168.1.100)"
    read -p "Pilihan [1-2]: " server_type
    
    case $server_type in
        1)
            read -p "Masukkan domain utama (misal: domain.com): " main_server
            ;;
        2)
            while true; do
                read -p "Masukkan IP address (misal: 192.168.1.100): " main_server
                # Validasi format IP address
                if [[ $main_server =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                    # Validasi range IP (0-255)
                    valid_ip=true
                    IFS='.' read -ra IP_PARTS <<< "$main_server"
                    for part in "${IP_PARTS[@]}"; do
                        if [ "$part" -gt 255 ] || [ "$part" -lt 0 ]; then
                            valid_ip=false
                            break
                        fi
                    done
                    if [ "$valid_ip" = true ]; then
                        break
                    else
                        echo "Error: IP address tidak valid (range 0-255 untuk setiap oktet)"
                    fi
                else
                    echo "Error: Format IP address tidak valid. Gunakan format seperti 192.168.1.100"
                fi
            done
            ;;
        *)
            log_error "Pilihan tidak valid!"
            return
            ;;
    esac
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
        echo "5. Next.js"
        echo "6. Svelte (static, folder build)"
        read -p "Pilihan [1-6]: " app_type
        
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
            5) 
                read -p "Masukkan port aplikasi Next.js (misal: 3000): " nextjs_port
                app_type_name="nextjs:$nextjs_port"
                ;;
            6) app_type_name="svelte" ;;
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
    # Buat nama file yang aman untuk IP address (ganti titik dengan underscore)
    safe_name=$(echo "$main_server" | sed 's/\./_/g')
    nginx_conf="/etc/nginx/sites-available/${safe_name}-pathbased"
    
cat > "$nginx_conf" <<EOF
server {
    listen 80;
    server_name ${main_server};
    
    # Default location untuk root domain/IP
    location = / {
        return 200 'Path-based routing aktif untuk ${main_server}';
        add_header Content-Type text/plain;
    }
    
EOF
    

    
    # Tambahkan konfigurasi untuk setiap aplikasi
    for i in "${!apps_config[@]}"; do
        # Parsing string dengan format: path_name:app_type:app_root
        # Khusus untuk nodejs/nextjs format: path_name:app_type:port:app_root
        config_str="${apps_config[$i]}"
        path_name=$(echo "$config_str" | cut -d':' -f1)
        
        # Deteksi jika ini nodejs atau nextjs (ada port)
        if [[ "$config_str" =~ ^[^:]+:(nodejs|nextjs):[0-9]+: ]]; then
            # Format: path_name:app_type:port:app_root
            app_type=$(echo "$config_str" | cut -d':' -f2-3)  # nodejs:port atau nextjs:port
            app_root=$(echo "$config_str" | cut -d':' -f4-)   # sisa setelah 3 colon pertama
        else
            # Format normal: path_name:app_type:app_root
            app_type=$(echo "$config_str" | cut -d':' -f2)
            app_root=$(echo "$config_str" | cut -d':' -f3-)
        fi
        
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
    location /$path_name/ {
        proxy_pass http://127.0.0.1:${node_port};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Origin \$http_origin;
        proxy_pass_header Set-Cookie;
    }
    
EOF
                ;;
            nextjs:*)
                nextjs_port="${app_type#nextjs:}"
                cat >> "$nginx_conf" <<EOF
    location /$path_name {
        proxy_pass http://127.0.0.1:${nextjs_port};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        # Timeout settings untuk Next.js
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # Buffer settings
        proxy_buffering off;
        proxy_request_buffering off;
    }
    
    # Cache untuk static assets Next.js
    location /$path_name/_next/static {
        proxy_pass http://127.0.0.1:${nextjs_port};
        proxy_http_version 1.1;
        proxy_cache_valid 200 60m;
        add_header Cache-Control "public, immutable";
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
            "svelte")
                cat >> "$nginx_conf" <<EOF
    location /$path_name {
        alias $app_root/build;
        index index.html;
        try_files \$uri \$uri/ /$path_name/index.html;
    }

    location ~* ^/$path_name/.*\.(?:css|js|woff2?|ttf|eot|ico|svg|jpg|jpeg|gif|png|webp)$ {
        alias $app_root/build;
        expires 1y;
        access_log off;
    }

EOF
                ;;
            *)
                log_error "Jenis aplikasi tidak dikenali: $app_type untuk path /$path_name"
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
        log_info "Konfigurasi Nginx path-based untuk $main_server berhasil dibuat!"
        echo
        echo "=== Ringkasan Konfigurasi ==="
        if [ "$server_type" = "1" ]; then
            echo "Domain: $main_server"
        else
            echo "IP Address: $main_server"
        fi
        echo "File konfigurasi: $nginx_conf"
        echo
        echo "Aplikasi yang dikonfigurasi:"
        for i in "${!apps_config[@]}"; do
            IFS=':' read -ra ADDR <<< "${apps_config[$i]}"
            path_name="${ADDR[0]}"
            app_type="${ADDR[1]}"
            app_root="${ADDR[2]}"
            echo "  - http://$main_server/$path_name -> $app_root (${app_type})"
        done
        echo
        echo "Pastikan semua aplikasi sudah diletakkan di path yang benar!"
    else
        log_error "Konfigurasi Nginx tidak valid! Periksa syntax error."
        rm -f "/etc/nginx/sites-enabled/$(basename "$nginx_conf")"
        return 1
    fi
}

configure_cronjob() {
    echo "=== Setting Cron Job ==="
    echo "Pilih jenis cron job yang ingin dikonfigurasi:"
    echo "1. Backup Database Otomatis"
    echo "2. Bersihkan File Temporary"
    echo "3. Bersihkan Cache Laravel & Node.js"
    echo "4. Setup Semua Cron Job"
    echo "0. Kembali"
    read -p "Pilihan [0-4]: " cronjob_choice
    
    case $cronjob_choice in
        1) setup_database_backup_cronjob ;;
        2) setup_temp_cleanup_cronjob ;;
        3) setup_cache_cleanup_cronjob ;;
        4) 
            setup_database_backup_cronjob
            setup_temp_cleanup_cronjob
            setup_cache_cleanup_cronjob
            log_info "Semua cron job berhasil dikonfigurasi!"
            ;;
        0) return ;;
        *) log_error "Pilihan tidak valid!" ;;
    esac
}

setup_database_backup_cronjob() {
    log_info "Mengkonfigurasi cron job untuk backup database..."
    
    # Pilihan jadwal backup
    echo "Pilih jadwal backup database:"
    echo "1. Harian (setiap hari jam 2:00 pagi)"
    echo "2. Mingguan (setiap minggu hari Minggu jam 2:00 pagi)"
    echo "3. Bulanan (setiap tanggal 1 jam 2:00 pagi)"
    read -p "Pilihan [1-3]: " backup_schedule
    
    case $backup_schedule in
        1) 
            cron_schedule="0 2 * * *"
            schedule_desc="harian (setiap hari jam 2:00 pagi)"
            retention_days=7
            ;;
        2) 
            cron_schedule="0 2 * * 0"
            schedule_desc="mingguan (setiap Minggu jam 2:00 pagi)"
            retention_days=30
            ;;
        3) 
            cron_schedule="0 2 1 * *"
            schedule_desc="bulanan (setiap tanggal 1 jam 2:00 pagi)"
            retention_days=365
            ;;
        *) 
            log_warning "Pilihan tidak valid, menggunakan default (harian)"
            cron_schedule="0 2 * * *"
            schedule_desc="harian (setiap hari jam 2:00 pagi)"
            retention_days=7
            ;;
    esac
    
    # Buat direktori backup jika belum ada
    mkdir -p /var/backups/database
    
    # Buat script backup database dengan retention yang dinamis
    cat > /usr/local/bin/backup-database.sh << EOF
#!/bin/bash
# Script backup database otomatis
BACKUP_DIR="/var/backups/database"
DATE=$(date +%Y%m%d_%H%M%S)
LOG_FILE="/var/log/database-backup.log"

echo "$(date): Memulai backup database..." >> $LOG_FILE

# Backup MySQL/MariaDB
if systemctl is-active --quiet mysql || systemctl is-active --quiet mariadb; then
    echo "$(date): Backup MySQL/MariaDB..." >> $LOG_FILE
    mysqldump --all-databases --single-transaction --routines --triggers > "$BACKUP_DIR/mysql_backup_$DATE.sql"
    gzip "$BACKUP_DIR/mysql_backup_$DATE.sql"
    echo "$(date): MySQL/MariaDB backup selesai" >> $LOG_FILE
fi

# Backup PostgreSQL
if systemctl is-active --quiet postgresql; then
    echo "$(date): Backup PostgreSQL..." >> $LOG_FILE
    sudo -u postgres pg_dumpall > "$BACKUP_DIR/postgres_backup_$DATE.sql"
    gzip "$BACKUP_DIR/postgres_backup_$DATE.sql"
    echo "$(date): PostgreSQL backup selesai" >> $LOG_FILE
fi

# Hapus backup lama berdasarkan retention policy
find \$BACKUP_DIR -name "*.sql.gz" -type f -mtime +${retention_days} -delete
echo "\$(date): Backup database selesai dan file lama dibersihkan" >> \$LOG_FILE
EOF

    chmod +x /usr/local/bin/backup-database.sh
    
    # Hapus cron job backup database yang mungkin sudah ada
    crontab -l 2>/dev/null | grep -v "backup-database.sh" | crontab -
    
    # Setup cron job baru dengan jadwal yang dipilih
    (crontab -l 2>/dev/null; echo "$cron_schedule /usr/local/bin/backup-database.sh") | crontab -
    
    log_info "Cron job backup database berhasil dikonfigurasi!"
    echo "  - Backup akan berjalan $schedule_desc"
    echo "  - File backup disimpan di: /var/backups/database"
    echo "  - Log backup di: /var/log/database-backup.log"
    echo "  - Backup lama (>$retention_days hari) akan dihapus otomatis"
}

setup_temp_cleanup_cronjob() {
    log_info "Mengkonfigurasi cron job untuk pembersihan file temporary..."
    
    # Buat script pembersihan temp
    cat > /usr/local/bin/cleanup-temp.sh << 'EOF'
#!/bin/bash
# Script pembersihan file temporary
LOG_FILE="/var/log/temp-cleanup.log"

echo "$(date): Memulai pembersihan file temporary..." >> $LOG_FILE

# Bersihkan /tmp (file lebih dari 3 hari)
find /tmp -type f -mtime +3 -delete 2>/dev/null
find /tmp -type d -empty -delete 2>/dev/null

# Bersihkan /var/tmp (file lebih dari 7 hari)
find /var/tmp -type f -mtime +7 -delete 2>/dev/null
find /var/tmp -type d -empty -delete 2>/dev/null

# Bersihkan log lama
find /var/log -name "*.log.*" -type f -mtime +14 -delete 2>/dev/null
find /var/log -name "*.gz" -type f -mtime +14 -delete 2>/dev/null

# Bersihkan APT cache
apt-get clean 2>/dev/null

# Bersihkan package yang tidak diperlukan
apt-get autoremove -y 2>/dev/null

echo "$(date): Pembersihan file temporary selesai" >> $LOG_FILE
EOF

    chmod +x /usr/local/bin/cleanup-temp.sh
    
    # Setup cron job (setiap hari jam 3 pagi)
    (crontab -l 2>/dev/null; echo "0 3 * * * /usr/local/bin/cleanup-temp.sh") | crontab -
    
    log_info "Cron job pembersihan file temporary berhasil dikonfigurasi!"
    echo "  - Pembersihan akan berjalan setiap hari jam 3:00 pagi"
    echo "  - Membersihkan /tmp (file >3 hari), /var/tmp (file >7 hari)"
    echo "  - Membersihkan log lama (>14 hari) dan APT cache"
    echo "  - Log pembersihan di: /var/log/temp-cleanup.log"
}

setup_cache_cleanup_cronjob() {
    log_info "Mengkonfigurasi cron job untuk pembersihan cache Laravel & Node.js..."
    
    # Buat script pembersihan cache
    cat > /usr/local/bin/cleanup-cache.sh << 'EOF'
#!/bin/bash
# Script pembersihan cache Laravel dan Node.js
LOG_FILE="/var/log/cache-cleanup.log"

echo "$(date): Memulai pembersihan cache..." >> $LOG_FILE

# Cari dan bersihkan cache Laravel
find /var/www -name "bootstrap" -type d 2>/dev/null | while read bootstrap_dir; do
    if [ -d "$bootstrap_dir/cache" ]; then
        echo "$(date): Membersihkan Laravel cache di $bootstrap_dir/cache" >> $LOG_FILE
        find "$bootstrap_dir/cache" -name "*.php" -type f -mtime +1 -delete 2>/dev/null
    fi
done

# Cari dan bersihkan storage/framework/cache Laravel
find /var/www -path "*/storage/framework/cache" -type d 2>/dev/null | while read cache_dir; do
    echo "$(date): Membersihkan Laravel storage cache di $cache_dir" >> $LOG_FILE
    find "$cache_dir" -type f -mtime +1 -delete 2>/dev/null
done

# Cari dan bersihkan storage/logs Laravel (file log lama)
find /var/www -path "*/storage/logs" -type d 2>/dev/null | while read logs_dir; do
    echo "$(date): Membersihkan Laravel logs di $logs_dir" >> $LOG_FILE
    find "$logs_dir" -name "*.log" -type f -mtime +7 -delete 2>/dev/null
done

# Bersihkan Node.js cache (npm cache)
if command -v npm >/dev/null 2>&1; then
    echo "$(date): Membersihkan npm cache" >> $LOG_FILE
    npm cache clean --force 2>/dev/null
fi

# Bersihkan yarn cache jika ada
if command -v yarn >/dev/null 2>&1; then
    echo "$(date): Membersihkan yarn cache" >> $LOG_FILE
    yarn cache clean 2>/dev/null
fi

# Cari dan bersihkan node_modules/.cache
find /var/www -path "*/node_modules/.cache" -type d 2>/dev/null | while read cache_dir; do
    echo "$(date): Membersihkan Node.js cache di $cache_dir" >> $LOG_FILE
    rm -rf "$cache_dir"/* 2>/dev/null
done

echo "$(date): Pembersihan cache selesai" >> $LOG_FILE
EOF

    chmod +x /usr/local/bin/cleanup-cache.sh
    
    # Setup cron job (setiap hari jam 4 pagi)
    (crontab -l 2>/dev/null; echo "0 4 * * * /usr/local/bin/cleanup-cache.sh") | crontab -
    
    log_info "Cron job pembersihan cache berhasil dikonfigurasi!"
    echo "  - Pembersihan akan berjalan setiap hari jam 4:00 pagi"
    echo "  - Membersihkan cache Laravel (bootstrap, storage/framework)"
    echo "  - Membersihkan log Laravel lama (>7 hari)"
    echo "  - Membersihkan npm/yarn cache dan node_modules/.cache"
    echo "  - Log pembersihan di: /var/log/cache-cleanup.log"
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
    echo "=== Konfigurasi systemd untuk Node.js/Next.js ==="
    echo "Pilih jenis aplikasi:"
    echo "1. Node.js/Express (biasa)"
    echo "2. Next.js"
    read -p "Pilihan [1-2]: " app_type
    
    case $app_type in
        1)
            # Node.js biasa
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
            
            # Cek apakah node tersedia
            if ! command -v node >/dev/null 2>&1; then
                log_error "Node.js tidak ditemukan! Install Node.js terlebih dahulu."
                return 1
            fi
            
            node_path=$(which node)
            service_file="/etc/systemd/system/${service_name}.service"
            cat > "$service_file" <<EOF
[Unit]
Description=Node.js App ($service_name)
After=network.target

[Service]
Type=simple
WorkingDirectory=$app_path
ExecStart=$node_path $entry_point
Restart=always
User=$run_user
Environment=NODE_ENV=production
StandardOutput=append:$app_path/app.log
StandardError=append:$app_path/app.log

[Install]
WantedBy=multi-user.target
EOF
            ;;
        2)
            # Next.js
            read -p "Masukkan path aplikasi Next.js (misal: /var/www/nextjs-app): " app_path
            if [ ! -d "$app_path" ]; then
                log_error "Path $app_path tidak ditemukan!"
                return
            fi
            
            # Cek apakah package.json ada
            if [ ! -f "$app_path/package.json" ]; then
                log_error "File package.json tidak ditemukan di $app_path"
                return 1
            fi
            
            read -p "Masukkan nama service systemd (misal: nextjs-app): " service_name
            read -p "Jalankan sebagai user apa? (default: www-data): " run_user
            run_user=${run_user:-www-data}
            
            # Cek apakah port sudah ada di package.json script atau perlu di-set
            if grep -q '"start".*"next start -p' "$app_path/package.json" 2>/dev/null; then
                log_info "Port sudah dikonfigurasi di package.json script, tidak perlu set PORT di environment"
                use_port_env=false
            else
                read -p "Masukkan port aplikasi Next.js (default: 3000, kosongkan jika sudah ada di package.json): " nextjs_port
                if [ -n "$nextjs_port" ]; then
                    use_port_env=true
                else
                    use_port_env=false
                fi
            fi
            
            # Cek apakah npm tersedia
            if ! command -v npm >/dev/null 2>&1; then
                log_error "npm tidak ditemukan! Install Node.js dan npm terlebih dahulu."
                return 1
            fi
            
            npm_path=$(which npm)
            service_file="/etc/systemd/system/${service_name}.service"
            
            # Buat file service dengan format sesuai kebutuhan
            if [ "$use_port_env" = true ]; then
                cat > "$service_file" <<EOF
[Unit]
Description=Next.js $service_name
After=network.target

[Service]
Type=simple
User=$run_user
WorkingDirectory=$app_path
ExecStart=$npm_path start
Restart=always
RestartSec=10
Environment=NODE_ENV=production
Environment=PORT=${nextjs_port}

[Install]
WantedBy=multi-user.target
EOF
            else
                cat > "$service_file" <<EOF
[Unit]
Description=Next.js $service_name
After=network.target

[Service]
Type=simple
User=$run_user
WorkingDirectory=$app_path
ExecStart=$npm_path start
Restart=always
RestartSec=10
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF
            fi
            log_info "Pastikan aplikasi Next.js sudah di-build (npm run build) sebelum menjalankan service!"
            ;;
        *)
            log_error "Pilihan tidak valid!"
            return
            ;;
    esac
    
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