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

    if command -v python3 &> /dev/null; then
        echo "python3 başarıyla kuruldu."
    else
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
    cd /tmp/cloudflared-kurulum

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

    if command -v cloudflared &> /dev/null; then
        echo "cloudflared başarıyla kuruldu."
    else
        echo "cloudflared kurulamadı. Elle kurmanız gerekiyor."
        exit 1
    fi
else
    echo "cloudflared zaten yüklü."
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
