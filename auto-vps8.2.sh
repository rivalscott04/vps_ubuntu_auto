#!/bin/bash

# Warna untuk output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Fungsi untuk logging
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Pastikan script dijalankan sebagai root
if [ "$(id -u)" -ne 0 ]; then
    log_error "Script ini harus dijalankan sebagai root. Gunakan sudo."
    exit 1
fi

# Fungsi untuk memastikan paket tertentu sudah terinstal
check_and_install_package() {
    if ! dpkg -l | grep -q "^ii  $1 "; then
        log_warning "Paket $1 belum terinstal. Menginstal..."
        apt update > /dev/null 2>&1
        apt install -y $1 > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            log_info "Paket $1 berhasil diinstal"
        else
            log_error "Gagal menginstal paket $1"
            exit 1
        fi
    fi
}
# Fungsi untuk menambahkan PPA Web Server
add_webserver_ppa() {
    log_info "Menyesuaikan PPA untuk Web Server..."

    if dpkg -l | grep -q "apache2"; then
        add_ppa_if_needed "ondrej/apache2"
    elif dpkg -l | grep -q "nginx"; then
        echo "Pilih versi Nginx yang akan diinstall:"
        echo "1. Nginx Mainline (ppa:ondrej/nginx-mainline)"
        echo "2. Nginx Stable (ppa:ondrej/nginx)"
        read -p "Pilihan [1-2]: " nginx_choice

        case $nginx_choice in
            1) add_ppa_if_needed "ondrej/nginx-mainline" ;;
            2) add_ppa_if_needed "ondrej/nginx" ;;
            *) log_warning "Pilihan tidak valid, menggunakan default (Stable)"
               add_ppa_if_needed "ondrej/nginx" ;;
        esac
    fi
}

# Fungsi untuk menambahkan PPA PHP
add_php_repository() {
    log_info "Menyesuaikan PPA untuk PHP..."
    add_ppa_if_needed "ondrej/php"
}

# Fungsi untuk menambahkan PPA hanya jika belum ada
add_ppa_if_needed() {
    local ppa_name=$1
    local ppa_list="/etc/apt/sources.list.d/${ppa_name}*.list"

    if ls $ppa_list 1> /dev/null 2>&1; then
        log_info "PPA $ppa_name sudah ditambahkan"
    else
        log_info "Menambahkan PPA $ppa_name..."
        add-apt-repository -y ppa:$ppa_name > /dev/null 2>&1
        apt update > /dev/null 2>&1
    fi
}

# Fungsi 1: Instalasi dan Konfigurasi PHP
install_php() {
    add_php_repository

    apt update > /dev/null 2>&1

    echo "Pilih versi PHP yang akan diinstall:"
    echo "1. PHP 8.1"
    echo "2. PHP 8.2"
    echo "3. PHP 8.3"
    read -p "Pilihan [1-3]: " php_choice

    case $php_choice in
        1) selected_php_version="8.1" ;;
        2) selected_php_version="8.2" ;;
        3) selected_php_version="8.3" ;;
        *) log_error "Pilihan tidak valid"; return ;;
    esac

    log_info "Menginstal PHP ${selected_php_version} dan ekstensi..."

    apt install -y php${selected_php_version} php${selected_php_version}-fpm php${selected_php_version}-cli \
                   php${selected_php_version}-common php${selected_php_version}-mysql php${selected_php_version}-zip \
                   php${selected_php_version}-gd php${selected_php_version}-mbstring php${selected_php_version}-curl \
                   php${selected_php_version}-xml php${selected_php_version}-bcmath php${selected_php_version}-pgsql \
                   php${selected_php_version}-intl php${selected_php_version}-readline php${selected_php_version}-ldap \
                   php${selected_php_version}-msgpack php${selected_php_version}-igbinary php${selected_php_version}-redis \
                   > /dev/null 2>&1

    if [ $? -eq 0 ]; then
        log_info "PHP ${selected_php_version} berhasil diinstall!"
        configure_php ${selected_php_version}
        # Export PHP version untuk digunakan di fungsi lain
        export selected_php_version
    else
        log_error "Gagal menginstal PHP ${selected_php_version}"
    fi
}

# Fungsi untuk menginstal Web Server
install_webserver() {
    log_info "Menginstal Nginx..."
    add_ppa_if_needed "ondrej/nginx-mainline"
    apt install -y nginx > /dev/null 2>&1
    systemctl restart nginx
    log_info "Nginx berhasil diinstall!"
}

# Fungsi 3: Instalasi dan Konfigurasi Database
install_database() {
    echo "Pilih database yang akan diinstall:"
    echo "1. MySQL"
    echo "2. PostgreSQL"
    echo "3. MariaDB"
    read -p "Pilihan [1-3]: " db_choice

    case $db_choice in
        1|3)  # MySQL atau MariaDB
            if [ "$db_choice" = "1" ]; then
                log_info "Menginstal MySQL..."
                apt install -y mysql-server > /dev/null 2>&1
            else
                log_info "Menginstal MariaDB..."
                apt install -y mariadb-server > /dev/null 2>&1
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

        2) log_info "Menginstal PostgreSQL..."
           apt install -y postgresql postgresql-contrib > /dev/null 2>&1
           log_info "PostgreSQL berhasil diinstall!"
           ;;

        *) log_error "Pilihan tidak valid" ;;
    esac
}

