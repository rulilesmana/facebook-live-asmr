# Facebook Live ASMR AutoStream

Repository template untuk menyiarkan video ASMR berulang ke Facebook Live menggunakan FFmpeg di VPS Ubuntu, dengan `systemd` untuk menjaga proses tetap berjalan dan GitHub Actions untuk mengirim pembaruan script.

> **Penting:** repository ini tidak membuat sesi Facebook Live secara otomatis. Buat siaran di Facebook Live Producer, gunakan server URL dan stream key yang valid, lalu pastikan preview diterima. Facebook dapat mengakhiri sesi atau meminta sesi baru. `systemd` hanya memulai ulang proses FFmpeg, bukan membuat sesi Facebook baru.

## Arsitektur

- **GitHub**: sumber kode dan workflow deployment.
- **VPS Ubuntu**: menyimpan media dan menjalankan FFmpeg 24/7.
- **systemd**: menjalankan service saat boot dan mencoba memulihkan proses yang gagal.
- **Facebook Live Producer**: menyediakan server URL dan stream key.

## Kebutuhan

- VPS Ubuntu 22.04 atau 24.04 LTS, disarankan mulai 2 vCPU / RAM 4 GB.
- Satu video MP4 milik sendiri, idealnya H.264 + AAC.
- Akun/Halaman Facebook yang memenuhi syarat LIVE.
- Repository GitHub.

## 1. Unggah repository ke GitHub

1. Buat repository baru, misalnya `facebook-live-asmr`.
2. Unggah semua isi folder ini ke repository tersebut.
3. Jangan pernah memasukkan stream key, password VPS, private SSH key, atau file `.env` berisi rahasia ke GitHub.

## 2. Persiapan VPS (sekali saja)

Masuk ke VPS melalui SSH sebagai user yang memiliki hak `sudo`, lalu jalankan:

```bash
sudo apt update
sudo apt install -y ffmpeg git
sudo useradd --system --create-home --home-dir /var/lib/fbstream --shell /usr/sbin/nologin fbstream || true
```

Clone repository (ganti URL dengan URL repository Anda). Jika folder `/opt/facebook-live-asmr` sudah ada, clone ke lokasi lain lalu salin isinya, atau gunakan direktori kosong:

```bash
cd /opt
sudo git clone https://github.com/USERNAME/facebook-live-asmr.git
sudo chown -R root:root /opt/facebook-live-asmr
sudo chmod 755 /opt/facebook-live-asmr
sudo install -d -o fbstream -g fbstream /opt/facebook-live-asmr/video
```

Jika repository privat, siapkan akses Git di VPS terlebih dahulu. Jangan menaruh token akses dalam URL remote.

## 3. Pasang video

Salin video ASMR ke lokasi berikut:

```text
/opt/facebook-live-asmr/video/asmr.mp4
```

Contoh unggah dari Windows PowerShell (jalankan dari folder tempat video berada; ganti IP dan user):

```powershell
scp .\asmr.mp4 USER_VPS@IP_VPS_ANDA:/tmp/asmr.mp4
```

Lalu di VPS:

```bash
sudo install -o fbstream -g fbstream -m 0644 /tmp/asmr.mp4 /opt/facebook-live-asmr/video/asmr.mp4
rm -f /tmp/asmr.mp4
```

Video harus memiliki trek video yang valid. Script mengizinkan audio tidak tersedia, tetapi untuk konten ASMR sebaiknya video memiliki audio yang sah dan jelas.

## 4. Simpan kredensial Facebook secara aman di VPS

Buka Facebook Live Producer dan pilih Halaman yang benar. Salin **server URL** dan **stream key** yang ditampilkan. Buat file rahasia di VPS:

```bash
sudo install -m 600 -o root -g root /dev/null /etc/facebook-live-asmr.env
sudo nano /etc/facebook-live-asmr.env
```

Isi file dengan URL dan key yang diberikan Facebook, misalnya:

```bash
FB_RTMP_SERVER='rtmps://SERVER_URL_DARI_FACEBOOK'
FB_STREAM_KEY='STREAM_KEY_ANDA'
```

Ganti kedua nilai contoh dengan nilai aktual. Jangan bagikan file ini atau commit ke GitHub. Pastikan URL dan stream key berasal dari Live Producer, bukan dari contoh di internet.

