#!/bin/bash

# Обновление и установка пакетов
sudo apt-get update
sudo apt-get install -y curl gnupg pcmanfm unzip

# Установка Google Chrome
curl -sSL https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -o /tmp/chrome.deb
sudo apt-get install -y /tmp/chrome.deb
rm /tmp/chrome.deb

# Установка Cloudflare WARP
curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | sudo gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/cloudflare-client.list
sudo apt-get update && sudo apt-get install -y cloudflare-warp

# Подготовка расширения для обхода фингерпринтинга (Canvas/WebGL Defender)
mkdir -p ~/.config/chrome-extensions
curl -sSL https://github.com/multilogin/canvas-defender/releases/download/1.1.0/canvas-defender-1.1.0.zip -o /tmp/canvas.zip
unzip /tmp/canvas.zip -d ~/.config/chrome-extensions/canvas-defender
rm /tmp/canvas.zip

# Создание ярлыка на рабочем столе с загрузкой расширения
mkdir -p ~/Desktop
cat <<EOF > ~/Desktop/Kaggle.desktop
[Desktop Entry]
Version=1.0
Name=Kaggle Chrome
Exec=google-chrome --no-sandbox --disable-dev-shm-usage --disable-gpu --proxy-server="socks5://127.0.0.1:40000" --load-extension=$HOME/.config/chrome-extensions/canvas-defender --password-store=basic https://www.kaggle.com
Icon=google-chrome
Terminal=false
Type=Application
EOF
chmod +x ~/Desktop/Kaggle.desktop

# Настройка автозапуска для Fluxbox
mkdir -p ~/.fluxbox
touch ~/.fluxbox/startup

# Очистка старых записей
sed -i '/pcmanfm/d' ~/.fluxbox/startup
sed -i '/warp-svc/d' ~/.fluxbox/startup
sed -i '/warp-cli/d' ~/.fluxbox/startup
sed -i '/warp-wait/d' ~/.fluxbox/startup

# Добавление сервисов в автозагрузку с правильным ожиданием демона
cat << 'EOF' >> ~/.fluxbox/startup
# Запуск демона WARP
sudo warp-svc > /dev/null 2>&1 &

# Ожидание готовности демона и подключение
(
  for i in {1..30}; do
    warp-cli --accept-tos status >/dev/null 2>&1 && break
    sleep 1
  done
  warp-cli --accept-tos registration new
  warp-cli --accept-tos mode proxy
  warp-cli --accept-tos connect
) &

# Отрисовка рабочего стола
pcmanfm --desktop &
EOF