# Fungsi untuk menginstal phpMyAdmin
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
        pma_path="/var/www/html/${domain_name}"
    else
        # Konfigurasi untuk subfolder
        read -p "Masukkan domain utama (contoh: domain.com): " domain_name
        read -p "Masukkan nama folder untuk phpMyAdmin [pma]: " pma_folder

        # Default ke 'pma' jika input kosong
        pma_folder=${pma_folder:-pma}

        # Set path instalasi
        pma_path="/var/www/html/${domain_name}/${pma_folder}"
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

    # Hapus referensi ke weding.domain.com jika ada
    if [ -f "/etc/nginx/sites-enabled/weding.domain.com" ]; then
        log_warning "Menghapus referensi ke weding.domain.com..."
        rm -f "/etc/nginx/sites-enabled/weding.domain.com"
    fi

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
    root /var/www/html/${domain_name};
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
# Fungsi 5: Instalasi Node.js & npm
install_nodejs() {
    log_info "Mempersiapkan instalasi Node.js dan npm..."
    check_and_install_package curl

    # Tambahkan repository Node.js
    log_info "Menambahkan repository Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - > /dev/null 2>&1

    log_info "Menginstal Node.js dan npm..."
    apt install -y nodejs > /dev/null 2>&1

    # Update npm ke versi terbaru
    log_info "Mengupdate npm ke versi terbaru..."
    npm install -g npm@latest > /dev/null 2>&1

    # Install beberapa package global yang umum digunakan
    log_info "Menginstal package global (pm2, yarn)..."
    npm install -g pm2 yarn > /dev/null 2>&1

    if command -v node > /dev/null; then
        node_version=$(node -v)
        npm_version=$(npm -v)
        log_info "Node.js ${node_version} dan npm ${npm_version} berhasil diinstall!"
        log_info "Package global yang terinstall: pm2, yarn"
    else
        log_error "Gagal menginstal Node.js dan npm"
    fi
}

