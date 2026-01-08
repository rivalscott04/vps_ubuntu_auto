# Auto VPS Ubuntu Setup

Script bash untuk setup VPS Ubuntu dari nol sampai siap hosting. Cocok buat yang males setup manual atau sering deploy VPS baru.

## Yang Bisa Dilakukan

Script ini punya menu interaktif yang bisa install dan konfigurasi berbagai komponen web server. Dari PHP, Nginx, database, sampai WordPress bisa diinstall dengan beberapa klik. Ada juga fitur optimasi, keamanan, dan utilitas lainnya.

### Instalasi Dasar

- **PHP** - Install PHP dengan banyak ekstensi yang umum dipake (Laravel, WordPress, dll). Bisa pilih versi PHP yang diinginkan.
- **Nginx** - Web server dengan konfigurasi dasar yang siap pakai.
- **Database** - Install MySQL/MariaDB atau PostgreSQL, pilih sesuai kebutuhan.
- **phpMyAdmin** - Interface web untuk manage database MySQL/MariaDB.
- **Node.js & npm** - Untuk aplikasi Node.js, bisa pilih versi LTS atau latest.
- **FrankenPHP** - PHP application server yang lebih modern, alternatif dari PHP-FPM.
- **WordPress** - Install WordPress otomatis dengan konfigurasi Nginx yang proper.
- **SSO** - Setup Single Sign-On untuk autentikasi terpusat.
- **Python** - Install Python dengan pip dan tools yang diperlukan.
- **Docker** - Install Docker dan Docker Compose untuk containerization.

### Konfigurasi

- **Konfigurasi Aplikasi Web** - Setup virtual host Nginx untuk domain baru. Bisa untuk PHP atau aplikasi Node.js.
- **Routing Berbasis Path** - Setup routing berdasarkan path untuk multiple aplikasi di satu domain.
- **Konfigurasi PHP** - Edit setting PHP seperti memory_limit, upload_max_filesize, dll. Ada validasi input dan auto-detect versi PHP yang terinstall.
- **Konfigurasi systemd** - Setup service systemd untuk aplikasi Node.js atau Python agar bisa auto-start dan manage dengan systemctl.

### Optimasi & Keamanan

- **Optimasi Server** - Tweak setting sistem untuk performa lebih baik.
- **Sistem Cache** - Install dan setup cache system (Redis, Memcached, dll).
- **Security Hardening** - Hardening keamanan server dengan berbagai best practices.
- **Sistem Backup** - Setup backup otomatis untuk database dan file penting.

### Utilitas

- **Setup Dasar VPS** - **WAJIB DILAKUKAN PERTAMA KALI!** Update sistem, set hostname, timezone, locale, dan firewall. Script ini juga bisa ganti mirror APT (bisa pilih manual atau auto-detect yang tercepat).
- **Info Sistem** - Tampilkan info lengkap sistem (CPU, RAM, disk, webserver, dll) dengan format yang rapi.
- **SSL Let's Encrypt** - Auto-detect domain yang belum punya SSL dan aktifkan sekaligus. Untuk WordPress, config Nginx awalnya cuma HTTP, blok SSL baru diinject setelah pilih menu SSL ini.
- **Hapus SSL Domain** - Hapus SSL certificate untuk domain tertentu.
- **Setting Cron Job** - Setup cron job dengan mudah.
- **Setup Virtual Environment (venv)** - Buat Python virtual environment.
- **Menu Hapus** - Uninstall komponen yang sudah terinstall.

## Cara Pakai

1. Clone atau download repository ini
2. Pastikan script executable:
   ```bash
   chmod +x auto-vps8.2.sh
   ```
3. Jalankan sebagai root:
   ```bash
   sudo ./auto-vps8.2.sh
   ```
4. **PENTING:** Pilih menu "15. Setup Dasar VPS" dulu sebelum install yang lain. Ini akan update sistem, set hostname, timezone, dan firewall.

## Struktur File

Script ini modular, jadi mudah di-maintain:

- `auto-vps8.2.sh` - File utama, menu interaktif
- `utils.sh` - Fungsi-fungsi helper (logging, validasi, dll)
- `installers.sh` - Semua fungsi untuk install komponen
- `configurators.sh` - Semua fungsi untuk konfigurasi
- `systeminfo.sh` - Script untuk tampilkan info sistem
- `php_config_menu.sh` - Menu khusus konfigurasi PHP

## Catatan Penting

- Script ini harus dijalankan sebagai root (pakai sudo)
- Untuk Ubuntu (tested di Ubuntu 20.04, 22.04, 24.04)
- Beberapa fitur butuh koneksi internet yang stabil
- SSL Let's Encrypt butuh domain yang sudah pointing ke IP VPS
- Script ini idempotent untuk beberapa operasi (misal setup dasar VPS), jadi aman dijalankan ulang

## Tips

- Kalau install PHP, pilih ekstensi yang memang dibutuhkan aja. Terlalu banyak ekstensi bisa bikin install lama.
- Untuk WordPress, pastikan domain sudah pointing ke VPS sebelum install. SSL bisa ditambahkan nanti lewat menu SSL.
- Kalau pakai mirror APT yang lambat, bisa ganti dulu lewat menu Setup Dasar VPS sebelum install yang lain.
- Info sistem bisa dipake untuk monitoring atau troubleshooting.

## Troubleshooting

- Kalau install gagal, cek koneksi internet dan pastikan VPS bisa akses repository Ubuntu.
- Untuk SSL Let's Encrypt, pastikan port 80 dan 443 terbuka di firewall.
- Kalau ada masalah dengan PHP-FPM, cek service status dengan `systemctl status php*-fpm`.
- Untuk masalah database, cek log di `/var/log/mysql/` atau `/var/log/mariadb/`.

## Kontribusi

Kalau ada bug atau mau tambah fitur, silakan buat issue atau pull request. Script ini masih terus dikembangkan.
