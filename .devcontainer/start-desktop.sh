#!/usr/bin/env bash
set -euo pipefail

nohup bash -s <<'EOF_START' >/tmp/desktop-startup.log 2>&1 &
set -u
export DISPLAY="${DISPLAY:-:1}"
export XDG_CURRENT_DESKTOP="LXDE"
export DESKTOP_SESSION="LXDE"

log() {
  echo "[$(date -Is)] $*"
}

DESKTOP_DIR="$(xdg-user-dir DESKTOP 2>/dev/null || printf '%s/Desktop' "${HOME}")"
mkdir -p "${DESKTOP_DIR}" "${HOME}/.config/pcmanfm/default"

log "Starting optional WARP service"
if command -v warp-svc >/dev/null 2>&1; then
  sudo warp-svc >/tmp/warp-svc.log 2>&1 &
  for _ in $(seq 1 15); do
    warp-cli --accept-tos status >/dev/null 2>&1 && break
    sleep 1
  done
  warp-cli --accept-tos registration new || true
  warp-cli --accept-tos mode proxy || true
  warp-cli --accept-tos connect || true
fi

log "Waiting for X server on ${DISPLAY}"
for _ in $(seq 1 30); do
  if xdpyinfo -display "${DISPLAY}" >/dev/null 2>&1 || xset -q -display "${DISPLAY}" >/dev/null 2>&1; then
    X_READY=1
    break
  fi
  sleep 1
done

if [ "${X_READY:-0}" != "1" ]; then
  log "WARNING: X server did not become ready; shortcuts will still be created, but PCManFM desktop cannot be started in this environment"
fi

log "Ensuring Chrome desktop shortcuts exist"
CHROME_ICON="/opt/google/chrome/product_logo_48.png"
[ -f "${CHROME_ICON}" ] || CHROME_ICON="/usr/share/icons/hicolor/48x48/apps/google-chrome.png"
[ -f "${CHROME_ICON}" ] || CHROME_ICON="google-chrome"
CHROME_EXTENSION_DIR="${HOME}/.config/chrome-extensions/canvas-defender"
CHROME_FLAGS="--no-sandbox --disable-dev-shm-usage --disable-gpu --proxy-server=socks5://127.0.0.1:40000 --password-store=basic"
if [ -f "${CHROME_EXTENSION_DIR}/manifest.json" ]; then
  CHROME_FLAGS="${CHROME_FLAGS} --load-extension=${CHROME_EXTENSION_DIR}"
fi

create_desktop_file() {
  local path="$1" name="$2" comment="$3" url="${4:-}"
  cat > "${path}" <<EOF_DESKTOP
[Desktop Entry]
Version=1.0
Name=${name}
Comment=${comment}
Exec=/usr/bin/google-chrome-stable ${CHROME_FLAGS}${url:+ ${url}}
Icon=${CHROME_ICON}
Terminal=false
Type=Application
Categories=Network;WebBrowser;
StartupNotify=true
EOF_DESKTOP
  chmod 755 "${path}"
}

create_desktop_file "${DESKTOP_DIR}/google-chrome.desktop" "Google Chrome" "Access the Internet"
create_desktop_file "${DESKTOP_DIR}/Kaggle.desktop" "Kaggle Chrome" "Open Kaggle" "https://www.kaggle.com"
create_desktop_file "${DESKTOP_DIR}/SageMaker.desktop" "SageMaker Chrome" "Open SageMaker Studio Lab" "https://studiolab.sagemaker.aws/"

log "Marking shortcuts trusted where GIO metadata is available"
if command -v dbus-launch >/dev/null 2>&1 && command -v gio >/dev/null 2>&1; then
  eval "$(dbus-launch --sh-syntax)"
  for item in "${DESKTOP_DIR}/"*.desktop; do
    [ -f "${item}" ] || continue
    gio set -t string "${item}" metadata::trusted true 2>/dev/null || true
  done
fi

log "Cleaning conflicting desktop-manager state"
pkill -f nautilus || true
pkill -f "pcmanfm --desktop" || true
rm -f "${HOME}/.config/pcmanfm/default/desktop-items-0.conf.lock"

if [ "${X_READY:-0}" = "1" ]; then
  log "Starting PCManFM desktop icon manager"
  pcmanfm --desktop --profile=default >/tmp/pcmanfm.log 2>&1 &

  if command -v fluxbox-remote >/dev/null 2>&1; then
    fluxbox-remote reconfigure || true
  fi
else
  log "Skipping PCManFM start because ${DISPLAY} is unavailable"
fi

log "Desktop startup completed; shortcuts in ${DESKTOP_DIR}:"
find "${DESKTOP_DIR}" -maxdepth 1 -name '*.desktop' -printf '%f\n' | sort
EOF_START
