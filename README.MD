# 🚀 Auto VPS Ubuntu Setup

![Bash](https://img.shields.io/badge/Bash-Script-green?logo=gnubash)

> **All-in-one VPS Provisioning & Web Hosting Toolkit**

---

## ✨ Fitur Unggulan

- 🟢 **Menu Interaktif 3 Kolom** — Navigasi mudah, semua fitur dalam satu layar.
- 🛡️ **Menu WAJIB: Setup Dasar VPS** — Update, upgrade, hostname, timezone, locale, firewall/UFW. **Jalankan ini pertama kali!**
- 🐘 **Instalasi PHP** (banyak ekstensi, siap Laravel, WordPress, phpMyAdmin, dsb)
- 🌐 **Nginx, Database, Node.js, FrankenPHP, WordPress, phpMyAdmin** — Semua siap satu klik.
- 🔒 **SSL Let's Encrypt Otomatis** — Deteksi domain yang belum HTTPS, aktifkan sekaligus.
- ⏳ **Progress Bar & Spinner** — Proses install lebih informatif.
- 🧭 **Ganti Mirror APT** — Pilih mirror negara atau otomatis cari mirror tercepat (netselect).
- 🧩 **Cek Ekstensi PHP Terinstall** — Tampilkan semua ekstensi PHP dalam tabel 3 kolom.
- 🧩 **Struktur Modular** — Mudah di-maintain: `utils.sh`, `installers.sh`, `configurators.sh`.

---

## 🖥️ Contoh Menu Utama

```
*** HARUS! Setup Dasar VPS (Update, Hostname, Timezone, Locale, Firewall) ***
================================================================================
--- Instalasi Dasar ---           --- Optimasi & Keamanan ---   --- Utilitas ---
1. Install PHP                    10. Optimasi Server           14. Info Sistem
2. Install Nginx                  11. Sistem Cache              15. Ganti User MySQL
3. Install Database               12. Security Hardening        16. Aktifkan SSL
4. Install phpMyAdmin             13. Sistem Backup             0. Keluar
5. Install Node.js & npm                                      17. Ganti Mirror APT Ubuntu
6. Install FrankenPHP                                         18. Cek Ekstensi PHP Terinstall
7. Install WordPress
8. Konfigurasi Aplikasi Web
9. Konfigurasi PHP
================================================================================
```

---

## 🛠️ Cara Pakai & Utilitas

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
   - Update sistem, set hostname, timezone, locale, aktifkan firewall.
   - **Tips:** Reboot server setelah selesai setup dasar.
4. **Lanjutkan instalasi sesuai kebutuhan:**
   - Pilih menu lain (PHP, Nginx, Database, dsb).
   - Untuk SSL, gunakan menu "Aktifkan SSL untuk Semua Domain" agar semua domain yang belum HTTPS bisa diaktifkan sekaligus.
5. **Utilitas tambahan:**
   - **Ganti Mirror APT Ubuntu:** Pilih mirror negara (Australia, Singapore, Vietnam) atau otomatis cari mirror tercepat (netselect).
   - **Cek Ekstensi PHP Terinstall:** Tampilkan semua ekstensi PHP yang aktif dalam tabel 3 kolom, cocok untuk troubleshooting aplikasi PHP.

---

## 💡 Tips & Best Practice

- **Selalu jalankan menu setup dasar sebelum apapun!**
- **Gunakan SSH key authentication** untuk keamanan ekstra.
- **Cek log** jika ada error pada certbot/SSL.
- **Backup konfigurasi** sebelum mengubah setting penting.
- **Gunakan menu SSL** untuk mengamankan semua domain sekaligus.

---

## 🔥 FAQ

**Q: Apakah script ini aman untuk VPS baru?**
> Ya, script ini didesain untuk provisioning VPS dari awal, termasuk firewall dan update.

**Q: Bisa untuk production?**
> Sangat bisa, tinggal sesuaikan domain dan konfigurasi sesuai kebutuhan project.

**Q: Bisa custom ekstensi PHP?**
> Edit saja bagian `installers.sh` pada fungsi install_php.

**Q: Bagaimana jika spinner/progress tidak muncul?**
> Pastikan terminal mendukung karakter khusus (Cygwin, WSL, Ubuntu, dsb).

---

## 🗂️ Struktur File

- `auto-vps8.2.sh` — Main menu & entry point
- `utils.sh` — Logging & utilitas
- `installers.sh` — Instalasi & SSL
- `configurators.sh` — Konfigurasi, optimasi, backup, dsb

---

## 🏆 Siap Pakai untuk:
- Web Hosting
- WordPress, Laravel, PHP, Node.js, dsb
- Project development & production

---

> **Script ini cocok untuk provisioning VPS baru, siap pakai untuk web hosting modern!**
> 
> _By: Rival & AI Assistant_
