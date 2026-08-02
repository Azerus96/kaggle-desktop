#!/bin/bash

# Обновление и установка пакетов, включая xdg-user-dirs для правильной работы рабочего стола
sudo apt-get update
sudo apt-get install -y curl gnupg pcmanfm unzip xdg-user-dirs

# Инициализация стандартных директорий пользователя (чтобы pcmanfm увидел ~/Desktop)
xdg-user-dirs-update

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

# Настройка pcmanfm (темный фон, принудительное отображение иконок)
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

# Ярлык Kaggle
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

# Ярлык SageMaker
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

# Резервный план: добавление ярлыков в меню Fluxbox (по правому клику мыши)
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

# Настройка автозапуска для Fluxbox
touch ~/.fluxbox/startup

# Очистка старых записей
sed -i '/pcmanfm/d' ~/.fluxbox/startup
sed -i '/warp-svc/d' ~/.fluxbox/startup
sed -i '/warp-cli/d' ~/.fluxbox/startup

# Добавление сервисов в автозагрузку
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
