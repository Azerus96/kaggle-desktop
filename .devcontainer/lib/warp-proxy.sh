#!/usr/bin/env bash
# Shared helpers for configuring the desktop's browser proxy.
# Uses bepass-org/warp-plus to run WARP in userspace without NET_ADMIN or tun.

WARP_SOCKS_HOST="127.0.0.1"
WARP_SOCKS_PORT="8086"
WARP_READY_MARKER="/tmp/.warp-proxy-ready"

warp_log() {
  echo "[$(date -Is)] $*"
}

warp_try_start() {
  rm -f "${WARP_READY_MARKER}"

  # 1. Скачиваем warp-plus (userspace клиент), если его еще нет
  if ! command -v warp-plus >/dev/null 2>&1; then
    warp_log "WARP: Downloading warp-plus (userspace WARP client)..."
    curl -fsSL -o /tmp/warp-plus.zip "https://github.com/bepass-org/warp-plus/releases/latest/download/warp-plus_linux-amd64.zip"
    sudo unzip -o /tmp/warp-plus.zip -d /usr/local/bin/
    sudo chmod +x /usr/local/bin/warp-plus
    rm -f /tmp/warp-plus.zip
  fi

  # 2. Запускаем warp-plus в фоне
  if ! pgrep -x warp-plus >/dev/null 2>&1; then
    warp_log "WARP: Starting warp-plus on port ${WARP_SOCKS_PORT}..."
    # Запускаем без root, биндим SOCKS5 на порт 8086
    nohup warp-plus -b "${WARP_SOCKS_HOST}:${WARP_SOCKS_PORT}" >/tmp/warp-plus.log 2>&1 &
  fi

  # 3. Ждем и проверяем, что трафик реально идет через прокси
  local i
  for i in $(seq 1 20); do
    if curl --max-time 3 -s -o /dev/null \
         --socks5-hostname "${WARP_SOCKS_HOST}:${WARP_SOCKS_PORT}" \
         https://www.gstatic.com/generate_204; then
      touch "${WARP_READY_MARKER}"
      warp_log "WARP: proxy confirmed working on ${WARP_SOCKS_HOST}:${WARP_SOCKS_PORT}"
      return 0
    fi
    sleep 1
  done

  warp_log "WARP: proxy did not come up in time - Chrome will use a direct connection"
  warp_log "WARP: Check /tmp/warp-plus.log for details."
  return 0
}

chrome_flags() {
  local flags="--no-sandbox --disable-dev-shm-usage --disable-gpu --password-store=basic"

  if [ -f "${WARP_READY_MARKER}" ]; then
    flags="${flags} --proxy-server=socks5://${WARP_SOCKS_HOST}:${WARP_SOCKS_PORT}"
  fi

  # Маскируем Linux под обычную Windows 10, чтобы не злить антифрод Kaggle
  flags="${flags} --user-agent=\"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36\""

  echo "${flags}"
}

write_fluxbox_menu() {
  local flags="$1"
  local icon="$2"
  mkdir -p "${HOME}/.fluxbox"
  cat > "${HOME}/.fluxbox/menu" <<EOF_MENU
[begin] (Codespaces Desktop)
  [exec] (Google Chrome) {/usr/bin/google-chrome-stable ${flags}} <${icon}>
  [exec] (Kaggle Chrome) {/usr/bin/google-chrome-stable ${flags} https://www.kaggle.com} <${icon}>
  [exec] (SageMaker Chrome) {/usr/bin/google-chrome-stable ${flags} https://studiolab.sagemaker.aws/} <${icon}>
  [separator]
  [exec] (File Manager) {pcmanfm}
  [exec] (Terminal) {xterm}
  [separator]
  [restart] (Restart WM)
  [reconfig] (Reconfigure WM)
[end]
EOF_MENU
}
