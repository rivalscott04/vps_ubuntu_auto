# Auto VPS Ubuntu Setup

Kumpulan skrip buat bantu setting VPS Ubuntu dari awal sampai siap dipake buat web atau aplikasi. Ada dua cara pakai: yang **simpel buat pemula** atau yang **lengkap buat yang udah biasa ngoprek**.

---

## Ini cocok buat siapa?

Buat kamu yang males ngisi satu-satu perintah pas baru beli VPS, atau sering bikin server baru dan pengen prosesnya cepat dan terarah.

---

## Sebelum mulai

- Pakai **Ubuntu** (umumnya 20.04 ke atas).
- Harus login sebagai **admin server** (biasanya pakai `sudo`).
- Pastikan VPS **kedap internet** buat download paket dan dependensi layanan.

Kalau nanti ada pesan **command `rg` tidak ketemu**, itu cuma program bantu supaya skrip bisa cari teks cepat. Pasang saja dengan:

`sudo apt install ripgrep`

---

## Cara jalanin

Di folder project ini:

```bash
chmod +x auto-vps8.2.sh
sudo ./auto-vps8.2.sh
```

Nanti kamu diminta pilih **mode simpel** atau **mode lanjutan**.

**Tips:** Kalau pakai mode lanjutan, lebih enak pakai menu **setup dasar VPS** dulu (biasanya nomor 15) — itu yang ngurus update sistem, nama mesin, zona waktu, dan firewall ringkas. Baru setelah itu install PHP, database, dan lain-lain.

---

## Mode simpel

Buat yang pengen **dibimbing langkah demi langkah**.

- Ada **wizard setup cepat**: masukin domain dan folder project, skrip bantu tebak jenis aplikasinya (misalnya Laravel, WordPress, project Node), terus bantu beresin hal dasar seperti web server dan setting upload file.
- Bisa **cek kondisi server** dulu sebelum ngapa-ngapain (RAM, disk, dan sebagainya).
- Ada **cek aplikasi**: ringkasannya enak dibaca, ada opsi perbaikan cepat kalau ada yang nyangkut.
- Bisa **cadangkan pengaturan penting** biar kalau salah bisa balikin feelingnya lebih tenang.
- Ada **mode belajar** kalau mau tiap langkah dikasih penjelasan singkat.

SSL untuk banyak domain sekaligus tetap lewat **mode lanjutan**. Kalau aplikasinya jenis yang jarang (misalnya Python/Django tanpa panduan khusus di wizard), bisa lanjut dari mode lanjutan atau set manual.

---

## Mode lanjutan

Menu lengkap seperti biasa: install PHP, Nginx, database, WordPress, Docker, dan banyak lagi. Skrip akan kasih konfirmasi kalau ada yang berpotensi ngubah banyak hal. Ada juga nomor menu buat **balik ke mode simpel** kalau pengen gaya wizard lagi.

---

## Cek kecepatan internet di VPS

Lewat menu info sistem, bisa lihat tes kecepatan ke beberapa kota (termasuk sekitar Jakarta dan kota lain). Yang pertama biasanya pakai server otomatis; sisanya buat gambaran kecepatan ke arah wilayah tertentu.

---

## Hal yang sering bikin gagal

- **Sertifikat HTTPS / Let's Encrypt gagal** — pastikan nama domain sudah benar-benar mengarah ke IP VPS ini, dan akses dari luar ke port web (biasanya 80 dan 443) nggak diblokir firewall.
- **Upload file besar ditolak** — wizard mode simpel sudah bantu samakan batas upload di web server dan PHP; kalau masih kecil, bisa sesuaikan lagi lewat menu lanjutan.
- **Website mutus putus (bad gateway)** — biasanya web server dan aplikasi (misalnya PHP) belum cocok atau salah satu layanan mati; cek dari menu cek aplikasi atau status layanan di server.

---

## Kontribusi

Kalau nemu bug atau punya ide perbaikan, silakan buka issue atau pull request.
