#!/bin/bash
set -e

echo "=== [1/6] Installing System Dependencies & Icon Themes ==="
sudo apt-get update
sudo apt-get install -y \
  curl gnupg pcmanfm unzip xdg-user-dirs x11-utils idesk \
  hicolor-icon-theme gnome-icon-theme desktop-file-utils \
  libglib2.0-bin dbus-x11 lxde-icon-theme

xdg-user-dirs-update || true

echo "=== [2/6] Installing Google Chrome ==="
curl -sSL https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -o /tmp/chrome.deb
sudo apt-get install -y /tmp/chrome.deb
rm -f /tmp/chrome.deb

# Прямой абсолютный путь к иконке Chrome
CHROME_ICON="/opt/google/chrome/product_logo_48.png"
if [ ! -f "$CHROME_ICON" ]; then
  CHROME_ICON="/usr/share/icons/hicolor/48x48/apps/google-chrome.png"
fi

echo "=== [3/6] Installing Cloudflare WARP ==="
curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | sudo gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/cloudflare-client.list
sudo apt-get update && sudo apt-get install -y cloudflare-warp || echo "WARP optional notice"

echo "=== [4/6] Installing Canvas Defender Extension ==="
mkdir -p ~/.config/chrome-extensions
curl -sSL https://github.com/multilogin/canvas-defender/releases/download/1.1.0/canvas-defender-1.1.0.zip -o /tmp/canvas.zip
unzip -o /tmp/canvas.zip -d ~/.config/chrome-extensions/canvas-defender
rm -f /tmp/canvas.zip

echo "=== [5/6] Configuring Desktop Environment & Desktop Shortcuts ==="
TARGET_HOME="$HOME"
mkdir -p "$TARGET_HOME/Desktop"
mkdir -p "$TARGET_HOME/.config/pcmanfm/default"
mkdir -p "$TARGET_HOME/.fluxbox"

# Конфигурация рабочего стола PCManFM
cat <<EOF > "$TARGET_HOME/.config/pcmanfm/default/desktop-items-0.conf"
[*]
wallpaper_mode=color
desktop_bg=#1e293b
desktop_fg=#ffffff
desktop_shadow=#000000
show_desktop=1
show_wm_menu=1
sort=name
sort_by=name
EOF

CHROME_FLAGS="--no-sandbox --disable-dev-shm-usage --disable-gpu --proxy-server=\"socks5://127.0.0.1:40000\" --load-extension=$TARGET_HOME/.config/chrome-extensions/canvas-defender --password-store=basic"

# 1. Основной ярлык Google Chrome
cat <<EOF > "$TARGET_HOME/Desktop/google-chrome.desktop"
[Desktop Entry]
Version=1.0
Name=Google Chrome
Comment=Access the Internet
Exec=google-chrome $CHROME_FLAGS
Icon=$CHROME_ICON
Terminal=false
Type=Application
Categories=Network;WebBrowser;
EOF

# 2. Ярлык Kaggle Chrome
cat <<EOF > "$TARGET_HOME/Desktop/Kaggle.desktop"
[Desktop Entry]
Version=1.0
Name=Kaggle Chrome
Comment=Open Kaggle
Exec=google-chrome $CHROME_FLAGS https://www.kaggle.com
Icon=$CHROME_ICON
Terminal=false
Type=Application
Categories=Network;WebBrowser;
EOF

# 3. Ярлык SageMaker Chrome
cat <<EOF > "$TARGET_HOME/Desktop/SageMaker.desktop"
[Desktop Entry]
Version=1.0
Name=SageMaker Chrome
Comment=Open SageMaker Studio Lab
Exec=google-chrome $CHROME_FLAGS https://studiolab.sagemaker.aws/
Icon=$CHROME_ICON
Terminal=false
Type=Application
Categories=Network;WebBrowser;
EOF

chmod +x "$TARGET_HOME/Desktop/"*.desktop
sudo cp "$TARGET_HOME/Desktop/Kaggle.desktop" /usr/share/applications/
sudo cp "$TARGET_HOME/Desktop/SageMaker.desktop" /usr/share/applications/

# Fluxbox Правый Клик Меню
cat <<EOF > "$TARGET_HOME/.fluxbox/menu"
[begin] (Codespaces Desktop)
  [exec] (Google Chrome) {google-chrome $CHROME_FLAGS} <$CHROME_ICON>
  [exec] (Kaggle Chrome) {google-chrome $CHROME_FLAGS https://www.kaggle.com} <$CHROME_ICON>
  [exec] (SageMaker Chrome) {google-chrome $CHROME_FLAGS https://studiolab.sagemaker.aws/} <$CHROME_ICON>
  [separator]
  [exec] (File Manager) {pcmanfm}
  [exec] (Terminal) {xterm}
  [separator]
  [restart] (Restart WM)
  [reconfig] (Reconfigure WM)
[end]
EOF

echo "=== [6/6] Updating Icon Cache & Permissions ==="
sudo gtk-update-icon-cache -f /usr/share/icons/hicolor || true
sudo chown -R $(whoami):$(whoami) "$TARGET_HOME" || true

echo "=== DevContainer Setup Completed Successfully! ==="
