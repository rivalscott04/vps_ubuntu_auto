# === Installers ===

add_php_repository() {
    log_info "Menyesuaikan PPA untuk PHP..."
    add_ppa_if_needed "ondrej/php"
}

install_php() {
    add_php_repository
    echo "Pilih versi PHP yang ingin diinstall:"
    echo "1. PHP 8.4 (jika tersedia)"
    echo "2. PHP 8.3"
    echo "3. PHP 8.2"
    echo "4. PHP 8.1"
    echo "5. PHP 8.0"
    echo "6. PHP 7.4"
    read -p "Pilihan [1-6]: " php_choice
    case $php_choice in
        1) selected_php_version="8.4" ;;
        2) selected_php_version="8.3" ;;
        3) selected_php_version="8.2" ;;
        4) selected_php_version="8.1" ;;
        5) selected_php_version="8.0" ;;
        6) selected_php_version="7.4" ;;
        *) log_warning "Pilihan tidak valid, menggunakan default 8.2"; selected_php_version="8.2" ;;
    esac
    echo "[1/2] Update repository..."
    safe_apt_update
    echo "[2/2] Install paket PHP dan ekstensi..."
    safe_apt_install php${selected_php_version} php${selected_php_version}-fpm php${selected_php_version}-cli \
                   php${selected_php_version}-common php${selected_php_version}-mysql php${selected_php_version}-zip \
                   php${selected_php_version}-gd php${selected_php_version}-mbstring php${selected_php_version}-curl \
                   php${selected_php_version}-xml php${selected_php_version}-bcmath php${selected_php_version}-pgsql \
                   php${selected_php_version}-intl php${selected_php_version}-readline php${selected_php_version}-ldap \
                   php${selected_php_version}-msgpack php${selected_php_version}-igbinary php${selected_php_version}-redis
    if [ $? -eq 0 ]; then
        log_info "PHP ${selected_php_version} berhasil diinstall!"
        configure_php ${selected_php_version}
        export selected_php_version
    else
        log_error "Gagal menginstal PHP ${selected_php_version}"
    fi
}

install_webserver() {
    log_info "Menginstal Nginx..."
    add_ppa_if_needed "ondrej/nginx-mainline"
    echo "[1/1] Install Nginx..."
    safe_apt_install -y nginx
    systemctl restart nginx
    log_info "Nginx berhasil diinstall!"
}

install_database() {
    echo "Pilih database yang akan diinstall:"
    echo "1. MySQL"
    echo "2. PostgreSQL"
    echo "3. MariaDB"
    read -p "Pilihan [1-3]: " db_choice
    case $db_choice in
        1|3)
            if [ "$db_choice" = "1" ]; then
                log_info "Menginstal MySQL..."
                echo "[1/1] Install MySQL..."
                safe_apt_install -y mysql-server
            else
                log_info "Menginstal MariaDB..."
                echo "[1/1] Install MariaDB..."
                safe_apt_install -y mariadb-server
            fi
            mysql_secure_installation
            echo "Pilih opsi manajemen user:"
            echo "1. Buat user baru (root tetap ada)"
            echo "2. Hapus root dan buat user baru"
            read -p "Pilihan [1-2]: " user_choice
            case $user_choice in
                1) configure_mysql_user ;;
                2) mysql_change_root ;;
                *) log_error "Pilihan tidak valid" ;;
            esac
            if [ "$db_choice" = "1" ]; then
                log_info "MySQL berhasil diinstall!"
            else
                log_info "MariaDB berhasil diinstall!"
            fi
            ;;
        2)
            log_info "Menginstal PostgreSQL..."
            echo "[1/1] Install PostgreSQL..."
            safe_apt_install -y postgresql postgresql-contrib
            log_info "PostgreSQL berhasil diinstall!"
            ;;
        *) log_error "Pilihan tidak valid" ;;
    esac
}

