#!/usr/bin/env bash
set -Eeuo pipefail

: "${FB_RTMP_SERVER:?FB_RTMP_SERVER belum diatur di /etc/facebook-live-asmr.env}"
: "${FB_STREAM_KEY:?FB_STREAM_KEY belum diatur di /etc/facebook-live-asmr.env}"

VIDEO="${VIDEO_PATH:-/opt/facebook-live-asmr/video/asmr.mp4}"
VIDEO_BITRATE="${VIDEO_BITRATE:-2500k}"
AUDIO_BITRATE="${AUDIO_BITRATE:-128k}"
GOP="${GOP:-60}"

if [[ ! -r "$VIDEO" ]]; then
  echo "ERROR: Video tidak ditemukan atau tidak bisa dibaca: $VIDEO" >&2
  exit 1
fi

# Hilangkan slash terakhir agar URL server dan stream key digabung dengan benar.
SERVER="${FB_RTMP_SERVER%/}"
RTMP_URL="${SERVER}/${FB_STREAM_KEY}"

echo "Memulai FFmpeg; file video: $VIDEO"
echo "Server RTMP(S) dikonfigurasi. Stream key tidak akan dicetak ke log."

exec ffmpeg \
  -hide_banner \
  -nostdin \
  -loglevel warning \
  -re \
  -stream_loop -1 \
  -i "$VIDEO" \
  -map 0:v:0 \
  -map 0:a:0? \
  -c:v libx264 \
  -preset veryfast \
  -b:v "$VIDEO_BITRATE" \
  -maxrate "$VIDEO_BITRATE" \
  -bufsize 5000k \
  -pix_fmt yuv420p \
  -g "$GOP" \
  -keyint_min "$GOP" \
  -sc_threshold 0 \
  -c:a aac \
  -b:a "$AUDIO_BITRATE" \
  -ar 44100 \
  -f flv \
  "$RTMP_URL"
