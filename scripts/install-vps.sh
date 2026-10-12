#!/usr/bin/env bash
set -Eeuo pipefail

if [[ "$(id -u)" -eq 0 ]]; then
  echo "Jalankan script ini sebagai user sudo biasa, bukan root." >&2
  exit 1
fi

REPO_DIR="/opt/facebook-live-asmr"

sudo apt update
sudo apt install -y ffmpeg git
sudo useradd --system --create-home --home-dir /var/lib/fbstream --shell /usr/sbin/nologin fbstream 2>/dev/null || true
sudo install -d -o "$USER" -g "$(id -gn)" -m 0755 "$REPO_DIR"
sudo install -d -o fbstream -g fbstream -m 0755 "$REPO_DIR/video"

install -m 0755 stream.sh /tmp/facebook-live-stream.sh
sudo install -o root -g root -m 0755 /tmp/facebook-live-stream.sh "$REPO_DIR/stream.sh"
rm -f /tmp/facebook-live-stream.sh

sudo install -m 0644 systemd/facebook-live-asmr.service /etc/systemd/system/facebook-live-asmr.service
if [[ ! -e /etc/facebook-live-asmr.env ]]; then
  sudo install -m 600 -o root -g root /dev/null /etc/facebook-live-asmr.env
  echo "File /etc/facebook-live-asmr.env dibuat kosong. Isi FB_RTMP_SERVER dan FB_STREAM_KEY sebelum menjalankan service."
fi

sudo systemctl daemon-reload
echo "Selesai. Salin video ke $REPO_DIR/video/asmr.mp4, isi /etc/facebook-live-asmr.env, lalu jalankan:"
echo "  sudo systemctl enable --now facebook-live-asmr"