install_phpmyadmin() {
    log_info "Mempersiapkan instalasi phpMyAdmin..."
    check_and_install_package curl
    check_and_install_package nginx

    # Deteksi versi PHP yang terinstall
    if [ -z "$selected_php_version" ]; then
        # Cek versi PHP yang terinstall
        for version in "8.3" "8.2" "8.1" "8.0" "7.4"; do
            if dpkg -l | grep -q "php$version"; then
                selected_php_version="$version"
                break
            fi
        done
    fi

    # Pastikan PHP terdeteksi
    if [ -z "$selected_php_version" ]; then
        log_error "PHP belum terinstal. Silakan install PHP terlebih dahulu."
        return 1
    fi

    log_info "Menggunakan PHP versi ${selected_php_version}"

    # Install required PHP extensions for the selected version
    check_and_install_package "php${selected_php_version}-fpm"
    check_and_install_package "php${selected_php_version}-mbstring"
    check_and_install_package "php${selected_php_version}-mysql"
    check_and_install_package "php${selected_php_version}-xml"
    check_and_install_package "php${selected_php_version}-zip"
    check_and_install_package "php${selected_php_version}-gd"

    # Pilihan instalasi: subdomain atau subfolder
    echo "Pilih metode instalasi phpMyAdmin:"
    echo "1. Gunakan subdomain (contoh: pma.domain.com)"
    echo "2. Gunakan subfolder (contoh: domain.com/pma)"
    read -p "Pilihan [1-2]: " pma_install_method

    case $pma_install_method in
        1) use_subdomain=true ;;
        2) use_subdomain=false ;;
        *) log_warning "Pilihan tidak valid, menggunakan default (subfolder)"; use_subdomain=false ;;
    esac

    if [ "$use_subdomain" = true ]; then
        # Konfigurasi untuk subdomain
        read -p "Masukkan domain utama (contoh: domain.com): " main_domain
        read -p "Masukkan subdomain untuk phpMyAdmin (contoh: pma): " pma_subdomain

        # Default ke 'pma' jika input kosong
        pma_subdomain=${pma_subdomain:-pma}

        # Buat domain lengkap
        domain_name="${pma_subdomain}.${main_domain}"

        # Set path instalasi
        pma_path="/var/www/${domain_name}"
    else
        # Konfigurasi untuk subfolder
        read -p "Masukkan domain utama (contoh: domain.com): " domain_name
        read -p "Masukkan nama folder untuk phpMyAdmin [pma]: " pma_folder

        # Default ke 'pma' jika input kosong
        pma_folder=${pma_folder:-pma}

        # Set path instalasi
        pma_path="/var/www/${domain_name}/${pma_folder}"
    fi

    # Membuat direktori jika belum ada
    mkdir -p "$pma_path"

    # Download dan extract phpMyAdmin
    log_info "Mengunduh phpMyAdmin..."
    curl -L https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.tar.gz -o /tmp/phpmyadmin.tar.gz

    log_info "Mengekstrak file..."
    tar xzf /tmp/phpmyadmin.tar.gz -C /tmp/
    mv /tmp/phpMyAdmin-*-all-languages/* "$pma_path/"

    # Generate blowfish secret
    blowfish_secret=$(openssl rand -base64 32)

    # Konfigurasi phpMyAdmin
    cp "${pma_path}/config.sample.inc.php" "${pma_path}/config.inc.php"
    sed -i "s/\$cfg\['blowfish_secret'\] = ''/\$cfg\['blowfish_secret'\] = '$blowfish_secret'/" "${pma_path}/config.inc.php"

    # Tanya apakah menggunakan SSL/HTTPS via Cloudflare
    read -p "Apakah menggunakan SSL/HTTPS via Cloudflare? (y/n): " use_ssl


    # Konfigurasi Nginx
    nginx_conf="/etc/nginx/sites-available/${domain_name}"

    if [ "$use_subdomain" = true ]; then
        # Konfigurasi untuk subdomain
        cat > "$nginx_conf" << EOF
server {
    listen 80;
    server_name ${domain_name};
    root ${pma_path};
    index index.php index.html index.htm;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

    # Cloudflare SSL configuration
    set_real_ip_from 173.245.48.0/20;
    set_real_ip_from 103.21.244.0/22;
    set_real_ip_from 103.22.200.0/22;
    set_real_ip_from 103.31.4.0/22;
    set_real_ip_from 141.101.64.0/18;
    set_real_ip_from 108.162.192.0/18;
    set_real_ip_from 190.93.240.0/20;
    set_real_ip_from 188.114.96.0/20;
    set_real_ip_from 197.234.240.0/22;
    set_real_ip_from 198.41.128.0/17;
    set_real_ip_from 162.158.0.0/15;
    set_real_ip_from 104.16.0.0/13;
    set_real_ip_from 104.24.0.0/14;
    set_real_ip_from 172.64.0.0/13;
    set_real_ip_from 131.0.72.0/22;
    set_real_ip_from 2400:cb00::/32;
    set_real_ip_from 2606:4700::/32;
    set_real_ip_from 2803:f800::/32;
    set_real_ip_from 2405:b500::/32;
    set_real_ip_from 2405:8100::/32;
    set_real_ip_from 2a06:98c0::/29;
    set_real_ip_from 2c0f:f248::/32;
    real_ip_header CF-Connecting-IP;

    location / {
        try_files \$uri \$uri/ =404;
    }

    # PHP handling
    location ~ \.php$ {
        try_files \$uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/var/run/php/php${selected_php_version}-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;

        # Extended timeout
        fastcgi_read_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_connect_timeout 300;

        # Buffer settings
        fastcgi_buffer_size 128k;
        fastcgi_buffers 4 256k;
        fastcgi_busy_buffers_size 256k;
    }

    # Deny access to specific phpMyAdmin files
    location ~ ^/(README|COPYING|LICENSE|RELEASE-DATE-|CHANGE|INSTALL|CONFIG|setup)$ {
        deny all;
    }

    location ~ /\.ht {
        deny all;
    }

    # Logging
    error_log /var/log/nginx/DOMAIN_NAME_error.log;
    access_log /var/log/nginx/DOMAIN_NAME_access.log combined;
}
EOF
    else
        # Konfigurasi untuk subfolder
        if [ ! -f "$nginx_conf" ]; then
            # Buat konfigurasi baru jika belum ada
            cat > "$nginx_conf" << EOF
server {
    listen 80;
    server_name ${domain_name};
    root /var/www/${domain_name};
    index index.php index.html index.htm;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

    # Cloudflare SSL configuration
    set_real_ip_from 173.245.48.0/20;
    set_real_ip_from 103.21.244.0/22;
    set_real_ip_from 103.22.200.0/22;
    set_real_ip_from 103.31.4.0/22;
    set_real_ip_from 141.101.64.0/18;
    set_real_ip_from 108.162.192.0/18;
    set_real_ip_from 190.93.240.0/20;
    set_real_ip_from 188.114.96.0/20;
    set_real_ip_from 197.234.240.0/22;
    set_real_ip_from 198.41.128.0/17;
    set_real_ip_from 162.158.0.0/15;
    set_real_ip_from 104.16.0.0/13;
    set_real_ip_from 104.24.0.0/14;
    set_real_ip_from 172.64.0.0/13;
    set_real_ip_from 131.0.72.0/22;
    set_real_ip_from 2400:cb00::/32;
    set_real_ip_from 2606:4700::/32;
    set_real_ip_from 2803:f800::/32;
    set_real_ip_from 2405:b500::/32;
    set_real_ip_from 2405:8100::/32;
    set_real_ip_from 2a06:98c0::/29;
    set_real_ip_from 2c0f:f248::/32;
    real_ip_header CF-Connecting-IP;

    # phpMyAdmin location
    location /${pma_folder} {
        try_files \$uri \$uri/ =404;

        location ~ \.php$ {
            try_files \$uri =404;
            fastcgi_split_path_info ^(.+\.php)(/.+)$;
            fastcgi_pass unix:/var/run/php/php${selected_php_version}-fpm.sock;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
            include fastcgi_params;

            # Extended timeout
            fastcgi_read_timeout 300;
            fastcgi_send_timeout 300;
            fastcgi_connect_timeout 300;

            # Buffer settings
            fastcgi_buffer_size 128k;
            fastcgi_buffers 4 256k;
            fastcgi_busy_buffers_size 256k;
        }

        # Deny access to specific phpMyAdmin files
        location ~ ^/(README|COPYING|LICENSE|RELEASE-DATE-|CHANGE|INSTALL|CONFIG|setup)$ {
            deny all;
        }
    }

    # Default PHP handling
    location ~ \.php$ {
        try_files \$uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/var/run/php/php${selected_php_version}-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }

    # Logging
    error_log /var/log/nginx/DOMAIN_NAME_error.log;
    access_log /var/log/nginx/DOMAIN_NAME_access.log combined;
}
EOF
        else
            # Backup konfigurasi yang ada
            cp "$nginx_conf" "${nginx_conf}.backup"

            # Cek apakah location phpMyAdmin sudah ada
            if ! grep -q "location /${pma_folder}" "$nginx_conf"; then
                # Tambahkan konfigurasi phpMyAdmin sebelum location terakhir
                sed -i "/location \/ {/i\\    # phpMyAdmin location\\n    location /${pma_folder} {\\n        try_files \$uri \$uri/ =404;\\n        \\n        location ~ \\.php$ {\\n            try_files \$uri =404;\\n            fastcgi_split_path_info ^(.+\\.php)(/.+)$;\\n            fastcgi_pass unix:/var/run/php/php${selected_php_version}-fpm.sock;\\n            fastcgi_index index.php;\\n            fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;\\n            include fastcgi_params;\\n            \\n            # Extended timeout\\n            fastcgi_read_timeout 300;\\n            fastcgi_send_timeout 300;\\n            fastcgi_connect_timeout 300;\\n            \\n            # Buffer settings\\n            fastcgi_buffer_size 128k;\\n            fastcgi_buffers 4 256k;\\n            fastcgi_busy_buffers_size 256k;\\n        }\\n        \\n        # Deny access to specific phpMyAdmin files\\n        location ~ ^/(README|COPYING|LICENSE|RELEASE-DATE-|CHANGE|INSTALL|CONFIG|setup)$ {\\n            deny all;\\n        }\\n    }\\n" "$nginx_conf"
            else
                log_warning "Konfigurasi phpMyAdmin sudah ada di nginx config"
            fi
        fi
    fi

    # Set permissions
    chown -R www-data:www-data "$pma_path"
    find "$pma_path" -type d -exec chmod 755 {} \;
    find "$pma_path" -type f -exec chmod 644 {} \;

    # Bersihkan file temporary
    rm -rf /tmp/phpmyadmin.tar.gz
    rm -rf /tmp/phpMyAdmin-*-all-languages

    # Test konfigurasi Nginx
    log_info "Menguji konfigurasi Nginx..."
    if nginx -t; then
        log_info "Konfigurasi Nginx valid!"

        # Tanya apakah ingin mengaktifkan konfigurasi
        read -p "Aktifkan konfigurasi Nginx untuk ${domain_name}? (y/n): " enable_config

        if [ "$enable_config" = "y" ]; then
            # Create symlink if not exists
            if [ ! -f "/etc/nginx/sites-enabled/${domain_name}" ]; then
                ln -sf "$nginx_conf" "/etc/nginx/sites-enabled/"
            fi
            log_info "Konfigurasi ${domain_name} diaktifkan"

            # Tanya apakah ingin restart Nginx
            read -p "Restart service Nginx sekarang? (y/n): " restart_nginx

            if [ "$restart_nginx" = "y" ]; then
                systemctl restart nginx
                log_info "Service Nginx berhasil di-restart"
            else
                log_info "Service Nginx tidak di-restart. Perubahan akan berlaku setelah Nginx di-restart."
                log_info "Untuk me-restart Nginx, jalankan: sudo systemctl restart nginx"
            fi

            # Tambahkan: Tawarkan instalasi SSL Certbot
            read -p "Ingin mengaktifkan SSL gratis (Let's Encrypt) untuk domain ${domain_name}? (y/n): " enable_ssl
            if [ "$enable_ssl" = "y" ]; then
                log_info "Menginstal certbot dan plugin nginx..."
                safe_apt_update && safe_apt_install -y certbot python3-certbot-nginx
                log_info "Menjalankan certbot untuk domain ${domain_name}..."
                certbot --nginx -d ${domain_name} --non-interactive --agree-tos -m admin@${domain_name} || log_warning "Certbot gagal, cek log untuk detail."
                systemctl reload nginx
                log_info "SSL Let's Encrypt telah diaktifkan untuk https://${domain_name}"
            fi
        else
            # Remove symlink if exists
            if [ -f "/etc/nginx/sites-enabled/${domain_name}" ]; then
                rm -f "/etc/nginx/sites-enabled/${domain_name}"
            fi
            log_info "Konfigurasi ${domain_name} tidak diaktifkan, tersimpan di ${nginx_conf}"
            log_info "Untuk mengaktifkan nanti, jalankan: sudo ln -sf ${nginx_conf} /etc/nginx/sites-enabled/"
        fi
    else
        log_error "Konfigurasi Nginx tidak valid!"
        read -p "Hapus konfigurasi yang tidak valid? (y/n): " remove_config

        if [ "$remove_config" = "y" ]; then
            rm -f "$nginx_conf"
            log_info "Konfigurasi yang tidak valid telah dihapus"
        else
            log_warning "Konfigurasi yang tidak valid tetap disimpan di ${nginx_conf}"
            log_warning "Silakan perbaiki konfigurasi secara manual"
        fi
        return 1
    fi

    if [ "$use_subdomain" = true ]; then
        log_info "Instalasi phpMyAdmin dengan subdomain selesai!"
        log_info "Akses phpMyAdmin di: http://${domain_name}"

        if [ "$use_ssl" = "y" ]; then
            log_info "Atau dengan HTTPS: https://${domain_name}"
        fi
    else
        log_info "Instalasi phpMyAdmin dengan subfolder selesai!"
        log_info "Akses phpMyAdmin di: http://${domain_name}/${pma_folder}"

        if [ "$use_ssl" = "y" ]; then
            log_info "Atau dengan HTTPS: https://${domain_name}/${pma_folder}"
        fi
    fi

    # Tambahkan substitusi untuk DOMAIN_NAME
    sed -i "s/DOMAIN_NAME/${domain_name}/g" "$nginx_conf"

    # Tampilkan informasi tambahan
    echo
    log_info "INFORMASI PENTING:"
    echo "1. Lokasi instalasi: ${pma_path}"
    echo "2. Log Nginx: "
    echo "   - Error: /var/log/nginx/${domain_name}_error.log"
    echo "   - Access: /var/log/nginx/${domain_name}_access.log"
    echo "3. Log PHP-FPM: /var/log/php${selected_php_version}-fpm.log"
    echo
    log_warning "REKOMENDASI KEAMANAN:"
    echo "1. Aktifkan SSL/HTTPS melalui Cloudflare"
    echo "2. Pertimbangkan untuk mengaktifkan basic authentication"
    echo "3. Batasi akses IP jika memungkinkan"
    echo "4. Periksa log secara berkala"

    if [ "$use_subdomain" = false ]; then
        echo "5. Pertimbangkan untuk mengubah nama folder phpMyAdmin dari '${pma_folder}'"
    fi
}

install_nodejs() {
    log_info "Mempersiapkan instalasi Node.js dan npm..."
    check_and_install_package curl

    # Tambahkan repository Node.js jika belum ada
    if [ ! -f /etc/apt/sources.list.d/nodesource.list ]; then
        log_info "Menambahkan repository Node.js..."
        curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
    else
        log_info "Repository Node.js sudah ada, skip."
    fi

    log_info "Menginstal Node.js dan npm..."
    echo "[1/1] Install Node.js dan npm..."
    safe_apt_install -y nodejs

    # Update npm ke versi terbaru
    log_info "Mengupdate npm ke versi terbaru..."
    npm install -g npm@latest

    # Install beberapa package global yang umum digunakan
    log_info "Menginstal package global (pm2, yarn)..."
    npm install -g pm2 yarn

    if command -v node > /dev/null; then
        node_version=$(node -v)
        npm_version=$(npm -v)
        log_info "Node.js ${node_version} dan npm ${npm_version} berhasil diinstall!"
        log_info "Package global yang terinstall: pm2, yarn"
    else
        log_error "Gagal menginstal Node.js dan npm"
    fi
}

install_frankenphp() {
    log_info "Mempersiapkan instalasi FrankenPHP..."
    check_and_install_package curl
    check_and_install_package gpg

    # Tambahkan repository FrankenPHP jika belum ada
    if [ ! -f /etc/apt/sources.list.d/frankenphp.list ]; then
        curl -sSL https://deb.frankenphp.dev/frankenphp.asc | gpg --dearmor -o /usr/share/keyrings/frankenphp-archive-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/frankenphp-archive-keyring.gpg] https://deb.frankenphp.dev jammy main" | tee /etc/apt/sources.list.d/frankenphp.list > /dev/null
    else
        log_info "Repository FrankenPHP sudah ada, skip."
    fi

    log_info "Menginstal FrankenPHP..."
    echo "[1/1] Install FrankenPHP..."
    safe_apt_update
    safe_apt_install -y frankenphp

    if [ $? -eq 0 ]; then
        log_info "FrankenPHP berhasil diinstall!"
        # Buat service untuk FrankenPHP
        cat > /etc/systemd/system/frankenphp.service << 'EOF'
[Unit]
Description=FrankenPHP Application Server
After=network.target

[Service]
Type=simple
User=www-data
ExecStart=/usr/local/bin/frankenphp run --config /etc/frankenphp/Caddyfile
Restart=always

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl enable frankenphp
        systemctl start frankenphp
    else
        log_error "Gagal menginstal FrankenPHP"
    fi
}

install_wordpress() {
    log_info "Mempersiapkan instalasi WordPress..."
    check_and_install_package curl
    check_and_install_package unzip
    check_and_install_package nginx

    # Pastikan PHP dan ekstensi yang dibutuhkan terinstal
    if [ -z "$selected_php_version" ]; then
        for version in "8.3" "8.2" "8.1" "8.0" "7.4"; do
            if dpkg -l | grep -q "php$version"; then
                selected_php_version="$version"
                break
            fi
        done
    fi
    if [ -z "$selected_php_version" ]; then
        log_error "PHP belum terinstal. Silakan install PHP terlebih dahulu."
        return 1
    fi
    log_info "Menggunakan PHP versi ${selected_php_version}"
    check_and_install_package "php${selected_php_version}-fpm"
    check_and_install_package "php${selected_php_version}-mysql"
    check_and_install_package "php${selected_php_version}-xml"
    check_and_install_package "php${selected_php_version}-curl"
    check_and_install_package "php${selected_php_version}-gd"
    check_and_install_package "php${selected_php_version}-mbstring"
    check_and_install_package "php${selected_php_version}-zip"

    # Tanya domain utama atau subdomain
    echo "Pilih jenis domain untuk WordPress:"
    echo "1. Domain utama (contoh: domain.com)"
    echo "2. Subdomain (contoh: blog.domain.com)"
    read -p "Pilihan [1-2]: " domain_type

    if [ "$domain_type" = "1" ]; then
        read -p "Masukkan domain utama (contoh: domain.com): " domain_name
        wp_path="/var/www/${domain_name}"
    else
        read -p "Masukkan domain utama (contoh: domain.com): " main_domain
        read -p "Masukkan subdomain (contoh: blog): " subdomain
        subdomain=${subdomain:-blog}
        domain_name="${subdomain}.${main_domain}"
        wp_path="/var/www/${domain_name}"
    fi
    mkdir -p "$wp_path"

    # Download WordPress
    log_info "Mengunduh WordPress..."
    curl -L https://wordpress.org/latest.zip -o /tmp/wordpress.zip
    unzip -oq /tmp/wordpress.zip -d /tmp/
    rsync -a /tmp/wordpress/ "$wp_path/"

    # Set permission
    chown -R www-data:www-data "$wp_path"
    find "$wp_path" -type d -exec chmod 755 {} \;
    find "$wp_path" -type f -exec chmod 644 {} \;

    # Konfigurasi database
    read -p "Masukkan nama database WordPress: " db_name
    read -p "Masukkan username database: " db_user
    read -s -p "Masukkan password database: " db_pass; echo
    read -p "Masukkan host database [localhost]: " db_host
    db_host=${db_host:-localhost}

    # Buat wp-config.php
    cp "$wp_path/wp-config-sample.php" "$wp_path/wp-config.php"
    sed -i "s/database_name_here/${db_name}/" "$wp_path/wp-config.php"
    sed -i "s/username_here/${db_user}/" "$wp_path/wp-config.php"
    sed -i "s/password_here/${db_pass}/" "$wp_path/wp-config.php"
    sed -i "s/localhost/${db_host}/" "$wp_path/wp-config.php"

    # Generate unique keys
    keys=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)
    if [ -n "$keys" ]; then
        sed -i "/AUTH_KEY/d;/SECURE_AUTH_KEY/d;/LOGGED_IN_KEY/d;/NONCE_KEY/d;/AUTH_SALT/d;/SECURE_AUTH_SALT/d;/LOGGED_IN_SALT/d;/NONCE_SALT/d" "$wp_path/wp-config.php"
        sed -i "/@since 2.6.0/a $keys" "$wp_path/wp-config.php"
    fi

    # Bersihkan file temporary
    rm -rf /tmp/wordpress /tmp/wordpress.zip

    # Generate konfigurasi Nginx
    nginx_conf="/etc/nginx/sites-available/${domain_name}"
    log_info "Membuat konfigurasi Nginx untuk ${domain_name}..."
    cat > "$nginx_conf" <<EOF
server {
    listen 80;
    server_name ${domain_name};
    root ${wp_path};
    index index.php index.html index.htm;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied expired no-cache no-store private must-revalidate auth;
    gzip_types
        application/atom+xml
        application/javascript
        application/json
        application/rss+xml
        application/vnd.ms-fontobject
        application/x-font-ttf
        application/x-web-app-manifest+json
        application/xhtml+xml
        application/xml
        font/opentype
        image/svg+xml
        image/x-icon
        text/css
        text/plain
        text/x-component;

    # Block access to sensitive files
    location ~* \.(htaccess|htpasswd|ini|log|sh|sql|conf)$ {
        deny all;
    }

    # Block access to wp-config.php
    location ~* wp-config\.php {
        deny all;
    }

    # Block access to readme files
    location ~* ^.*(readme|license|changelog)\.(txt|md)$ {
        deny all;
    }

    # Block access to xmlrpc.php (prevent brute force attacks)
    location = /xmlrpc.php {
        deny all;
    }

    # WordPress permalinks
    location / {
        try_files $uri $uri/ /index.php?$args;
    }

    # Handle PHP files
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php${selected_php_version}-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
        
        # Security for PHP
        fastcgi_hide_header X-Powered-By;
        fastcgi_read_timeout 300;
        fastcgi_buffer_size 128k;
        fastcgi_buffers 4 256k;
        fastcgi_busy_buffers_size 256k;
    }

    # Cache static files
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    # WordPress uploads directory
    location ~* ^/wp-content/uploads/.*\.(php|php5|phtml|pl|py|jsp|asp|sh|cgi)$ {
        deny all;
    }

    # Deny access to wp-admin for non-logged users
    location ~* ^/wp-admin/(.*) {
        location ~ ^/wp-admin/admin-ajax\.php$ {
            try_files $uri /index.php?$args;
            include snippets/fastcgi-php.conf;
            fastcgi_pass unix:/var/run/php/php${selected_php_version}-fpm.sock;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            include fastcgi_params;
        }
        
        location ~ ^/wp-admin/(.*) {
            try_files $uri /index.php?$args;
            include snippets/fastcgi-php.conf;
            fastcgi_pass unix:/var/run/php/php${selected_php_version}-fpm.sock;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            include fastcgi_params;
        }
    }

    # Error and access logs
    error_log /var/log/nginx/${domain_name}_error.log;
    access_log /var/log/nginx/${domain_name}_access.log;
}
EOF

    log_info "Konfigurasi Nginx berhasil dibuat di $nginx_conf"

    # Tawarkan aktivasi config dan restart Nginx
    read -p "Aktifkan konfigurasi Nginx untuk ${domain_name}? (y/n): " enable_config
    if [ "$enable_config" = "y" ]; then
        ln -sf "$nginx_conf" "/etc/nginx/sites-enabled/"
        log_info "Konfigurasi ${domain_name} diaktifkan"
        read -p "Restart service Nginx sekarang? (y/n): " restart_nginx
        if [ "$restart_nginx" = "y" ]; then
            systemctl restart nginx
            log_info "Service Nginx berhasil di-restart"
        else
            log_info "Service Nginx tidak di-restart. Perubahan akan berlaku setelah Nginx di-restart."
            log_info "Untuk me-restart Nginx, jalankan: sudo systemctl restart nginx"
        fi

        # Tambahkan: Tawarkan instalasi SSL Certbot
        read -p "Ingin mengaktifkan SSL gratis (Let's Encrypt) untuk domain ${domain_name}? (y/n): " enable_ssl
        if [ "$enable_ssl" = "y" ]; then
            log_info "Menginstal certbot dan plugin nginx..."
            safe_apt_update && safe_apt_install -y certbot python3-certbot-nginx
            log_info "Menjalankan certbot untuk domain ${domain_name}..."
            certbot --nginx -d ${domain_name} --non-interactive --agree-tos -m admin@${domain_name} || log_warning "Certbot gagal, cek log untuk detail."
            systemctl reload nginx
            log_info "SSL Let's Encrypt telah diaktifkan untuk https://${domain_name}"
        fi
    else
        log_info "Konfigurasi ${domain_name} tidak diaktifkan, tersimpan di $nginx_conf"
        log_info "Untuk mengaktifkan nanti, jalankan: sudo ln -sf $nginx_conf /etc/nginx/sites-enabled/"
    fi

    log_info "WordPress berhasil diinstal di $wp_path"
    log_info "Akses instalasi melalui: http://${domain_name}"
} 

offer_ssl_for_all_domains() {
    log_info "Mendeteksi domain yang belum memiliki SSL..."
    local domains=()
    local confs=()
    local i=1
    for conf in /etc/nginx/sites-enabled/*; do
        [ -e "$conf" ] || continue
        domain=$(basename "$conf")
        # Kecualikan localhost dan 127.0.0.1
        if [[ "$domain" =~ localhost|127.0.0.1 ]]; then
            continue
        fi
        if grep -q 'listen 443' "$conf" || grep -q 'ssl_certificate' "$conf"; then
            continue
        fi
        domains+=("$domain")
        confs+=("$conf")
    done
    if [ ${#domains[@]} -eq 0 ]; then
        log_info "Semua domain sudah memiliki SSL atau tidak ada domain yang terdeteksi."
        return
    fi
    echo "Domain yang belum memiliki SSL:"
    echo "----------------------------------------"
    echo " No  | Domain"
    echo "-----+-------------------------------"
    for idx in "${!domains[@]}"; do
        printf " %2d  | %s\n" $((idx+1)) "${domains[$idx]}"
    done
    echo "----------------------------------------"
    echo
    read -p "Masukkan nomor domain yang ingin diaktifkan SSL (pisahkan dengan spasi/koma, atau ketik 'all' untuk semua): " input
    if [[ "$input" == "all" ]]; then
        selected=("${domains[@]}")
    else
        IFS=', ' read -ra nums <<< "$input"
        selected=()
        for n in "${nums[@]}"; do
            n=$(echo $n | tr -d ' ')
            if [[ $n =~ ^[0-9]+$ ]] && (( n >= 1 && n <= ${#domains[@]} )); then
                selected+=("${domains[$((n-1))]}")
            fi
        done
    fi
    if [ ${#selected[@]} -eq 0 ]; then
        log_warning "Tidak ada domain yang dipilih."
        return
    fi
    log_info "Akan mengaktifkan SSL untuk: ${selected[*]}"
    # Cek status UFW untuk port 80 dan 443
    local need_allow=0
    local ufw_status=""
    if command -v ufw >/dev/null 2>&1; then
        ufw_status=$(ufw status | grep -E '80/tcp|443/tcp')
        if ! echo "$ufw_status" | grep -q '80/tcp.*ALLOW'; then
            need_allow=1
        fi
        if ! echo "$ufw_status" | grep -q '443/tcp.*ALLOW'; then
            need_allow=1
        fi
        if [ $need_allow -eq 1 ]; then
            echo -e "\e[1;33m[INFO]\e[0m Port 80 dan/atau 443 belum terbuka di firewall (UFW)."
            echo "1. Buka port 80 & 443 otomatis"
            echo "2. Batal/atur manual"
            read -p "Pilih [1-2]: " ufw_opt
            if [ "$ufw_opt" = "1" ]; then
                sudo ufw allow 80/tcp
                sudo ufw allow 443/tcp
                sudo ufw reload
                echo -e "\e[1;32m[SUKSES]\e[0m Port 80 & 443 berhasil dibuka di UFW."
                read -p "Tekan Enter untuk lanjut install SSL..."
            else
                log_warning "Batal, silakan atur port firewall manual lalu ulangi proses SSL."
                return
            fi
        fi
    fi
    # Install certbot & plugin hanya jika belum ada
    if ! command -v certbot >/dev/null 2>&1 || ! dpkg -l | grep -q python3-certbot-nginx; then
        safe_apt_update
        safe_apt_install -y certbot python3-certbot-nginx
    fi
    echo
    read -p "Apakah Anda sudah punya akun Let's Encrypt? (y/n): " has_account
    if [[ "$has_account" =~ ^[Yy]$ ]]; then
        read -p "Masukkan email akun Let's Encrypt Anda: " certbot_email
    else
        certbot_email=""
    fi
    for domain in "${selected[@]}"; do
        if [ -z "$certbot_email" ]; then
            certbot_email="admin@$domain"
        fi
        log_info "Menjalankan certbot untuk domain $domain (email: $certbot_email)..."
        certbot_out=$(certbot --nginx -d $domain --non-interactive --agree-tos -m "$certbot_email" 2>&1)
        if [ $? -eq 0 ]; then
            log_info "\e[1;32m[SUKSES]\e[0m SSL aktif untuk https://$domain (email: $certbot_email)"
        else
            log_error "Certbot gagal untuk $domain:"
            echo "$certbot_out" | tail -n 10
        fi
    done
    systemctl reload nginx
    log_info "Proses SSL selesai untuk domain terpilih."
} 

setup_basic_vps() {
    echo
    # Mirror APT
    if [ ! -f /etc/vps_setup_done_mirror ]; then
        read -p "Ingin mengubah mirror APT sebelum setup dasar? (y/n): " change_mirror
        if [[ "$change_mirror" =~ ^[Yy]$ ]]; then
            change_apt_mirror
            touch /etc/vps_setup_done_mirror
        fi
    else
        log_info "Mirror APT sudah pernah diatur, skip."
    fi
    # Update & Upgrade
    if [ -f /etc/vps_setup_done_update ]; then
        log_info "Update & upgrade sudah dilakukan, skip."
    else
        log_info "[1/4] Update & Upgrade Sistem..."
        safe_apt_update
        safe_apt_upgrade -y
        log_info "Update & upgrade selesai."
        touch /etc/vps_setup_done_update
    fi
    echo
    # Hostname
    if [ -f /etc/vps_setup_done_hostname ]; then
        log_info "Hostname sudah diubah, skip."
    else
        read -p "Masukkan hostname baru untuk VPS: " new_hostname
        if [ -n "$new_hostname" ]; then
            hostnamectl set-hostname "$new_hostname"
            log_info "Hostname diubah menjadi $new_hostname"
            echo "$new_hostname" > /etc/vps_setup_done_hostname
        else
            log_warning "Hostname tidak diubah."
        fi
    fi
    echo
    # Timezone
    if [ -f /etc/vps_setup_done_timezone ]; then
        log_info "Timezone sudah diubah, skip."
    else
        read -p "Masukkan timezone (misal: Asia/Jakarta): " timezone
        if [ -n "$timezone" ]; then
            timedatectl set-timezone "$timezone"
            log_info "Timezone diubah menjadi $timezone"
            echo "$timezone" > /etc/vps_setup_done_timezone
        else
            log_warning "Timezone tidak diubah."
        fi
    fi
    echo
    # Locale
    if [ -f /etc/vps_setup_done_locale ]; then
        log_info "Locale sudah diubah, skip."
    else
        read -p "Masukkan locale (misal: en_US.UTF-8): " locale
        if [ -n "$locale" ]; then
            update-locale LANG=$locale
            log_info "Locale diubah menjadi $locale"
            echo "$locale" > /etc/vps_setup_done_locale
        else
            log_warning "Locale tidak diubah."
        fi
    fi
    echo
    # UFW
    if [ -f /etc/vps_setup_done_ufw ]; then
        log_info "UFW (Firewall) sudah aktif, skip."
    else
        log_info "[4/4] Install & Enable UFW (Firewall)..."
        safe_apt_install -y ufw
        ufw allow OpenSSH
        ufw --force enable
        log_info "UFW aktif. Port SSH diizinkan."
        touch /etc/vps_setup_done_ufw
    fi
    echo
    log_info "Setup dasar VPS selesai! Sangat disarankan reboot setelah ini."
} 