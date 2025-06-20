#!/bin/bash

FILE="swarm.pem"
PORT=8000

# swarm.pem var mı?
if [ ! -f "$FILE" ]; then
  echo "Hata: $FILE dosyası bulunamadı!"
  exit 1
fi

# python3 kontrolü
echo ">> python3 kontrol ediliyor..."
if ! command -v python3 &> /dev/null; then
    echo "python3 yüklü değil. Kurulum başlatılıyor..."

    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        sudo apt-get update
        sudo apt-get install -y python3 python3-pip
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v brew &> /dev/null; then
            brew install python
        else
            echo "Homebrew yüklü değil. python3'ü elle kurmanız gerekiyor."
            exit 1
        fi
    else
        echo "Desteklenmeyen işletim sistemi: $OSTYPE"
        exit 1
    fi

    if ! command -v python3 &> /dev/null; then
        echo "python3 kurulamadı. Elle kurmanız gerekiyor."
        exit 1
    fi
else
    echo "python3 zaten yüklü."
fi

# cloudflared kontrolü
echo ">> cloudflared kontrol ediliyor..."

ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then
    CLOUDFLARED_ARCH="amd64"
elif [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
    CLOUDFLARED_ARCH="arm64"
else
    echo "Desteklenmeyen mimari: $ARCH"
    exit 1
fi

if ! command -v cloudflared &> /dev/null; then
    echo "cloudflared yüklü değil. Kurulum başlatılıyor..."

    mkdir -p /tmp/cloudflared-kurulum
    cd /tmp/cloudflared-kurulum || exit 1

    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        curl -L "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${CLOUDFLARED_ARCH}" -o cloudflared
        chmod +x cloudflared
        sudo mv cloudflared /usr/local/bin/
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        curl -L "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-darwin-${CLOUDFLARED_ARCH}.tgz" -o cloudflared.tgz
        tar -xzf cloudflared.tgz
        chmod +x cloudflared
        sudo mv cloudflared /usr/local/bin/
    else
        echo "Desteklenmeyen işletim sistemi: $OSTYPE"
        exit 1
    fi

    cd - &> /dev/null

    if ! command -v cloudflared &> /dev/null; then
        echo "cloudflared kurulamadı. Elle kurmanız gerekiyor."
        exit 1
    fi
else
    echo "cloudflared zaten yüklü."
fi

# Renk kodları
BOLD='\033[1m'
GREEN='\033[1;32m'
NC='\033[0m'

# HTTP sunucu başlat
echo "HTTP sunucu başlatılıyor (port $PORT)..."
python3 -m http.server "$PORT" &

HTTP_PID=$!
sleep 2

# Sunucu gerçekten çalışıyor mu kontrol et
if ! kill -0 "$HTTP_PID" 2>/dev/null; then
    echo "HTTP sunucusu başlatılamadı!"
    exit 1
fi

# cloudflared tüneli başlat
echo "Cloudflared tüneli kuruluyor..."
cloudflared tunnel --url "http://localhost:$PORT" > /tmp/cloudflared.log 2>&1 &

CLOUDFLARED_PID=$!

# Tünel URL'sini bulmak için birkaç saniyelik döngü
TUNNEL_URL=""
for i in {1..10}; do
    sleep 1
    TUNNEL_URL=$(grep -o 'https://[^ ]*\.trycloudflare\.com' /tmp/cloudflared.log | head -n 1)
    if [[ -n "$TUNNEL_URL" ]]; then
        break
    fi
done

if [ -z "$TUNNEL_URL" ]; then
  echo "Tünel URL'si bulunamadı!"
  kill -TERM "$HTTP_PID" 2>/dev/null
  kill -TERM "$CLOUDFLARED_PID" 2>/dev/null
  exit 1
fi

# Bağlantıyı göster
echo
echo -e "${BOLD} 🐉 ShadoWeysel 🐉 ${NC}"
echo -e "swarm.pem dosyasını indirmek için bu bağlantıyı kullanın:"
echo -e "${GREEN}${TUNNEL_URL}/${FILE}${NC}"
echo
echo "Sunucuları durdurmak için Ctrl+C tuşlayın."

# Ctrl+C ile temiz kapatma
trap "echo 'Sunucular durduruluyor...'; kill -TERM $HTTP_PID $CLOUDFLARED_PID; exit" INT

wait