# Fungsi 6: Instalasi FrankenPHP
install_frankenphp() {
    log_info "Mempersiapkan instalasi FrankenPHP..."
    check_and_install_package curl
    check_and_install_package gpg

    # Tambahkan repository FrankenPHP
    curl -sSL https://deb.frankenphp.dev/frankenphp.asc | gpg --dearmor -o /usr/share/keyrings/frankenphp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/frankenphp-archive-keyring.gpg] https://deb.frankenphp.dev jammy main" | tee /etc/apt/sources.list.d/frankenphp.list > /dev/null

    log_info "Menginstal FrankenPHP..."
    apt update > /dev/null 2>&1
    apt install -y frankenphp > /dev/null 2>&1

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

# Fungsi 7: Konfigurasi Aplikasi Web dengan pilihan stack (PHP/Laravel atau JavaScript)
configure_webapp() {
    # Pilih stack teknologi
    echo "Pilih stack teknologi yang digunakan:"
    echo "1. PHP Native"
    echo "2. Laravel"
    echo "3. JavaScript (Node.js/React/Vue/dll)"
    read -p "Pilihan [1-3]: " stack_choice

    case $stack_choice in
        1)
            stack_type="php"
            use_laravel="n"
            log_info "Stack PHP Native dipilih"
            ;;
        2)
            stack_type="php"
            use_laravel="y"
            log_info "Stack Laravel dipilih"
            ;;
        3)
            stack_type="js"
            log_info "Stack JavaScript dipilih"
            ;;
        *)
            log_error "Pilihan tidak valid, menggunakan default (PHP Native)"
            stack_type="php"
            use_laravel="n"
            ;;
    esac

    # Tanya path aplikasi dan domain
    read -p "Masukkan path aplikasi (contoh: /var/www/html/namaaplikasi): " app_path

    # Validasi input path
    if [ -z "$app_path" ]; then
        log_error "Path aplikasi tidak boleh kosong"
        return 1
    fi

    # Tanya jenis domain
    echo "Pilih jenis domain:"
    echo "1. Domain utama (contoh: domain.com)"
    echo "2. Subdomain (contoh: app.domain.com)"
    read -p "Pilihan [1-2]: " domain_type

    case $domain_type in
        1)
            read -p "Masukkan domain utama (contoh: domain.com): " domain_name
            ;;
        2)
            read -p "Masukkan domain utama (contoh: domain.com): " main_domain
            read -p "Masukkan subdomain (contoh: app): " subdomain
            domain_name="${subdomain}.${main_domain}"
            log_info "Menggunakan subdomain: ${domain_name}"
            ;;
        *)
            log_error "Pilihan tidak valid, menggunakan domain utama"
            read -p "Masukkan domain utama (contoh: domain.com): " domain_name
            ;;
    esac

    # Validasi input domain
    if [ -z "$domain_name" ]; then
        log_error "Domain tidak boleh kosong"
        return 1
    fi

    # Konfigurasi berdasarkan stack yang dipilih
    if [ "$stack_type" = "php" ]; then
        # Sesuaikan path untuk Laravel
        if [ "$use_laravel" = "y" ]; then
            # Laravel menggunakan /public sebagai document root
            full_path="$app_path"
            app_path="${app_path}/public"
            log_info "Laravel terdeteksi, root diatur ke: $app_path"
        else
            full_path="$app_path"
            log_info "PHP Native terdeteksi, root diatur ke: $app_path"
        fi

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
    else
        # JavaScript stack
        full_path="$app_path"

        # Default untuk JavaScript adalah menggunakan folder dist
        js_public_path="${app_path}/dist"
        log_info "JavaScript terdeteksi, root diatur ke: $js_public_path (folder dist)"

        # Tanya apakah menggunakan proxy untuk Node.js
        read -p "Apakah aplikasi berjalan sebagai service Node.js? (y/n): " use_nodejs_service

        if [ "$use_nodejs_service" = "y" ]; then
            read -p "Port aplikasi Node.js (default: 3000): " nodejs_port
            nodejs_port=${nodejs_port:-3000}
            log_info "Konfigurasi proxy untuk Node.js pada port ${nodejs_port}"
        else
            # Tanya apakah menggunakan Vite
            read -p "Apakah aplikasi menggunakan Vite.js? (y/n): " use_vite

            if [ "$use_vite" = "y" ]; then
                log_info "Konfigurasi untuk aplikasi Vite.js akan dibuat"

                # Tanya apakah perlu konfigurasi untuk development server
                read -p "Apakah perlu konfigurasi untuk Vite development server? (y/n): " use_vite_dev

                if [ "$use_vite_dev" = "y" ]; then
                    read -p "Port Vite development server (default: 5173): " vite_port
                    vite_port=${vite_port:-5173}
                    log_info "Konfigurasi proxy untuk Vite development server pada port ${vite_port}"
                fi
            fi
        fi
    fi

    read -p "Apakah menggunakan SSL/HTTPS via Cloudflare? (y/n): " use_ssl

    # Buat direktori jika belum ada
    mkdir -p "$full_path"

    # Buat direktori dist untuk JavaScript jika diperlukan
    if [ "$stack_type" = "js" ] && [ "$use_nodejs_service" != "y" ]; then
        mkdir -p "$js_public_path"
        log_info "Membuat direktori dist untuk aplikasi JavaScript: $js_public_path"
    fi

    chown -R www-data:www-data "$full_path"
    chmod -R 755 "$full_path"

    # Buat file error page dasar jika PHP Native
    if [ "$stack_type" = "php" ] && [ "$use_laravel" = "n" ]; then
        log_info "Membuat file error page dasar untuk PHP Native..."

        # Buat file 404.html jika belum ada
        if [ ! -f "${full_path}/404.html" ]; then
            cat > "${full_path}/404.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>404 - Halaman Tidak Ditemukan</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
        h1 { font-size: 36px; margin-bottom: 20px; }
        p { font-size: 18px; color: #666; }
    </style>
</head>
<body>
    <h1>404 - Halaman Tidak Ditemukan</h1>
    <p>Maaf, halaman yang Anda cari tidak ditemukan.</p>
    <p><a href="/">Kembali ke Beranda</a></p>
</body>
</html>
EOF
            log_info "File 404.html berhasil dibuat"
        fi

        # Buat file 50x.html jika belum ada
        if [ ! -f "${full_path}/50x.html" ]; then
            cat > "${full_path}/50x.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>500 - Kesalahan Server</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
        h1 { font-size: 36px; margin-bottom: 20px; }
        p { font-size: 18px; color: #666; }
    </style>
</head>
<body>
    <h1>500 - Kesalahan Server</h1>
    <p>Maaf, terjadi kesalahan pada server.</p>
    <p><a href="/">Kembali ke Beranda</a></p>
</body>
</html>
EOF
            log_info "File 50x.html berhasil dibuat"
        fi
    fi

    log_info "Membuat konfigurasi Nginx untuk ${domain_name}..."

    # Base configuration
    cat > "/etc/nginx/sites-available/${domain_name}" << 'EOF'
server {
    listen 80;
    server_name DOMAIN;

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
EOF

    # Tambahkan konfigurasi berdasarkan stack
    if [ "$stack_type" = "php" ]; then
        # Tambahkan root path untuk PHP
        cat >> "/etc/nginx/sites-available/${domain_name}" << 'EOF'

    root APPPATH;
    index index.php index.html index.htm;
EOF

        if [ "$use_laravel" = "y" ]; then
            # Konfigurasi untuk Laravel
            cat >> "/etc/nginx/sites-available/${domain_name}" << 'EOF'

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    # Laravel specific error handling
    error_page 404 /index.php;

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/phpPHPVER-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
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

    location ~ /\.(?!well-known).* {
        deny all;
    }
EOF
        else
            # Konfigurasi untuk PHP Native
            cat >> "/etc/nginx/sites-available/${domain_name}" << 'EOF'

    location / {
        try_files $uri $uri/ =404;
    }

    # Standard PHP error handling
    error_page 404 /404.html;
    error_page 500 502 503 504 /50x.html;

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/phpPHPVER-fpm.sock;

        # Extended timeout
        fastcgi_read_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_connect_timeout 300;
    }

    location ~ /\.ht {
        deny all;
    }
EOF
        fi
    else
        # Konfigurasi untuk JavaScript
        if [ "$use_nodejs_service" = "y" ]; then
            # Konfigurasi proxy untuk Node.js
            cat >> "/etc/nginx/sites-available/${domain_name}" << 'EOF'

    location / {
        proxy_pass http://localhost:NODEJS_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
EOF
        else
            if [ "$use_vite" = "y" ]; then
                if [ "$use_vite_dev" = "y" ]; then
                    # Konfigurasi untuk Vite development server
                    cat >> "/etc/nginx/sites-available/${domain_name}" << 'EOF'

    root APPPATH;
    index index.html index.htm;

    location / {
        try_files $uri $uri/ /index.html;
    }

    # Proxy untuk Vite dev server
    location /@vite {
        proxy_pass http://localhost:VITE_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }

    # Proxy untuk HMR WebSocket
    location /ws {
        proxy_pass http://localhost:VITE_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }

    # SPA error handling
    error_page 404 /index.html;
EOF
                else
                    # Konfigurasi untuk Vite production build
                    cat >> "/etc/nginx/sites-available/${domain_name}" << 'EOF'

    root APPPATH;
    index index.html index.htm;

    location / {
        try_files $uri $uri/ /index.html;
    }

    # Vite assets caching
    location /assets/ {
        expires 1y;
        add_header Cache-Control "public, max-age=31536000, immutable";
    }

    # SPA error handling
    error_page 404 /index.html;

    # Cache static assets
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg)$ {
        expires 30d;
        add_header Cache-Control "public, no-transform";
    }
EOF
                fi
            else
                # Konfigurasi untuk static files (SPA) standar
                cat >> "/etc/nginx/sites-available/${domain_name}" << 'EOF'

    root APPPATH;
    index index.html index.htm;

    location / {
        try_files $uri $uri/ /index.html;
    }

    # SPA error handling
    error_page 404 /index.html;

    # Cache static assets
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg)$ {
        expires 30d;
        add_header Cache-Control "public, no-transform";
    }
EOF
            fi
        fi
    fi

    # Close server block
    cat >> "/etc/nginx/sites-available/${domain_name}" << EOF

    # Logging
    error_log /var/log/nginx/${domain_name}_error.log;
    access_log /var/log/nginx/${domain_name}_access.log combined;
}
EOF

    # Replace placeholders
    sed -i "s/DOMAIN/${domain_name}/g" "/etc/nginx/sites-available/${domain_name}"
    sed -i "s/DOMAIN_NAME/${domain_name}/g" "/etc/nginx/sites-available/${domain_name}"

    # Set appropriate path based on stack type
    if [ "$stack_type" = "php" ]; then
        sed -i "s|APPPATH|${app_path}|g" "/etc/nginx/sites-available/${domain_name}"
        sed -i "s/PHPVER/${selected_php_version}/g" "/etc/nginx/sites-available/${domain_name}"
    else
        # For JavaScript applications, use the dist folder path
        if [ "$use_nodejs_service" = "y" ]; then
            # For Node.js services, use the app_path as is
            sed -i "s|APPPATH|${app_path}|g" "/etc/nginx/sites-available/${domain_name}"
            sed -i "s/NODEJS_PORT/${nodejs_port}/g" "/etc/nginx/sites-available/${domain_name}"
        else
            # For static JS apps, use the dist folder
            sed -i "s|APPPATH|${js_public_path}|g" "/etc/nginx/sites-available/${domain_name}"

            if [ "$use_vite" = "y" ] && [ "$use_vite_dev" = "y" ]; then
                sed -i "s/VITE_PORT/${vite_port}/g" "/etc/nginx/sites-available/${domain_name}"
            fi
        fi
    fi

    # Hapus referensi ke weding.domain.com jika ada
    if [ -f "/etc/nginx/sites-enabled/weding.domain.com" ]; then
        log_warning "Menghapus referensi ke weding.domain.com..."
        rm -f "/etc/nginx/sites-enabled/weding.domain.com"
    fi

    # Test konfigurasi Nginx
    log_info "Menguji konfigurasi Nginx..."
    if nginx -t; then
        log_info "Konfigurasi Nginx valid!"

        # Tanya apakah ingin mengaktifkan konfigurasi
        read -p "Aktifkan konfigurasi Nginx untuk ${domain_name}? (y/n): " enable_config

        if [ "$enable_config" = "y" ]; then
            # Create symlink
            ln -sf "/etc/nginx/sites-available/${domain_name}" "/etc/nginx/sites-enabled/"
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
        else
            log_info "Konfigurasi ${domain_name} tidak diaktifkan, tersimpan di /etc/nginx/sites-available/${domain_name}"
            log_info "Untuk mengaktifkan nanti, jalankan: sudo ln -sf /etc/nginx/sites-available/${domain_name} /etc/nginx/sites-enabled/"
        fi
    else
        log_error "Konfigurasi Nginx tidak valid!"
        read -p "Hapus konfigurasi yang tidak valid? (y/n): " remove_config

        if [ "$remove_config" = "y" ]; then
            rm -f "/etc/nginx/sites-available/${domain_name}"
            log_info "Konfigurasi yang tidak valid telah dihapus"
        else
            log_warning "Konfigurasi yang tidak valid tetap disimpan di /etc/nginx/sites-available/${domain_name}"
            log_warning "Silakan perbaiki konfigurasi secara manual"
        fi
        return 1
    fi

    log_info "Konfigurasi aplikasi web selesai!"

    # Tampilkan informasi domain
    if [ "$domain_type" = "1" ]; then
        log_info "Domain utama: ${domain_name}"
    else
        log_info "Subdomain: ${domain_name} (dari domain utama ${main_domain})"
    fi

    log_info "Path aplikasi: ${app_path}"

    if [ "$stack_type" = "php" ]; then
        if [ "$use_laravel" = "y" ]; then
            log_info "Stack: Laravel"
            log_info "Document root: ${app_path} (public folder)"
        else
            log_info "Stack: PHP Native"
            log_info "Document root: ${app_path}"
        fi
    else
        log_info "Stack: JavaScript"
        if [ "$use_nodejs_service" = "y" ]; then
            log_info "Node.js service pada port: ${nodejs_port}"
            log_info "Document root: ${app_path}"
        elif [ "$use_vite" = "y" ]; then
            if [ "$use_vite_dev" = "y" ]; then
                log_info "Vite.js dengan development server pada port: ${vite_port}"
                log_info "Proxy untuk Vite dev server: /@vite"
                log_info "Proxy untuk HMR WebSocket: /ws"
                log_info "Document root: ${js_public_path} (dist folder)"
            else
                log_info "Vite.js (production build)"
                log_info "Optimized caching untuk folder /assets/"
                log_info "Document root: ${js_public_path} (dist folder)"
            fi
        else
            log_info "Static JavaScript (SPA)"
            log_info "Document root: ${js_public_path} (dist folder)"
        fi
    fi

    if [ "$use_ssl" = "y" ]; then
        log_info "SSL/HTTPS via Cloudflare telah dikonfigurasi"
    fi
}

# Fungsi 8: Konfigurasi PHP
configure_php() {
    local php_version=$1
    if [ -z "$php_version" ]; then
        php_version=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
    fi

    php_ini_file="/etc/php/${php_version}/fpm/php.ini"
    php_fpm_file="/etc/php/${php_version}/fpm/pool.d/www.conf"

    if [ ! -f "$php_ini_file" ]; then
        log_error "File php.ini tidak ditemukan di $php_ini_file"
        return
    fi

    log_info "Mengkonfigurasi PHP $php_version..."

    # Backup file konfigurasi asli
    cp $php_ini_file "${php_ini_file}.backup"
    cp $php_fpm_file "${php_fpm_file}.backup"

    # Konfigurasi php.ini
    sed -i 's/^memory_limit = .*/memory_limit = 256M/' $php_ini_file
    sed -i 's/^upload_max_filesize = .*/upload_max_filesize = 64M/' $php_ini_file
    sed -i 's/^post_max_size = .*/post_max_size = 64M/' $php_ini_file
    sed -i 's/^max_execution_time = .*/max_execution_time = 300/' $php_ini_file
    sed -i 's/^max_input_time = .*/max_input_time = 300/' $php_ini_file
    sed -i 's/^;date.timezone =.*/date.timezone = Asia\/Jakarta/' $php_ini_file

    # Konfigurasi PHP-FPM
    sed -i 's/^;emergency_restart_threshold = .*/emergency_restart_threshold = 10/' $php_fpm_file
    sed -i 's/^;emergency_restart_interval = .*/emergency_restart_interval = 1m/' $php_fpm_file
    sed -i 's/^;process_control_timeout = .*/process_control_timeout = 10s/' $php_fpm_file
    sed -i 's/^pm = .*/pm = dynamic/' $php_fpm_file
    sed -i 's/^pm.max_children = .*/pm.max_children = 50/' $php_fpm_file
    sed -i 's/^pm.start_servers = .*/pm.start_servers = 5/' $php_fpm_file
    sed -i 's/^pm.min_spare_servers = .*/pm.min_spare_servers = 5/' $php_fpm_file
    sed -i 's/^pm.max_spare_servers = .*/pm.max_spare_servers = 35/' $php_fpm_file

    # Restart PHP-FPM
    systemctl restart php${php_version}-fpm

    log_info "Konfigurasi PHP selesai!"
    log_info "Backup file tersimpan di ${php_ini_file}.backup dan ${php_fpm_file}.backup"
}


# Fungsi untuk menghapus root dan membuat user baru MySQL
mysql_change_root() {
    log_info "Konfigurasi penggantian user root MySQL..."

    # Input untuk user baru
    read -p "Masukkan username MySQL baru: " mysql_user
    read -s -p "Masukkan password untuk user $mysql_user: " mysql_pass
    echo

    # Buat user baru dan berikan privileges
    mysql -e "CREATE USER '${mysql_user}'@'localhost' IDENTIFIED BY '${mysql_pass}';"
    mysql -e "GRANT ALL PRIVILEGES ON *.* TO '${mysql_user}'@'localhost' WITH GRANT OPTION;"
    mysql -e "FLUSH PRIVILEGES;"

    if [ $? -eq 0 ]; then
        # Hapus user root
        mysql -e "DROP USER 'root'@'localhost';"
        mysql -e "FLUSH PRIVILEGES;"

        if [ $? -eq 0 ]; then
            log_info "User root berhasil dihapus dan diganti dengan user ${mysql_user}"

            # Buat file konfigurasi untuk user baru
            cat > ~/.my.cnf << EOL
[client]
user=${mysql_user}
password=${mysql_pass}
EOL
            chmod 600 ~/.my.cnf

            log_info "File konfigurasi MySQL telah dibuat di ~/.my.cnf"
        else
            log_error "Gagal menghapus user root"
        fi
    else
        log_error "Gagal membuat user baru"
    fi
}



# Fungsi untuk optimasi server
optimize_server() {
    log_info "Memulai optimasi server..."

    # Backup file konfigurasi sebelum modifikasi
    log_info "Membuat backup file konfigurasi..."
    cp /etc/sysctl.conf /etc/sysctl.conf.backup
    cp /etc/security/limits.conf /etc/security/limits.conf.backup

    # 1. Konfigurasi parameter kernel untuk performa optimal
    log_info "Mengkonfigurasi parameter kernel..."
    cat > /etc/sysctl.d/99-performance.conf << 'EOF'
# Meningkatkan jumlah file yang dapat dibuka
fs.file-max = 2097152

# Meningkatkan batas ukuran mmap
vm.max_map_count = 262144

# Meningkatkan performa I/O
vm.swappiness = 10
vm.dirty_ratio = 60
vm.dirty_background_ratio = 2

# Optimasi TCP/IP stack
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 65535
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.tcp_keepalive_intvl = 15
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_tw_reuse = 1
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.rmem_default = 262144
net.core.wmem_default = 262144
net.ipv4.tcp_congestion_control = cubic
EOF

    # Terapkan konfigurasi sysctl
    sysctl -p /etc/sysctl.d/99-performance.conf > /dev/null 2>&1

    # 2. Pengaturan system limits
    log_info "Mengkonfigurasi system limits..."
    cat >> /etc/security/limits.conf << 'EOF'

# Konfigurasi limits untuk performa optimal
* soft nofile 1048576
* hard nofile 1048576
root soft nofile 1048576
root hard nofile 1048576
* soft nproc 65535
* hard nproc 65535
root soft nproc 65535
root hard nproc 65535
EOF

    # 3. Konfigurasi tambahan untuk performa
    log_info "Mengkonfigurasi pengaturan tambahan..."

    # Pastikan paket tuned terinstall
    check_and_install_package tuned

    # Konfigurasi tuned untuk performa
    tuned-adm profile throughput-performance > /dev/null 2>&1

    log_info "Optimasi server selesai!"
    log_info "Backup file tersimpan di /etc/sysctl.conf.backup dan /etc/security/limits.conf.backup"
}

# Fungsi untuk instalasi dan konfigurasi sistem cache
install_cache_system() {
    log_info "Memulai instalasi sistem cache..."

    echo "Pilih sistem cache yang akan diinstall:"
    echo "1. Redis"
    echo "2. Memcached"
    echo "3. Keduanya (Redis dan Memcached)"
    read -p "Pilihan [1-3]: " cache_choice

    case $cache_choice in
        1) install_redis ;;
        2) install_memcached ;;
        3) install_redis
           install_memcached ;;
        *) log_error "Pilihan tidak valid"; return 1 ;;
    esac

    # Deteksi PHP untuk integrasi
    if command -v php > /dev/null; then
        log_info "PHP terdeteksi, mengkonfigurasi integrasi dengan sistem cache..."

        # Deteksi versi PHP
        if [ -z "$selected_php_version" ]; then
            for version in "8.3" "8.2" "8.1" "8.0" "7.4"; do
                if dpkg -l | grep -q "php$version"; then
                    selected_php_version="$version"
                    break
                fi
            done
        fi

        if [ -n "$selected_php_version" ]; then
            log_info "Menggunakan PHP versi ${selected_php_version}"

            # Instalasi ekstensi PHP untuk Redis jika Redis terinstall
            if command -v redis-cli > /dev/null; then
                check_and_install_package "php${selected_php_version}-redis"
            fi

            # Instalasi ekstensi PHP untuk Memcached jika Memcached terinstall
            if command -v memcached > /dev/null; then
                check_and_install_package "php${selected_php_version}-memcached"
            fi

            # Restart PHP-FPM
            systemctl restart php${selected_php_version}-fpm
        else
            log_warning "Tidak dapat mendeteksi versi PHP yang terinstall"
        fi
    fi

    log_info "Instalasi sistem cache selesai!"
}

