#!/bin/bash

# Check if script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Script ini harus dijalankan sebagai root. Gunakan sudo."
    exit 1
fi

# Function to display menu
show_menu() {
    clear
    echo "=== Auto Setup VPS Menu ==="
    echo "1. Install PHP (8.1-8.3)"
    echo "2. Install Web Server (Apache/Nginx)"
    echo "3. Install Node.js & npm"
    echo "4. Install FrankenPHP"
    echo "5. Konfigurasi Aplikasi Web"
    echo "6. Install Database (MySQL/PostgreSQL)"
    echo "7. Install phpMyAdmin"
    echo "8. Keluar"
}

# Function to install PHP
install_php() {
    echo "Pilih versi PHP yang akan diinstall:"
    echo "1. PHP 8.1"
    echo "2. PHP 8.2"
    echo "3. PHP 8.3"
    read -p "Pilihan [1-3]: " php_choice

    # Add PHP repository
    apt install -y software-properties-common
    add-apt-repository -y ppa:ondrej/php
    apt update

    case $php_choice in
        1) php_version="8.1" ;;
        2) php_version="8.2" ;;
        3) php_version="8.3" ;;
        *) echo "Pilihan tidak valid"; return ;;
    esac

    # Install PHP and extensions needed for Laravel
    apt install -y php${php_version} php${php_version}-fpm php${php_version}-cli \
        php${php_version}-common php${php_version}-mysql php${php_version}-zip \
        php${php_version}-gd php${php_version}-mbstring php${php_version}-curl \
        php${php_version}-xml php${php_version}-bcmath php${php_version}-pgsql \
        php${php_version}-intl php${php_version}-readline php${php_version}-ldap \
        php${php_version}-msgpack php${php_version}-igbinary php${php_version}-redis

    echo "PHP ${php_version} terinstall!"
}

# Function to install web server
install_webserver() {
    echo "Pilih web server yang akan diinstall:"
    echo "1. Apache"
    echo "2. Nginx"
    read -p "Pilihan [1-2]: " server_choice

    case $server_choice in
        1)
            apt install -y apache2
            a2enmod rewrite
            systemctl restart apache2
            echo "Apache terinstall!"
            ;;
        2)
            apt install -y nginx
            systemctl restart nginx
            echo "Nginx terinstall!"
            ;;
        *)
            echo "Pilihan tidak valid"
            return
            ;;
    esac
}

# Function to install Node.js and npm
install_nodejs() {
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
    apt install -y nodejs
    npm install -g npm@latest
    echo "Node.js dan npm terinstall!"
    echo "Node.js version: $(node -v)"
    echo "npm version: $(npm -v)"
}

