#!/bin/bash

FILE="swarm.pem"
PORT=8000

# swarm.pem var mı?
if [ ! -f "$FILE" ]; then
  echo "Hata: $FILE dosyası bulunamadı!"
  exit 1
fi

# python3 var mı?
if ! command -v python3 &> /dev/null; then
  echo "python3 yüklü değil, lütfen kurunuz."
  exit 1
fi

# cloudflared var mı? Yoksa kur
if ! command -v cloudflared &> /dev/null; then
  echo "cloudflared yüklü değil, kuruluyor..."
  curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o cloudflared
  chmod +x cloudflared
  sudo mv cloudflared /usr/local/bin/
  if ! command -v cloudflared &> /dev/null; then
    echo "cloudflared kurulamadı!"
    exit 1
  fi
fi

# Renk kodları (kalın ve yeşil için)
BOLD='\033[1m'
GREEN='\033[1;32m'
NC='\033[0m'

# HTTP server başlat
echo "HTTP sunucu başlatılıyor (port $PORT)..."
python3 -m http.server "$PORT" &

HTTP_PID=$!

sleep 2

# cloudflared tunnel başlat
echo "Cloudflared tüneli kuruluyor..."
cloudflared tunnel --url "http://localhost:$PORT" > /tmp/cloudflared.log 2>&1 &

CLOUDFLARED_PID=$!

sleep 5

# Tünel URL'sini bul
TUNNEL_URL=$(grep -o 'https://[^ ]*\.trycloudflare\.com' /tmp/cloudflared.log | head -n 1)

if [ -z "$TUNNEL_URL" ]; then
  echo "Tünel URL'si bulunamadı!"
  kill $HTTP_PID
  kill $CLOUDFLARED_PID
  exit 1
fi

echo
echo -e "${BOLD} 🐉 ShadoWeysel 🐉 ${NC}"
echo -e "swarm.pem'i indirmek için bu linki kullanın:"
echo -e "${GREEN}${TUNNEL_URL}/${FILE}${NC}"
echo
echo "Sunucuları durdurmak için Ctrl+C tuşlayın."

# Ctrl+C yakala ve temizle
trap "echo 'Sunucular durduruluyor...'; kill $HTTP_PID $CLOUDFLARED_PID; exit" INT

wait