# Fungsi untuk instalasi Redis
install_redis() {
    log_info "Menginstal Redis..."

    # Instalasi Redis
    check_and_install_package redis-server

    # Backup konfigurasi asli
    cp /etc/redis/redis.conf /etc/redis/redis.conf.backup

    # Konfigurasi Redis untuk performa optimal
    log_info "Mengkonfigurasi Redis..."
    sed -i 's/^# maxmemory .*/maxmemory 256mb/' /etc/redis/redis.conf
    sed -i 's/^# maxmemory-policy .*/maxmemory-policy allkeys-lru/' /etc/redis/redis.conf

    # Aktifkan dan restart Redis
    systemctl enable redis-server
    systemctl restart redis-server

    if systemctl is-active --quiet redis-server; then
        log_info "Redis berhasil diinstal dan dikonfigurasi!"
    else
        log_error "Gagal mengaktifkan Redis"
    fi
}

# Fungsi untuk instalasi Memcached
install_memcached() {
    log_info "Menginstal Memcached..."

    # Instalasi Memcached
    check_and_install_package memcached
    check_and_install_package libmemcached-tools

    # Backup konfigurasi asli
    cp /etc/memcached.conf /etc/memcached.conf.backup

    # Konfigurasi Memcached untuk performa optimal
    log_info "Mengkonfigurasi Memcached..."
    sed -i 's/^-m .*/\-m 128/' /etc/memcached.conf
    sed -i 's/^-c .*/\-c 1024/' /etc/memcached.conf

    # Aktifkan dan restart Memcached
    systemctl enable memcached
    systemctl restart memcached

    if systemctl is-active --quiet memcached; then
        log_info "Memcached berhasil diinstal dan dikonfigurasi!"
    else
        log_error "Gagal mengaktifkan Memcached"
    fi
}

