# 🚀 Auto VPS Ubuntu Setup

![Bash](https://img.shields.io/badge/Bash-Script-green?logo=gnubash)

> **All-in-one VPS Provisioning & Web Hosting Toolkit**

---

## ✨ Fitur Unggulan

- 🟢 **Menu Interaktif 3 Kolom** — Navigasi mudah, semua fitur dalam satu layar.
- 🛡️ **Menu WAJIB: Setup Dasar VPS** — Update, upgrade, hostname, timezone, locale, firewall/UFW. **Jalankan ini pertama kali!**
- 🐘 **Instalasi PHP** (banyak ekstensi, siap Laravel, WordPress, phpMyAdmin, dsb)
- 🌐 **Nginx, Database, Node.js, FrankenPHP, WordPress, phpMyAdmin** — Semua siap satu klik.
- 🔒 **SSL Let's Encrypt Otomatis** — Deteksi domain yang belum HTTPS, aktifkan sekaligus. **Config Nginx WordPress hanya HTTP saat install, blok SSL otomatis diinject setelah pilih menu SSL!**
- ⏳ **Progress Bar & Spinner** — Proses install lebih informatif.
- 🧭 **Ganti Mirror APT** — Pilih mirror negara atau otomatis cari mirror tercepat (netselect).
- 🖥️ **Info Sistem Modern** — Menu utilitas menampilkan info sistem (CPU, RAM, disk, webserver, dsb) dengan tampilan modern dan interaktif (systeminfo.sh).
- 🧩 **Cek Ekstensi PHP Terinstall** — Tampilkan semua ekstensi PHP dalam tabel 3 kolom.
- 🧩 **Struktur Modular** — Mudah di-maintain: `utils.sh`, `installers.sh`, `configurators.sh`.

---

## 🖥️ Contoh Menu Utama

```
*** HARUS! Setup Dasar VPS (Update, Hostname, Timezone, Locale, Firewall) ***
================================================================================
--- Instalasi Dasar ---           --- Optimasi & Keamanan ---   --- Utilitas ---
1. Install PHP                    10. Optimasi Server           14. Tampilkan Info Sistem
2. Install Nginx                  11. Sistem Cache              15. Aktifkan SSL Semua Domain
3. Install Database               12. Security Hardening        16. Konfigurasi systemd Node.js
4. Install phpMyAdmin             13. Sistem Backup             17. Hapus SSL Domain
5. Install Node.js & npm
6. Install FrankenPHP
7. Install WordPress
8. Konfigurasi Aplikasi Web
9. Konfigurasi PHP
================================================================================
```

## Menu Konfigurasi PHP

Menu ini memungkinkan Anda untuk:
- Mengubah `memory_limit` (dengan validasi input)
- Mengubah `post_max_size` (dengan validasi input)
- Mengubah `upload_max_filesize` (dengan validasi input)
- Mengubah `max_execution_time` (dengan validasi input, hanya angka positif)
- Mengubah `max_input_time` (dengan validasi input, hanya angka positif)
- Restart service PHP-FPM

Setiap perubahan akan menampilkan pesan sukses atau error secara interaktif dan berwarna.

Menu ini otomatis mendeteksi semua versi PHP-FPM yang terinstall, dan Anda dapat memilih versi yang ingin dikonfigurasi jika ada lebih dari satu.