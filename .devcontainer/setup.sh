#!/bin/bash

sudo apt-get update
sudo apt-get install -y curl gnupg pcmanfm unzip xdg-user-dirs x11-utils idesk

xdg-user-dirs-update

# Установка Chrome
curl -sSL https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -o /tmp/chrome.deb
sudo apt-get install -y /tmp/chrome.deb
rm /tmp/chrome.deb

# Установка WARP
curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | sudo gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/cloudflare-client.list
sudo apt-get update && sudo apt-get install -y cloudflare-warp

# Расширение Canvas Defender
mkdir -p ~/.config/chrome-extensions
curl -sSL https://github.com/multilogin/canvas-defender/releases/download/1.1.0/canvas-defender-1.1.0.zip -o /tmp/canvas.zip
unzip /tmp/canvas.zip -d ~/.config/chrome-extensions/canvas-defender
rm /tmp/canvas.zip

# Настройка pcmanfm
mkdir -p ~/.config/pcmanfm/default
cat <<EOF > ~/.config/pcmanfm/default/desktop-items-0.conf
[*]
wallpaper_mode=color
desktop_bg=#2c3e50
desktop_shadow=#000000
show_wm_menu=1
EOF

# Ярлыки для pcmanfm
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

# Настройка idesk (резервный слой иконок)
mkdir -p ~/.idesktop
cat <<EOF > ~/.ideskrc
Background.File:
Font.Name: Arial
Font.Color: white
Caption.OnHover: false
ToolTips.Font: Arial
ToolTips.OnHover: true
ToolTips.Delay: 500
EOF

cat <<EOF > ~/.idesktop/kaggle.lnk
table Icon
  Caption: Kaggle
  Command: google-chrome --no-sandbox --disable-dev-shm-usage --disable-gpu --proxy-server="socks5://127.0.0.1:40000" --load-extension=$HOME/.config/chrome-extensions/canvas-defender --password-store=basic https://www.kaggle.com
  Icon: /usr/share/icons/hicolor/48x48/apps/google-chrome.png
  Width: 48
  Height: 48
  X: 50
  Y: 50
end
EOF

cat <<EOF > ~/.idesktop/sagemaker.lnk
table Icon
  Caption: SageMaker
  Command: google-chrome --no-sandbox --disable-dev-shm-usage --disable-gpu --proxy-server="socks5://127.0.0.1:40000" --load-extension=$HOME/.config/chrome-extensions/canvas-defender --password-store=basic https://studiolab.sagemaker.aws/
  Icon: /usr/share/icons/hicolor/48x48/apps/google-chrome.png
  Width: 48
  Height: 48
  X: 50
  Y: 150
end
EOF