# Fungsi untuk security hardening
security_hardening() {
    log_info "Memulai security hardening..."

    echo "Pilih opsi security hardening:"
    echo "1. Implementasi fail2ban"
    echo "2. Konfigurasi automatic updates"
    echo "3. Pengamanan shared memory"
    echo "4. Pembatasan akses sistem"
    echo "5. Semua opsi di atas"
    read -p "Pilihan [1-5]: " security_choice

    case $security_choice in
        1) install_fail2ban ;;
        2) configure_auto_updates ;;
        3) secure_shared_memory ;;
        4) restrict_system_access ;;
        5) install_fail2ban
           configure_auto_updates
           secure_shared_memory
           restrict_system_access ;;
        *) log_error "Pilihan tidak valid"; return 1 ;;
    esac

    log_info "Security hardening selesai!"
}

# Fungsi untuk instalasi fail2ban
install_fail2ban() {
    log_info "Menginstal fail2ban..."

    # Instalasi fail2ban
    check_and_install_package fail2ban

    # Buat konfigurasi dasar
    cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
# Ban hosts for 1 hour
bantime = 3600
# Check for 10 minutes
findtime = 600
# Ban after 5 failures
maxretry = 5

# SSH protection
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3

# Web server protection
[nginx-http-auth]
enabled = true
filter = nginx-http-auth
port = http,https
logpath = /var/log/nginx/*error.log

# PHP-FPM protection
[php-url-fopen]
enabled = true
port = http,https
filter = php-url-fopen
logpath = /var/log/nginx/*access.log
EOF

    # Deteksi jika MySQL/MariaDB terinstall
    if command -v mysql > /dev/null; then
        cat >> /etc/fail2ban/jail.local << 'EOF'

# MySQL protection
[mysqld-auth]
enabled = true
filter = mysqld-auth
port = 3306
logpath = /var/log/mysql/error.log
maxretry = 5
EOF
    fi

    # Restart fail2ban
    systemctl enable fail2ban
    systemctl restart fail2ban

    if systemctl is-active --quiet fail2ban; then
        log_info "fail2ban berhasil diinstal dan dikonfigurasi!"
        log_info "Konfigurasi: /etc/fail2ban/jail.local"
    else
        log_error "Gagal mengaktifkan fail2ban"
    fi
}

# Fungsi untuk konfigurasi automatic updates
configure_auto_updates() {
    log_info "Mengkonfigurasi automatic updates..."

    # Instalasi unattended-upgrades
    check_and_install_package unattended-upgrades
    check_and_install_package apt-listchanges

    # Konfigurasi unattended-upgrades
    cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

    # Konfigurasi detail unattended-upgrades
    cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}";
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
    "${distro_id}:${distro_codename}-updates";
};

Unattended-Upgrade::Package-Blacklist {
};

Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::InstallOnShutdown "false";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF

    # Aktifkan unattended-upgrades
    systemctl enable unattended-upgrades
    systemctl restart unattended-upgrades

    if systemctl is-active --quiet unattended-upgrades; then
        log_info "Automatic updates berhasil dikonfigurasi!"
    else
        log_error "Gagal mengaktifkan automatic updates"
    fi
}

# Fungsi untuk pengamanan shared memory
secure_shared_memory() {
    log_info "Mengamankan shared memory..."

    # Backup fstab
    cp /etc/fstab /etc/fstab.backup

    # Cek apakah konfigurasi sudah ada
    if ! grep -q "tmpfs /dev/shm" /etc/fstab; then
        # Tambahkan konfigurasi ke fstab
        echo "tmpfs /dev/shm tmpfs defaults,noexec,nosuid,nodev 0 0" >> /etc/fstab

        # Terapkan konfigurasi
        mount -o remount /dev/shm

        log_info "Shared memory berhasil diamankan!"
    else
        log_info "Shared memory sudah dikonfigurasi dengan aman"
    fi
}

# Fungsi untuk pembatasan akses sistem
restrict_system_access() {
    log_info "Membatasi akses sistem..."

    # Konfigurasi SSH yang lebih aman
    log_info "Mengkonfigurasi SSH..."
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

    # Konfigurasi SSH yang lebih aman
    sed -i 's/^#PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config
    sed -i 's/^#PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/^PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/^#MaxAuthTries .*/MaxAuthTries 3/' /etc/ssh/sshd_config

    # Restart SSH
    systemctl restart sshd

    # Konfigurasi pembatasan akses sudo
    log_info "Mengkonfigurasi sudo..."
    cat > /etc/sudoers.d/secure << 'EOF'
Defaults        use_pty
Defaults        logfile="/var/log/sudo.log"
Defaults        log_input, log_output
EOF
    chmod 440 /etc/sudoers.d/secure

    log_info "Pembatasan akses sistem berhasil dikonfigurasi!"
    log_warning "PENTING: Pastikan Anda memiliki akses SSH dengan key authentication sebelum logout!"
}

