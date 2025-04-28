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

    # Input dari user
    read -p "Masukkan domain utama (contoh: domain.com): " domain_name
    read -p "Masukkan nama folder untuk phpMyAdmin [pma]: " pma_folder
    pma_folder=${pma_folder:-pma}  # Default ke 'pma' jika input kosong

    # Set path instalasi
    pma_path="/var/www/html/${domain_name}/${pma_folder}"

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

    # Cek apakah konfigurasi nginx untuk domain utama sudah ada
    nginx_conf="/etc/nginx/sites-available/${domain_name}"
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
    error_log /var/log/nginx/${domain_name}_error.log;
    access_log /var/log/nginx/${domain_name}_access.log combined;
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

    # Set permissions
    chown -R www-data:www-data "$pma_path"
    find "$pma_path" -type d -exec chmod 755 {} \;
    find "$pma_path" -type f -exec chmod 644 {} \;

    # Bersihkan file temporary
    rm -rf /tmp/phpmyadmin.tar.gz
    rm -rf /tmp/phpMyAdmin-*-all-languages

    # Aktifkan konfigurasi jika belum
    if [ ! -f "/etc/nginx/sites-enabled/${domain_name}" ]; then
        ln -sf "$nginx_conf" "/etc/nginx/sites-enabled/"
    fi

    # Test konfigurasi Nginx dan restart
    if nginx -t; then
        systemctl restart nginx
        log_info "Instalasi phpMyAdmin selesai!"
        log_info "Akses phpMyAdmin di: http://${domain_name}/${pma_folder}"

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
        echo "5. Pertimbangkan untuk mengubah nama folder phpMyAdmin dari '${pma_folder}'"
    else
        log_error "Konfigurasi Nginx tidak valid"
        exit 1
    fi
}
# Fungsi 5: Instalasi Node.js & npm
install_nodejs() {
    log_info "Mempersiapkan instalasi Node.js..."
    check_and_install_package curl

    # Tambahkan repository Node.js
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - > /dev/null 2>&1

    log_info "Menginstal Node.js dan npm..."
    apt install -y nodejs > /dev/null 2>&1

    # Update npm ke versi terbaru
    npm install -g npm@latest > /dev/null 2>&1

    # Install beberapa package global yang umum digunakan
    log_info "Menginstal package global..."
    npm install -g pm2 yarn > /dev/null 2>&1

    if command -v node > /dev/null; then
        node_version=$(node -v)
        npm_version=$(npm -v)
        log_info "Node.js ${node_version} dan npm ${npm_version} berhasil diinstall!"
    else
        log_error "Gagal menginstal Node.js"
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
    echo "1. PHP (Laravel/PHP Native)"
    echo "2. JavaScript (Node.js/React/Vue/dll)"
    read -p "Pilihan [1-2]: " stack_choice

    case $stack_choice in
        1) stack_type="php" ;;
        2) stack_type="js" ;;
        *) log_error "Pilihan tidak valid, menggunakan default (PHP)"; stack_type="php" ;;
    esac

    # Tanya path aplikasi dan domain
    read -p "Masukkan path aplikasi (contoh: /var/www/html/namaaplikasi): " app_path

    # Validasi input path
    if [ -z "$app_path" ]; then
        log_error "Path aplikasi tidak boleh kosong"
        return 1
    fi

    # Tanya domain
    read -p "Masukkan domain (contoh: domain.com): " domain_name

    # Validasi input domain
    if [ -z "$domain_name" ]; then
        log_error "Domain tidak boleh kosong"
        return 1
    fi

    # Konfigurasi berdasarkan stack yang dipilih
    if [ "$stack_type" = "php" ]; then
        # Tanya apakah menggunakan Laravel
        read -p "Apakah menggunakan Laravel? (y/n): " use_laravel

        # Sesuaikan path untuk Laravel
        if [ "$use_laravel" = "y" ]; then
            # Laravel menggunakan /public sebagai document root
            full_path="$app_path"
            app_path="${app_path}/public"
            log_info "Laravel terdeteksi, root diatur ke: $app_path"
        else
            full_path="$app_path"
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

        # Tanya apakah menggunakan proxy untuk Node.js
        read -p "Apakah aplikasi berjalan sebagai service Node.js? (y/n): " use_nodejs_service

        if [ "$use_nodejs_service" = "y" ]; then
            read -p "Port aplikasi Node.js (default: 3000): " nodejs_port
            nodejs_port=${nodejs_port:-3000}
            log_info "Konfigurasi proxy untuk Node.js pada port ${nodejs_port}"
        fi
    fi

    read -p "Apakah menggunakan SSL/HTTPS via Cloudflare? (y/n): " use_ssl

    # Buat direktori jika belum ada
    mkdir -p "$full_path"
    chown -R www-data:www-data "$full_path"
    chmod -R 755 "$full_path"

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
            # Konfigurasi untuk static files (SPA)
            cat >> "/etc/nginx/sites-available/${domain_name}" << 'EOF'

    root APPPATH;
    index index.html index.htm;

    location / {
        try_files $uri $uri/ /index.html;
    }

    # Cache static assets
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg)$ {
        expires 30d;
        add_header Cache-Control "public, no-transform";
    }
