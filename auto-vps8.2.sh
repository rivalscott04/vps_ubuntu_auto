#!/bin/bash

# Pastikan script dijalankan sebagai root
if [ "$(id -u)" -ne 0 ]; then
    echo "Script ini harus dijalankan sebagai root. Gunakan sudo."
    exit 1
fi

# Fungsi untuk memastikan paket tertentu sudah terinstal
check_and_install_package() {
    if ! dpkg -l | grep -q "^ii  $1 "; then
        echo "Paket $1 belum terinstal. Apakah Anda ingin menginstalnya? (y/n)"
        read -p "Jawaban: " answer
        if [ "$answer" == "y" ]; then
            apt update && apt upgrade -y
            apt install -y $1
        else
            echo "Paket $1 diperlukan untuk menjalankan fitur ini."
            exit 1
        fi
    fi
}

# Fungsi untuk menambahkan PPA hanya jika belum ada
add_ppa_if_needed() {
    local ppa_name=$1
    local ppa_list="/etc/apt/sources.list.d/${ppa_name}*.list"

    if ls $ppa_list 1> /dev/null 2>&1; then
        echo "✅ PPA $ppa_name sudah ditambahkan, tidak perlu menambahkan ulang."
    else
        echo "🔄 Menambahkan PPA $ppa_name..."
        add-apt-repository -y ppa:$ppa_name
        apt update && apt upgrade -y
    fi
}

# Fungsi untuk menambahkan PPA Web Server
add_webserver_ppa() {
    echo "🔧 Menyesuaikan PPA untuk Web Server..."

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
            *) echo "Pilihan tidak valid, menggunakan default (Stable)."
               add_ppa_if_needed "ondrej/nginx" ;;
        esac
    fi
}

# Fungsi untuk menambahkan PPA PHP
add_php_repository() {
    echo "🔧 Menyesuaikan PPA untuk PHP..."
    add_ppa_if_needed "ondrej/php"
}

# Fungsi untuk menginstal PHP
install_php() {
    add_webserver_ppa
    add_php_repository

    apt update

    echo "Pilih versi PHP yang akan diinstall:"
    echo "1. PHP 8.1"
    echo "2. PHP 8.2"
    echo "3. PHP 8.3"
    read -p "Pilihan [1-3]: " php_choice

    case $php_choice in
        1) php_version="8.1" ;;
        2) php_version="8.2" ;;
        3) php_version="8.3" ;;
        *) echo "Pilihan tidak valid"; return ;;
    esac

    apt install -y php${php_version} php${php_version}-fpm php${php_version}-cli \
                   php${php_version}-common php${php_version}-mysql php${php_version}-zip \
                   php${php_version}-gd php${php_version}-mbstring php${php_version}-curl \
                   php${php_version}-xml php${php_version}-bcmath php${php_version}-pgsql \
                   php${php_version}-intl php${php_version}-readline php${php_version}-ldap \
                   php${php_version}-msgpack php${php_version}-igbinary php${php_version}-redis

    echo "✅ PHP ${php_version} berhasil diinstall!"
}

# Fungsi untuk menginstal Web Server
install_webserver() {
    echo "Pilih web server yang akan diinstall:"
    echo "1. Apache"
    echo "2. Nginx"
    read -p "Pilihan [1-2]: " server_choice

    case $server_choice in
        1) apt install -y apache2
           add_webserver_ppa
           a2enmod rewrite
           systemctl restart apache2
           echo "✅ Apache terinstall!"
           ;;
        2) apt install -y nginx
           add_webserver_ppa
           systemctl restart nginx
           echo "✅ Nginx terinstall!"
           ;;
        *) echo "Pilihan tidak valid" ;;
    esac
}

# Fungsi untuk menginstal Database
install_database() {
    echo "Pilih database yang akan diinstall:"
    echo "1. MySQL"
    echo "2. PostgreSQL"
    read -p "Pilihan [1-2]: " db_choice

    case $db_choice in
        1) apt install -y mysql-server
           mysql_secure_installation
           echo "✅ MySQL berhasil diinstall!"
           ;;
        2) apt install -y postgresql postgresql-contrib
           echo "✅ PostgreSQL berhasil diinstall!"
           ;;
        *) echo "Pilihan tidak valid" ;;
    esac
}