# Fungsi untuk sistem backup
setup_backup_system() {
    log_info "Menyiapkan sistem backup..."

    # Instalasi paket yang diperlukan
    check_and_install_package rsync

    # Tanya lokasi backup
    read -p "Masukkan direktori untuk menyimpan backup [/backup]: " backup_dir
    backup_dir=${backup_dir:-/backup}

    # Buat direktori backup
    mkdir -p "${backup_dir}"
    mkdir -p "${backup_dir}/mysql"
    mkdir -p "${backup_dir}/websites"
    mkdir -p "${backup_dir}/config"

    # Buat script backup
    cat > /usr/local/bin/run-backups.sh << EOF
#!/bin/bash

# Script backup otomatis
# Dibuat oleh auto-vps8.2.sh

# Direktori backup
BACKUP_DIR="${backup_dir}"
DATE=\$(date +%Y-%m-%d)
MYSQL_BACKUP_DIR="\${BACKUP_DIR}/mysql"
WEBSITES_BACKUP_DIR="\${BACKUP_DIR}/websites"
CONFIG_BACKUP_DIR="\${BACKUP_DIR}/config"

# Log file
LOG_FILE="/var/log/backups.log"

# Fungsi logging
log_info() {
    echo "\$(date +"%Y-%m-%d %H:%M:%S") [INFO] \$1" >> \$LOG_FILE
    echo "\$(date +"%Y-%m-%d %H:%M:%S") [INFO] \$1"
}

log_error() {
    echo "\$(date +"%Y-%m-%d %H:%M:%S") [ERROR] \$1" >> \$LOG_FILE
    echo "\$(date +"%Y-%m-%d %H:%M:%S") [ERROR] \$1"
}

# Backup MySQL/MariaDB
if command -v mysql > /dev/null; then
    log_info "Memulai backup database MySQL/MariaDB..."

    # Buat direktori untuk backup hari ini
    mkdir -p "\${MYSQL_BACKUP_DIR}/\${DATE}"

    # Dapatkan daftar database
    databases=\$(mysql -e "SHOW DATABASES;" | grep -Ev "(Database|information_schema|performance_schema|mysql|sys)")

    # Backup setiap database
    for db in \$databases; do
        log_info "Backup database \$db"
        mysqldump --single-transaction --quick --lock-tables=false "\$db" | gzip > "\${MYSQL_BACKUP_DIR}/\${DATE}/\${db}.sql.gz"

        if [ \$? -eq 0 ]; then
            log_info "Backup database \$db berhasil"
        else
            log_error "Backup database \$db gagal"
        fi
    done

    log_info "Backup database selesai"
fi

# Backup website files
log_info "Memulai backup file website..."

# Buat direktori untuk backup hari ini
mkdir -p "\${WEBSITES_BACKUP_DIR}/\${DATE}"

# Backup direktori /var/www
rsync -a --delete /var/www/ "\${WEBSITES_BACKUP_DIR}/\${DATE}/"

if [ \$? -eq 0 ]; then
    log_info "Backup file website berhasil"
else
    log_error "Backup file website gagal"
fi

# Backup konfigurasi Nginx
if [ -d "/etc/nginx" ]; then
    log_info "Memulai backup konfigurasi Nginx..."

    # Buat direktori untuk backup hari ini
    mkdir -p "\${CONFIG_BACKUP_DIR}/\${DATE}/nginx"

    # Backup direktori konfigurasi Nginx
    rsync -a --delete /etc/nginx/ "\${CONFIG_BACKUP_DIR}/\${DATE}/nginx/"

    if [ \$? -eq 0 ]; then
        log_info "Backup konfigurasi Nginx berhasil"
    else
        log_error "Backup konfigurasi Nginx gagal"
    fi
fi

# Backup konfigurasi PHP
if [ -d "/etc/php" ]; then
    log_info "Memulai backup konfigurasi PHP..."

    # Buat direktori untuk backup hari ini
    mkdir -p "\${CONFIG_BACKUP_DIR}/\${DATE}/php"

    # Backup direktori konfigurasi PHP
    rsync -a --delete /etc/php/ "\${CONFIG_BACKUP_DIR}/\${DATE}/php/"

    if [ \$? -eq 0 ]; then
        log_info "Backup konfigurasi PHP berhasil"
    else
        log_error "Backup konfigurasi PHP gagal"
    fi
fi

# Rotasi backup (hapus backup yang lebih dari 7 hari)
log_info "Melakukan rotasi backup..."

# Rotasi backup MySQL
find "\${MYSQL_BACKUP_DIR}" -type d -name "20*" -mtime +7 -exec rm -rf {} \;

# Rotasi backup website
find "\${WEBSITES_BACKUP_DIR}" -type d -name "20*" -mtime +7 -exec rm -rf {} \;

# Rotasi backup konfigurasi
find "\${CONFIG_BACKUP_DIR}" -type d -name "20*" -mtime +7 -exec rm -rf {} \;

log_info "Rotasi backup selesai"
log_info "Proses backup selesai"
EOF

    # Buat executable
    chmod +x /usr/local/bin/run-backups.sh

    # Buat cron job untuk menjalankan backup setiap hari pada jam 2 pagi
    echo "0 2 * * * root /usr/local/bin/run-backups.sh" > /etc/cron.d/daily-backups
    chmod 644 /etc/cron.d/daily-backups

    log_info "Sistem backup berhasil dikonfigurasi!"
    log_info "Backup akan dijalankan setiap hari pada jam 2 pagi"
    log_info "Lokasi backup: ${backup_dir}"
    log_info "Log backup: /var/log/backups.log"
    log_info "Untuk menjalankan backup manual: sudo /usr/local/bin/run-backups.sh"
}