EOF
        fi
    fi

    # Close server block
    cat >> "/etc/nginx/sites-available/${domain_name}" << 'EOF'

    # Logging
    error_log /var/log/nginx/${domain_name}_error.log;
    access_log /var/log/nginx/${domain_name}_access.log combined;
}
EOF

    # Replace placeholders
    sed -i "s/DOMAIN/${domain_name}/g" "/etc/nginx/sites-available/${domain_name}"
    sed -i "s|APPPATH|${app_path}|g" "/etc/nginx/sites-available/${domain_name}"

    if [ "$stack_type" = "php" ]; then
        sed -i "s/PHPVER/${selected_php_version}/g" "/etc/nginx/sites-available/${domain_name}"
    elif [ "$use_nodejs_service" = "y" ]; then
        sed -i "s/NODEJS_PORT/${nodejs_port}/g" "/etc/nginx/sites-available/${domain_name}"
    fi

    # Create symlink and test config
    ln -sf "/etc/nginx/sites-available/${domain_name}" "/etc/nginx/sites-enabled/"

    # Test and reload nginx
    if nginx -t; then
        systemctl restart nginx
        log_info "Konfigurasi aplikasi web selesai!"
        log_info "Domain: ${domain_name}"
        log_info "Path aplikasi: ${app_path}"

        if [ "$stack_type" = "php" ]; then
            log_info "Stack: PHP"
            if [ "$use_laravel" = "y" ]; then
                log_info "Framework: Laravel"
            fi
        else
            log_info "Stack: JavaScript"
            if [ "$use_nodejs_service" = "y" ]; then
                log_info "Node.js service pada port: ${nodejs_port}"
            fi
        fi

        if [ "$use_ssl" = "y" ]; then
            log_info "SSL/HTTPS via Cloudflare telah dikonfigurasi"
        fi
    else
        log_error "Konfigurasi Nginx tidak valid, silakan periksa kembali"
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
}

# Modifikasi menu utama dengan menambahkan opsi baru
while true; do
    clear
    echo "=============================="
    echo "     Auto Setup VPS Menu     "
    echo "=============================="
    echo "1. Install PHP"
    echo "2. Install Nginx"
    echo "3. Install Database"
    echo "4. Install phpMyAdmin"
    echo "5. Install Node.js & npm"
    echo "6. Install FrankenPHP"
    echo "7. Konfigurasi Aplikasi Web"
    echo "8. Konfigurasi PHP"
    echo "9. Tampilkan Informasi Sistem"
    echo "10. Ganti User Root MySQL"
    echo "0. Keluar"
    echo "=============================="
    read -p "Pilihan [0-10]: " choice

    case $choice in
        1) install_php ;;
        2) install_webserver ;;
        3) install_database ;;
        4) install_phpmyadmin ;;
        5) install_nodejs ;;
        6) install_frankenphp ;;
        7) configure_webapp ;;
        8) configure_php ;;
        9) show_system_info ;;
        10) mysql_change_root ;;
        0) log_info "Terima kasih telah menggunakan script ini!"
           exit 0 ;;
        *) log_error "Pilihan tidak valid" ;;
    esac

    echo
    read -p "Tekan Enter untuk melanjutkan..."
done