# Fungsi untuk menginstal phpMyAdmin
install_phpmyadmin() {
    check_and_install_package unzip
    check_and_install_package wget

    read -p "Masukkan domain untuk phpMyAdmin (contoh: a.domain.com): " domain_name
    read -p "Masukkan alias untuk phpMyAdmin (contoh: pma): " pma_alias
    read -p "Web server yang digunakan (apache/nginx): " web_server

    pma_path="/var/www/${pma_alias}"
    mkdir -p ${pma_path}

    wget -qO /tmp/phpmyadmin.zip https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.zip
    unzip /tmp/phpmyadmin.zip -d /tmp/
    mv /tmp/phpMyAdmin-*-all-languages/* ${pma_path}/
    rm -rf /tmp/phpmyadmin.zip /tmp/phpMyAdmin-*-all-languages

    if [ "$web_server" = "nginx" ]; then
        cat > /etc/nginx/sites-available/${domain_name} <<EOL
server {
    listen 80;
    server_name ${domain_name};

    root /var/www/html;
    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location /${pma_alias} {
        alias ${pma_path};
        index index.php index.html index.htm;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOL
        ln -s /etc/nginx/sites-available/${domain_name} /etc/nginx/sites-enabled/
        systemctl restart nginx

    elif [ "$web_server" = "apache" ]; then
        cat > /etc/apache2/sites-available/${domain_name}.conf <<EOL
<VirtualHost *:80>
    ServerName ${domain_name}
    DocumentRoot /var/www/html

    Alias /${pma_alias} ${pma_path}

    <Directory ${pma_path}>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/${domain_name}_error.log
    CustomLog \${APACHE_LOG_DIR}/${domain_name}_access.log combined
</VirtualHost>
EOL
        a2ensite ${domain_name}
        systemctl restart apache2
    fi

    echo "✅ phpMyAdmin berhasil diinstall dan dapat diakses di http://${domain_name}/${pma_alias}!"
}

# Fungsi untuk menginstal Node.js & npm
install_nodejs() {
    check_and_install_package curl
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
    apt update && apt install -y nodejs
    npm install -g npm@latest
    echo "✅ Node.js dan npm berhasil diinstall!"
}

# Fungsi untuk menginstal FrankenPHP
install_frankenphp() {
    check_and_install_package curl
    curl -sSL https://deb.frankenphp.dev/frankenphp.asc | gpg --dearmor -o /usr/share/keyrings/frankenphp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/frankenphp-archive-keyring.gpg] https://deb.frankenphp.dev jammy main" | tee /etc/apt/sources.list.d/frankenphp.list
    apt update && check_and_install_package frankenphp
    echo "✅ FrankenPHP berhasil diinstall!"
}

# Fungsi untuk konfigurasi aplikasi web
configure_webapp() {
    read -p "Masukkan domain aplikasi web: " domain_name
    read -p "Masukkan path aplikasi (contoh: /var/www/myapp): " app_path
    read -p "Web server yang digunakan (apache/nginx): " web_server

    mkdir -p $app_path

    if [ "$web_server" = "nginx" ]; then
        ln -s /etc/nginx/sites-available/$domain_name /etc/nginx/sites-enabled/
        systemctl restart nginx

    elif [ "$web_server" = "apache" ]; then
        a2ensite $domain_name
        systemctl restart apache2
    fi

    echo "✅ Konfigurasi aplikasi web selesai!"
}


# Fungsi untuk mengonfigurasi PHP
configure_php() {
    if ! command -v php &> /dev/null; then
        echo "❌ PHP belum diinstall! Silakan install PHP terlebih dahulu."
        return
    fi

    php_version=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
    php_ini_file="/etc/php/${php_version}/fpm/php.ini"

    if [ ! -f "$php_ini_file" ]; then
        echo "❌ File php.ini tidak ditemukan di $php_ini_file"
        return
    fi

    echo "🔧 Konfigurasi PHP ($php_ini_file)"

    sed -i "s/^memory_limit = .*/memory_limit = 256M/" $php_ini_file
    sed -i "s/^upload_max_filesize = .*/upload_max_filesize = 50M/" $php_ini_file
    sed -i "s/^post_max_size = .*/post_max_size = 50M/" $php_ini_file
    sed -i "s/^display_errors = .*/display_errors = On/" $php_ini_file
    sed -i "s/^error_reporting = .*/error_reporting = E_ALL/" $php_ini_file
    sed -i "s|^;date.timezone =.*|date.timezone = Europe/Paris|" $php_ini_file

    systemctl restart php${php_version}-fpm
    echo "✅ Konfigurasi PHP berhasil diperbarui!"
}

# Menu utama
while true; do
    echo "=== Auto Setup VPS Menu ==="
    echo "1. Install PHP"
    echo "2. Install Web Server"
    echo "3. Install Database"
    echo "4. Install phpMyAdmin"
    echo "5. Install Node.js & npm (BELUM TERSEDIA)"
    echo "6. Install FrankenPHP (BELUM TERSEDIA)"
    echo "7. Konfigurasi Aplikasi Web (BELUM TERSEDIA)"
    echo "8. Konfigurasi PHP"
    echo "9. Keluar"
    read -p "Pilihan [1-9]: " choice

    case $choice in
        1) install_php ;;
        2) install_webserver ;;
        3) install_database ;;
        4) echo "🚀 Installasi phpMyAdmin belum tersedia!" ;;
        5) echo "🚀 Installasi Node.js belum tersedia!" ;;
        6) echo "🚀 Installasi FrankenPHP belum tersedia!" ;;
        7) echo "🚀 Konfigurasi Aplikasi Web belum tersedia!" ;;
        8) configure_php ;;
        9) echo "Terima kasih!"; exit 0 ;;
        *) echo "Pilihan tidak valid" ;;
    esac

    read -p "Tekan Enter untuk melanjutkan..."
done
