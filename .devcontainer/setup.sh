#!/bin/bash

# Обновление и установка пакетов
sudo apt-get update
sudo apt-get install -y curl gnupg pcmanfm unzip xdg-user-dirs x11-utils

# Инициализация стандартных директорий пользователя
xdg-user-dirs-update

# Установка Google Chrome
curl -sSL https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -o /tmp/chrome.deb
sudo apt-get install -y /tmp/chrome.deb
rm /tmp/chrome.deb

# Установка Cloudflare WARP
curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | sudo gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/cloudflare-client.list
sudo apt-get update && sudo apt-get install -y cloudflare-warp

# Подготовка расширения для обхода фингерпринтинга
mkdir -p ~/.config/chrome-extensions
curl -sSL https://github.com/multilogin/canvas-defender/releases/download/1.1.0/canvas-defender-1.1.0.zip -o /tmp/canvas.zip
unzip /tmp/canvas.zip -d ~/.config/chrome-extensions/canvas-defender
rm /tmp/canvas.zip

# Настройка pcmanfm (темный фон)
mkdir -p ~/.config/pcmanfm/default
cat <<EOF > ~/.config/pcmanfm/default/desktop-items-0.conf
[*]
wallpaper_mode=color
desktop_bg=#2c3e50
desktop_shadow=#000000
show_wm_menu=1
EOF

# Создание ярлыков на рабочем столе
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

cat <<EOF > ~/Desktop/SageMaker.desktop
[Desktop Entry]
Version=1.0
Name=SageMaker Chrome
Exec=google-chrome --no-sandbox --disable-dev-shm-usage --disable-gpu --proxy-server="socks5://127.0.0.1:40000" --load-extension=$HOME/.config/chrome-extensions/canvas-defender --password-store=basic https://studiolab.sagemaker.aws/
Icon=google-chrome
Terminal=false
Type=Application
EOF
chmod +x ~/Desktop/SageMaker.desktop

# Резервное меню Fluxbox
mkdir -p ~/.fluxbox
cat <<EOF > ~/.fluxbox/menu
[begin] (Fluxbox)
    [exec] (Kaggle Chrome) {google-chrome --no-sandbox --disable-dev-shm-usage --disable-gpu --proxy-server="socks5://127.0.0.1:40000" --load-extension=$HOME/.config/chrome-extensions/canvas-defender --password-store=basic https://www.kaggle.com}
    [exec] (SageMaker Chrome) {google-chrome --no-sandbox --disable-dev-shm-usage --disable-gpu --proxy-server="socks5://127.0.0.1:40000" --load-extension=$HOME/.config/chrome-extensions/canvas-defender --password-store=basic https://studiolab.sagemaker.aws/}
    [exec] (Terminal) {x-terminal-emulator}
    [restart] (Restart)
    [exit] (Exit)
[end]
EOF