## 5. Pasang service systemd

Salin unit service:

```bash
sudo cp /opt/facebook-live-asmr/systemd/facebook-live-asmr.service /etc/systemd/system/
sudo chmod 755 /opt/facebook-live-asmr/stream.sh
sudo chown root:root /opt/facebook-live-asmr/stream.sh
sudo chmod 755 /opt/facebook-live-asmr/stream.sh
sudo systemctl daemon-reload
sudo systemctl enable --now facebook-live-asmr
```

Periksa status dan log:

```bash
sudo systemctl status facebook-live-asmr
sudo journalctl -u facebook-live-asmr -f
```

Jika gagal, periksa terlebih dahulu apakah file video, server URL, stream key, format video, dan izin baca benar. Untuk menghentikan siaran dari VPS:

```bash
sudo systemctl stop facebook-live-asmr
```

## 6. Konfigurasi GitHub Actions untuk deploy script

Workflow `.github/workflows/deploy.yml` menggunakan SSH dengan pemeriksaan host key yang ketat. Di GitHub, buka **Settings → Secrets and variables → Actions**, lalu tambahkan:

- `VPS_HOST`: IP atau hostname VPS.
- `VPS_USER`: user SSH khusus deployment.
- `VPS_SSH_KEY`: private key SSH khusus deployment.
- `VPS_KNOWN_HOSTS`: baris `known_hosts` untuk VPS yang fingerprint-nya sudah diverifikasi melalui kanal tepercaya.

Jangan memakai `ssh-keyscan` secara langsung sebagai verifikasi identitas server pada setiap deployment. Verifikasi fingerprint host terlebih dahulu, kemudian simpan nilai tepercaya di secret `VPS_KNOWN_HOSTS`.

User deployment perlu dapat menjalankan dua perintah administratif yang dipakai workflow. Buat user SSH khusus deployment (contoh: `deployuser`), pastikan public key deployment terpasang di `~deployuser/.ssh/authorized_keys`, lalu atur `sudoers` dengan editor aman:

```bash
sudo visudo -f /etc/sudoers.d/facebook-live-deploy
```

Isi file berikut setelah mengganti `deployuser` dengan nilai `VPS_USER`:

```sudoers
deployuser ALL=(root) NOPASSWD: /usr/bin/install -o root -g root -m 0755 /tmp/facebook-live-stream.sh /opt/facebook-live-asmr/stream.sh, /usr/bin/systemctl restart facebook-live-asmr
```

Validasi sintaks dengan `sudo visudo -cf /etc/sudoers.d/facebook-live-deploy`, lalu pastikan permission file sesuai (umumnya `0440`). Lokasi `install` dapat berbeda di distro tertentu; periksa dengan `command -v install` dan sesuaikan aturan. Jangan memberi akses sudo penuh hanya demi workflow. Untuk lingkungan produksi, pertimbangkan wrapper root-owned yang tervalidasi agar aturan sudo lebih mudah dibatasi.

Workflow ini mengirim hanya `stream.sh` dan me-restart service; video serta file rahasia tetap berada di VPS. Host key harus disimpan dalam secret `VPS_KNOWN_HOSTS` setelah fingerprint server diverifikasi melalui kanal tepercaya.

## 7. Uji sebelum berjalan lama

1. Mulai dari LIVE uji 15–30 menit.
2. Pastikan preview menampilkan video dan suara.
3. Periksa `journalctl` dan statistik penggunaan CPU/jaringan.
4. Uji restart service.
5. Jangan menganggap restart service otomatis membuat sesi LIVE Facebook baru. Jika Facebook mengakhiri sesi, buat/aktifkan sesi baru melalui alur yang didukung Facebook.

## Catatan bandwidth

Bitrate video 2,5 Mbps menggunakan kira-kira 810 GB per 30 hari untuk satu aliran kontinu, belum termasuk overhead protokol dan penggunaan lain. Pastikan paket VPS mengizinkan streaming kontinu dan menyediakan kuota transfer yang cukup.

## Keamanan

- Jangan commit stream key, password, token, atau private SSH key.
- Jika stream key terungkap, reset/ganti dari Facebook Live Producer.
- Batasi akses SSH, gunakan autentikasi key, dan verifikasi host key.
- Gunakan hanya video/audio yang hak penggunaannya Anda miliki.