# Fungsi untuk menampilkan sistem info
show_system_info() {
    log_info "=== Informasi Sistem ==="
    echo "OS: $(lsb_release -ds)"
    echo "Kernel: $(uname -r)"
    echo "CPU: $(grep "model name" /proc/cpuinfo | head -n1 | cut -d: -f2)"
    echo "RAM: $(free -h | awk '/^Mem:/ {print $2}')"
    echo "Disk: $(df -h / | awk 'NR==2 {print $2}')"

    if command -v php > /dev/null; then
        echo "PHP Version: $(php -v | head -n1)"
    fi

    if command -v mysql > /dev/null; then
        echo "MySQL Version: $(mysql --version)"
    fi

    if command -v nginx > /dev/null; then
        echo "Nginx Version: $(nginx -v 2>&1)"
    elif command -v apache2 > /dev/null; then
        echo "Apache Version: $(apache2 -v | head -n1)"
    fi

    if command -v node > /dev/null; then
        echo "Node.js Version: $(node -v)"
        echo "NPM Version: $(npm -v)"
    fi

    # Tampilkan informasi tambahan
    echo
    echo "=== Layanan Aktif ==="
    if systemctl is-active --quiet redis-server; then
        echo "Redis: Aktif"
    fi

    if systemctl is-active --quiet memcached; then
        echo "Memcached: Aktif"
    fi

    if systemctl is-active --quiet fail2ban; then
        echo "Fail2ban: Aktif"
    fi

    if systemctl is-active --quiet unattended-upgrades; then
        echo "Automatic Updates: Aktif"
    fi

    # Cek apakah backup sudah dikonfigurasi
    if [ -f "/usr/local/bin/run-backups.sh" ]; then
        echo "Sistem Backup: Terkonfigurasi"
    fi
}