# Function to install FrankenPHP
install_frankenphp() {
    echo "=== Instalasi dan Konfigurasi FrankenPHP ==="
    
    # Install FrankenPHP
    curl -sSL https://deb.frankenphp.dev/frankenphp.asc | gpg --dearmor -o /usr/share/keyrings/frankenphp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/frankenphp-archive-keyring.gpg] https://deb.frankenphp.dev jammy main" | tee /etc/apt/sources.list.d/frankenphp.list
    apt update
    apt install -y frankenphp

    # Konfigurasi sebagai daemon
    read -p "Apakah Anda ingin menjalankan FrankenPHP sebagai daemon? (y/n): " setup_daemon
    if [ "$setup_daemon" = "y" ]; then
        # Buat service file untuk systemd
        cat > /etc/systemd/system/frankenphp.service <<EOL
[Unit]
Description=FrankenPHP Application Server
After=network.target

[Service]
Type=simple
User=www-data
Group=www-data
ExecStart=/usr/local/bin/frankenphp run --config /etc/frankenphp/Caddyfile
Restart=always
RestartSec=5
StartLimitInterval=0
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOL

        # Buat direktori konfigurasi
        mkdir -p /etc/frankenphp

        # Tanya port untuk FrankenPHP
        read -p "Masukkan port untuk FrankenPHP (default: 8082): " frankenphp_port
        frankenphp_port=${frankenphp_port:-8082}

        # Buat file konfigurasi dasar
        cat > /etc/frankenphp/Caddyfile <<EOL
{
    auto_https off
    admin off
}

:${frankenphp_port} {
    root * /var/www/html
    php_server
}
EOL

        # Aktifkan dan jalankan service
        systemctl daemon-reload
        systemctl enable frankenphp
        systemctl start frankenphp
        
        echo "FrankenPHP daemon dikonfigurasi dan dijalankan pada port ${frankenphp_port}"

        # Tanya untuk setup reverse proxy Nginx
        read -p "Apakah Anda ingin mengkonfigurasi reverse proxy Nginx untuk FrankenPHP? (y/n): " setup_proxy
        if [ "$setup_proxy" = "y" ]; then
            read -p "Masukkan domain untuk aplikasi: " domain_name
            
            # Buat konfigurasi Nginx reverse proxy
            cat > /etc/nginx/sites-available/frankenphp-${domain_name} <<EOL
server {
    listen 80;
    server_name ${domain_name};

    location / {
        proxy_pass http://127.0.0.1:${frankenphp_port};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOL

            # Aktifkan site dan restart Nginx
            ln -s /etc/nginx/sites-available/frankenphp-${domain_name} /etc/nginx/sites-enabled/
            systemctl restart nginx
            
            echo "Reverse proxy Nginx dikonfigurasi untuk ${domain_name}"
        fi
    fi

    echo "FrankenPHP terinstall dan dikonfigurasi!"
}

# Function to configure web application
configure_webapp() {
    read -p "Masukkan nama domain: " domain_name
    read -p "Masukkan path aplikasi (contoh: /var/www/myapp): " app_path
    read -p "Web server yang digunakan (apache/nginx): " web_server

    # Create directory if it doesn't exist
    mkdir -p $app_path

    if [ "$web_server" = "nginx" ]; then
        # Create Nginx configuration
        cat > /etc/nginx/sites-available/$domain_name <<EOL
server {
    listen 80;
    listen [::]:80;
    server_name ${domain_name};
    root ${app_path}/public;

    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOL
        ln -s /etc/nginx/sites-available/$domain_name /etc/nginx/sites-enabled/
        systemctl restart nginx

    elif [ "$web_server" = "apache" ]; then
        # Create Apache configuration
        cat > /etc/apache2/sites-available/$domain_name.conf <<EOL
<VirtualHost *:80>
    ServerName ${domain_name}
    DocumentRoot ${app_path}/public

    <Directory ${app_path}/public>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/${domain_name}_error.log
    CustomLog \${APACHE_LOG_DIR}/${domain_name}_access.log combined
</VirtualHost>
EOL
        a2ensite $domain_name
        systemctl restart apache2
    fi

    echo "Konfigurasi web aplikasi selesai!"
}

# Function to install database
install_database() {
    echo "Pilih database yang akan diinstall:"
    echo "1. MySQL"
    echo "2. PostgreSQL"
    read -p "Pilihan [1-2]: " db_choice

    case $db_choice in
        1)
            apt install -y mysql-server
            mysql_secure_installation
            echo "MySQL terinstall!"
            ;;
        2)
            apt install -y postgresql postgresql-contrib
            echo "PostgreSQL terinstall!"
            ;;
        *)
            echo "Pilihan tidak valid"
            return
            ;;
    esac
}

# Function to install phpMyAdmin
install_phpmyadmin() {
    read -p "Masukkan alias untuk phpMyAdmin (contoh: pma): " pma_alias
    read -p "Web server yang digunakan (apache/nginx): " web_server

    # Download and extract phpMyAdmin
    mkdir -p /var/www/${pma_alias}
    wget -qO /tmp/phpmyadmin.zip https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.zip
    unzip /tmp/phpmyadmin.zip -d /tmp/
    mv /tmp/phpMyAdmin-*-all-languages/* /var/www/${pma_alias}/
    rm -rf /tmp/phpmyadmin.zip /tmp/phpMyAdmin-*-all-languages

    if [ "$web_server" = "nginx" ]; then
        # Create Nginx configuration for phpMyAdmin
        cat > /etc/nginx/sites-available/${pma_alias} <<EOL
server {
    listen 80;
    server_name ${pma_alias}.*;
    root /var/www/${pma_alias};

    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOL
        ln -s /etc/nginx/sites-available/${pma_alias} /etc/nginx/sites-enabled/
        systemctl restart nginx

    elif [ "$web_server" = "apache" ]; then
        # Create Apache configuration for phpMyAdmin
        cat > /etc/apache2/sites-available/${pma_alias}.conf <<EOL
<VirtualHost *:80>
    ServerName ${pma_alias}.localhost
    DocumentRoot /var/www/${pma_alias}

    <Directory /var/www/${pma_alias}>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOL
        a2ensite ${pma_alias}
        systemctl restart apache2
    fi

    echo "phpMyAdmin terinstall dengan alias '${pma_alias}'!"
}

# Main menu loop
while true; do
    show_menu
    read -p "Pilihan [1-8]: " choice

    case $choice in
        1) install_php ;;
        2) install_webserver ;;
        3) install_nodejs ;;
        4) install_frankenphp ;;
        5) configure_webapp ;;
        6) install_database ;;
        7) install_phpmyadmin ;;
        8) echo "Terima kasih!"; exit 0 ;;
        *) echo "Pilihan tidak valid" ;;
    esac

    read -p "Tekan Enter untuk melanjutkan..."
done
