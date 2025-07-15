# Auto VPS Ubuntu Setup

## Fitur Utama
- **Menu interaktif 3 kolom** untuk instalasi dan konfigurasi server
- **Menu WAJIB: Setup Dasar VPS** (update, upgrade, hostname, timezone, locale, firewall/UFW)
- Instalasi PHP (dengan banyak ekstensi, siap Laravel, WordPress, phpMyAdmin, dsb)
- Instalasi Nginx, Database (MySQL/MariaDB/PostgreSQL), Node.js, FrankenPHP, WordPress, phpMyAdmin
- Konfigurasi aplikasi web, optimasi server, cache, security, backup
- **Aktivasi SSL Let's Encrypt** (certbot) untuk banyak domain sekaligus, dengan deteksi otomatis
- **Progress bar/spinner** pada proses instalasi
- Struktur modular: fungsi dipisah di `utils.sh`, `installers.sh`, `configurators.sh`

## Cara Pakai

1. **Jadikan script executable:**
   ```bash
   chmod +x auto-vps8.2.sh
   ```
2. **Jalankan script sebagai root:**
   ```bash
   sudo ./auto-vps8.2.sh
   ```
3. **WAJIB! Jalankan menu paling atas:**
   > *** HARUS! Setup Dasar VPS (Update, Hostname, Timezone, Locale, Firewall) ***
   - Ini akan update sistem, set hostname, timezone, locale, dan aktifkan firewall.
   - Sangat disarankan reboot setelah selesai.
4. **Lanjutkan instalasi sesuai kebutuhan:**
   - Pilih menu lain (PHP, Nginx, Database, dsb) sesuai kebutuhan project Anda.
   - Untuk SSL, gunakan menu "Aktifkan SSL untuk Semua Domain" agar semua domain yang belum HTTPS bisa diaktifkan sekaligus.

## Troubleshooting
- Jika spinner/progress tidak muncul, pastikan terminal mendukung karakter khusus.
- Jika certbot gagal, cek log certbot atau pastikan domain sudah mengarah ke IP VPS.
- Untuk custom ekstensi PHP, edit bagian `installers.sh` pada fungsi install_php.

## Struktur File
- `auto-vps8.2.sh` (main menu & entry point)
- `utils.sh` (fungsi logging & utilitas)
- `installers.sh` (fungsi instalasi & SSL)
- `configurators.sh` (fungsi konfigurasi, optimasi, backup, dsb)

---

**Script ini cocok untuk provisioning VPS baru, siap pakai untuk web hosting modern!**