# Modifikasi menu utama dengan menambahkan opsi baru
while true; do
    clear
    echo "=============================="
    echo "     Auto Setup VPS Menu     "
    echo "=============================="
    echo "--- Instalasi Dasar ---"
    echo "1. Install PHP"
    echo "2. Install Nginx"
    echo "3. Install Database"
    echo "4. Install phpMyAdmin"
    echo "5. Install Node.js & npm"
    echo "6. Install FrankenPHP"
    echo "7. Konfigurasi Aplikasi Web"
    echo "8. Konfigurasi PHP"
    echo
    echo "--- Optimasi & Keamanan ---"
    echo "9. Optimasi Server"
    echo "10. Instalasi Sistem Cache"
    echo "11. Security Hardening"
    echo "12. Sistem Backup"
    echo
    echo "--- Utilitas ---"
    echo "13. Tampilkan Informasi Sistem"
    echo "14. Ganti User Root MySQL"
    echo "0. Keluar"
    echo "=============================="
    read -p "Pilihan [0-14]: " choice

    case $choice in
        1) install_php ;;
        2) install_webserver ;;
        3) install_database ;;
        4) install_phpmyadmin ;;
        5) install_nodejs ;;
        6) install_frankenphp ;;
        7) configure_webapp ;;
        8) configure_php ;;
        9) optimize_server ;;
        10) install_cache_system ;;
        11) security_hardening ;;
        12) setup_backup_system ;;
        13) show_system_info ;;
        14) mysql_change_root ;;
        0) log_info "Terima kasih telah menggunakan script ini!"
           exit 0 ;;
        *) log_error "Pilihan tidak valid" ;;
    esac

    echo
    read -p "Tekan Enter untuk melanjutkan..."
done
