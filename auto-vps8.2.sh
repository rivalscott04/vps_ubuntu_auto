#!/bin/bash

# Pastikan script dijalankan sebagai root
if [ "$(id -u)" -ne 0 ]; then
    echo "Script ini harus dijalankan sebagai root. Gunakan sudo."
    exit 1
fi

# Fungsi untuk memastikan package tambahan tersedia
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

# Fungsi untuk menambahkan PPA Web Server sesuai pilihan
add_webserver_ppa() {
    echo "Menambahkan repository tambahan untuk web server..."

    if dpkg -l | grep -q "apache2"; then
        add-apt-repository -y ppa:ondrej/apache2
        echo "✅ PPA Apache berhasil ditambahkan."
    elif dpkg -l | grep -q "nginx"; then
        echo "Pilih versi Nginx yang akan diinstall:"
        echo "1. Nginx Mainline (ppa:ondrej/nginx-mainline)"
        echo "2. Nginx Stable (ppa:ondrej/nginx)"
        read -p "Pilihan [1-2]: " nginx_choice

        case $nginx_choice in
            1) add-apt-repository -y ppa:ondrej/nginx-mainline ;;
            2) add-apt-repository -y ppa:ondrej/nginx ;;
            *) echo "Pilihan tidak valid, menggunakan default (Stable)."
               add-apt-repository -y ppa:ondrej/nginx ;;
        esac
        echo "✅ PPA Nginx berhasil ditambahkan."
    fi

    apt update && apt upgrade -y
}

# Fungsi menambahkan repository PHP Ondřej Surý
add_php_repository() {
    echo "Menambahkan repository PHP Ondřej Surý..."
    apt install -y software-properties-common
    add-apt-repository -y ppa:ondrej/php 2>/dev/null

    if ! grep -q "ondrej/php" /etc/apt/sources.list.d/*.list 2>/dev/null; then
        echo "❌ Gagal menambahkan repository PHP dari PPA Ondřej Surý!"
        exit 1
    fi
    echo "✅ Repository PHP berhasil ditambahkan!"
}

# Fungsi untuk menginstal PHP
install_php() {
    add_php_repository
    add_webserver_ppa
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

    if [ $? -eq 0 ]; then
        echo "✅ PHP ${php_version} berhasil diinstall!"
    else
        echo "❌ Gagal menginstall PHP ${php_version}!"
    fi
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
    read -p "Masukkan alias untuk phpMyAdmin (contoh: _pma): " pma_alias
    read -p "Web server yang digunakan (apache/nginx): " web_server

    # Path phpMyAdmin
    pma_path="/var/www/${pma_alias}"
    mkdir -p ${pma_path}

    # Download phpMyAdmin
    wget -qO /tmp/phpmyadmin.zip https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.zip
    unzip /tmp/phpmyadmin.zip -d /tmp/
    mv /tmp/phpMyAdmin-*-all-languages/* ${pma_path}/
    rm -rf /tmp/phpmyadmin.zip /tmp/phpMyAdmin-*-all-languages

    if [ "$web_server" = "nginx" ]; then
        # Konfigurasi Nginx
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
        # Konfigurasi Apache
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

    <Directory /var/www/html>
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

# Menu utama
while true; do
    echo "=== Auto Setup VPS Menu ==="
    echo "1. Install PHP (8.1-8.3)"
    echo "2. Install Web Server (Apache/Nginx)"
    echo "3. Install Node.js & npm"
    echo "4. Install Database (MySQL/PostgreSQL)"
    echo "5. Install phpMyAdmin"
    echo "6. Install FrankenPHP"
    echo "7. Konfigurasi Aplikasi Web"
    echo "8. Keluar"
    read -p "Pilihan [1-8]: " choice

    case $choice in
        1) install_php ;;
        2) install_webserver ;;
        3) echo "🚀 Installasi Node.js belum tersedia!" ;;
        4) install_database ;;
        5) install_phpmyadmin ;;
        6) echo "🚀 Installasi FrankenPHP belum tersedia!" ;;
        7) configure_webapp ;;
        8) echo "Terima kasih!"; exit 0 ;;
        *) echo "Pilihan tidak valid" ;;
    esac

    read -p "Tekan Enter untuk melanjutkan..."
done
