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
    echo "Pilih web server yang akan diinstall:"
    echo "1. Apache"
    echo "2. Nginx"
    read -p "Pilihan [1-2]: " server_choice

    case $server_choice in
        1) log_info "Menginstal Apache2..."
           # Tambah PPA dulu sebelum install
           add_ppa_if_needed "ondrej/apache2"
           apt install -y apache2 > /dev/null 2>&1
           a2enmod rewrite > /dev/null 2>&1
           a2enmod ssl > /dev/null 2>&1
           a2enmod headers > /dev/null 2>&1
           systemctl restart apache2
           log_info "Apache2 berhasil diinstall!"
           ;;
        2) log_info "Menginstal Nginx..."
           # Tambah PPA dulu sebelum install
           add_ppa_if_needed "ondrej/nginx"
           apt install -y nginx > /dev/null 2>&1
           systemctl restart nginx
           log_info "Nginx berhasil diinstall!"
           ;;
        *) log_error "Pilihan tidak valid" ;;
    esac
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
    check_and_install_package unzip
    check_and_install_package wget

    read -p "Masukkan domain untuk phpMyAdmin (contoh: pma.domain.com): " domain_name
    read -p "Masukkan alias untuk phpMyAdmin (contoh: pma): " pma_alias
    read -p "Web server yang digunakan (apache/nginx): " web_server

    pma_path="/var/www/${pma_alias}"
    # Mengubah path ke /var/www/html
    pma_path="/var/www/html/${pma_alias}"
    mkdir -p "${pma_path}"

    log_info "Mengunduh phpMyAdmin..."
    
    real_ip_header CF-Connecting-IP;
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Content-Type-Options "nosniff";
    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }
        fastcgi_pass unix:/var/run/php/php${selected_php_version}-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
        # Security for phpMyAdmin
        fastcgi_intercept_errors on;
        fastcgi_read_timeout 300;
    }
    location ~ /\.ht {
        deny all;
    }
    
    # Deny access to specific phpMyAdmin files
    location ~ ^/(README|COPYING|LICENSE|RELEASE-DATE-|CHANGE|INSTALL|CONFIG|setup)$ {
        deny all;
    }
}
EOL
        # Buat symlink jika belum ada
        if [ -f "/etc/nginx/sites-available/${domain_name}" ]; then
            ln -sf "/etc/nginx/sites-available/${domain_name}" "/etc/nginx/sites-enabled/"
            # Test konfigurasi nginx sebelum restart
            if nginx -t; then
                systemctl restart nginx
                log_info "Konfigurasi Nginx berhasil diterapkan"
            else
                log_error "Konfigurasi Nginx tidak valid"
                return 1
            fi
        # Hapus symlink yang mungkin sudah ada
        rm -f "/etc/nginx/sites-enabled/${domain_name}"
        
        # Buat symlink baru
        ln -sf "/etc/nginx/sites-available/${domain_name}" "/etc/nginx/sites-enabled/"
        
        # Test konfigurasi nginx sebelum restart
        if nginx -t; then
            systemctl restart nginx
            log_info "Konfigurasi Nginx berhasil diterapkan"
        else
            log_error "File konfigurasi Nginx tidak berhasil dibuat"
            log_error "Konfigurasi Nginx tidak valid"
            return 1
        fi

@@ -312,15 +326,44 @@
        Options FollowSymLinks
        AllowOverride All
        Require all granted
        
        # Additional security for phpMyAdmin
        <IfModule mod_php.c>
            php_admin_value upload_max_filesize 64M
            php_admin_value max_execution_time 300
            php_admin_value max_input_time 300
            php_admin_value memory_limit 256M
            php_admin_value post_max_size 64M
        </IfModule>
    </Directory>
    # Security headers
    Header set X-Frame-Options "SAMEORIGIN"
    Header set X-XSS-Protection "1; mode=block"
    Header set X-Content-Type-Options "nosniff"
    ErrorLog \${APACHE_LOG_DIR}/${domain_name}_error.log
    CustomLog \${APACHE_LOG_DIR}/${domain_name}_access.log combined
</VirtualHost>
EOL

        # Aktifkan modul headers jika belum aktif
        a2enmod headers > /dev/null 2>&1
        
        # Hapus konfigurasi lama jika ada
        a2dissite "${domain_name}" > /dev/null 2>&1
        
        # Aktifkan konfigurasi baru
        a2ensite "${domain_name}" > /dev/null 2>&1
        systemctl restart apache2
        
        # Test konfigurasi Apache sebelum restart
        if apache2ctl configtest; then
            systemctl restart apache2
            log_info "Konfigurasi Apache berhasil diterapkan"
        else
            log_error "Konfigurasi Apache tidak valid"
            return 1
        fi
    else
        log_error "Web server tidak valid"
        return 1
@@ -333,341 +376,342 @@
    log_info "phpMyAdmin berhasil diinstall!"
    log_info "Akses phpMyAdmin di: http://${domain_name}"
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

# Fungsi 7: Konfigurasi Aplikasi Web
configure_webapp() {
    read -p "Masukkan domain aplikasi web: " domain_name
    read -p "Masukkan path aplikasi (contoh: /var/www/myapp): " app_path
    read -p "Web server yang digunakan (apache/nginx): " web_server
    read -p "Apakah menggunakan PHP? (y/n): " use_php
    read -p "Apakah menggunakan SSL/HTTPS? (y/n): " use_ssl

    mkdir -p "$app_path"
    chown -R www-data:www-data "$app_path"
    chmod -R 755 "$app_path"

    case "$web_server" in
        nginx)
            log_info "Membuat konfigurasi Nginx..."

            nginx_conf="server {
    listen 80;
    listen [::]:80;
    server_name ${domain_name};
    # Redirect HTTP to HTTPS if not coming from Cloudflare
    if (\$http_cf_visitor !~ '{\"scheme\":\"https\"}') {
        return 301 https://\$server_name\$request_uri;
    }
    root ${app_path};
    index index.html index.htm$([ "$use_php" = "y" ] && echo " index.php");
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
        try_files \$uri \$uri/ /index.php?\$args;
    }"

            if [ "$use_php" = "y" ]; then
                nginx_conf="${nginx_conf}
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php${selected_php_version}-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }"
            fi

            nginx_conf="${nginx_conf}
    location ~ /\.ht {
        deny all;
    }
}"

            echo "$nginx_conf" > "/etc/nginx/sites-available/$domain_name"
            ln -sf "/etc/nginx/sites-available/$domain_name" "/etc/nginx/sites-enabled/"
            nginx -t && systemctl restart nginx
            ;;

        apache)
            log_info "Membuat konfigurasi Apache..."

            apache_conf="<VirtualHost *:80>
    ServerName ${domain_name}
    DocumentRoot ${app_path}
    <Directory ${app_path}>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog \${APACHE_LOG_DIR}/${domain_name}_error.log
    CustomLog \${APACHE_LOG_DIR}/${domain_name}_access.log combined
</VirtualHost>"

            echo "$apache_conf" > "/etc/apache2/sites-available/${domain_name}.conf"
            a2ensite "${domain_name}"
            apache2ctl configtest && systemctl restart apache2
            ;;

        *)
            log_error "Web server tidak valid. Pilih 'apache' atau 'nginx'"
            return
            ;;
    esac

    log_info "Konfigurasi aplikasi web selesai!"
    if [ "$use_ssl" = "y" ]; then
        log_info "SSL telah dikonfigurasi untuk $domain_name"
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
    echo "2. Install Web Server"
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
