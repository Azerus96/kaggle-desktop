#!/usr/bin/env bash
set -euo pipefail

log() {
  echo "=== $* ==="
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/warp-proxy.sh
source "${SCRIPT_DIR}/lib/warp-proxy.sh"

DESKTOP_DIR="${HOME}/Desktop"
CHROME_EXTENSION_DIR="${HOME}/.config/chrome-extensions/canvas-defender"
PCMANFM_PROFILE_DIR="${HOME}/.config/pcmanfm/default"

log "[1/6] Installing system dependencies, file-manager desktop support and icon themes"
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  ca-certificates curl dbus-x11 desktop-file-utils file gnome-icon-theme \
  gnupg hicolor-icon-theme idesk libglib2.0-bin lsb-release lxde-icon-theme \
  pcmanfm unzip x11-utils xdg-user-dirs xterm

xdg-user-dirs-update || true
DESKTOP_DIR="$(xdg-user-dir DESKTOP 2>/dev/null || printf '%s/Desktop' "${HOME}")"
mkdir -p "${DESKTOP_DIR}"

log "[2/6] Installing Google Chrome"
curl -fsSL https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -o /tmp/chrome.deb
sudo apt-get install -y /tmp/chrome.deb
rm -f /tmp/chrome.deb

CHROME_ICON="/opt/google/chrome/product_logo_48.png"
if [ ! -f "${CHROME_ICON}" ]; then
  CHROME_ICON="/usr/share/icons/hicolor/48x48/apps/google-chrome.png"
fi
if [ ! -f "${CHROME_ICON}" ]; then
  CHROME_ICON="google-chrome"
fi

log "[3/6] Installing Cloudflare WARP (optional)"
if curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | sudo gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg; then
  # Cloudflare's apt repo lags behind new Ubuntu releases by months (this base
  # image resolves to the latest LTS codename, e.g. "resolute"/26.04, which the
  # repo may not have packages for yet -> apt-get update would 404).
  # Probe the actual Release file instead of hardcoding an allow-list, so this
  # self-heals once Cloudflare adds support for the current codename instead
  # of permanently pinning to an older one.
  UBUNTU_CODENAME="$(lsb_release -cs)"
  if ! curl -fsSL --head "https://pkg.cloudflareclient.com/dists/${UBUNTU_CODENAME}/Release" >/dev/null 2>&1; then
    echo "WARP optional notice: Cloudflare repo has no '${UBUNTU_CODENAME}' release yet; falling back to 'jammy' packages (forward-compatible)."
    UBUNTU_CODENAME="jammy"
  fi
  echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ ${UBUNTU_CODENAME} main" | sudo tee /etc/apt/sources.list.d/cloudflare-client.list >/dev/null
  sudo apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y cloudflare-warp || echo "WARP optional notice: package install failed"
else
  echo "WARP optional notice: repository key download failed"
fi

log "[4/6] Installing Canvas Defender extension"
mkdir -p "${CHROME_EXTENSION_DIR}"
if curl -fsSL https://github.com/multilogin/canvas-defender/releases/download/1.1.0/canvas-defender-1.1.0.zip -o /tmp/canvas.zip; then
  unzip -o /tmp/canvas.zip -d "${CHROME_EXTENSION_DIR}"
  rm -f /tmp/canvas.zip
else
  echo "Canvas Defender optional notice: extension download failed"
fi

log "[5/6] Configuring desktop environment and shortcuts"
mkdir -p "${PCMANFM_PROFILE_DIR}" "${HOME}/.fluxbox"

cat > "${PCMANFM_PROFILE_DIR}/desktop-items-0.conf" <<'EOF_CONF'
[*]
wallpaper_mode=color
wallpaper_common=1
desktop_bg=#1e293b
desktop_fg=#ffffff
desktop_shadow=#000000
show_desktop=1
show_wm_menu=1
show_documents=0
show_trash=0
show_mounts=0
sort=name
sort_by=name
EOF_CONF

# NOTE: at build time WARP has not been started yet (that happens on every
# container *start*, in run-desktop.sh), so chrome_flags() will correctly
# return direct-connection flags here. The shortcuts get rewritten with the
# real, verified proxy state every time the container starts.
CHROME_FLAGS_STRING="$(chrome_flags)"

create_desktop_file() {
  local path="$1"
  local name="$2"
  local comment="$3"
  local url="${4:-}"

  cat > "${path}" <<EOF_DESKTOP
[Desktop Entry]
Version=1.0
Name=${name}
Comment=${comment}
Exec=/usr/bin/google-chrome-stable ${CHROME_FLAGS_STRING}${url:+ ${url}}
Icon=${CHROME_ICON}
Terminal=false
Type=Application
Categories=Network;WebBrowser;
StartupNotify=true
EOF_DESKTOP
  chmod 755 "${path}"
  desktop-file-validate "${path}" || true
}

create_desktop_file "${DESKTOP_DIR}/google-chrome.desktop" "Google Chrome" "Access the Internet"
create_desktop_file "${DESKTOP_DIR}/Kaggle.desktop" "Kaggle Chrome" "Open Kaggle" "https://www.kaggle.com"
create_desktop_file "${DESKTOP_DIR}/SageMaker.desktop" "SageMaker Chrome" "Open SageMaker Studio Lab" "https://studiolab.sagemaker.aws/"

sudo cp "${DESKTOP_DIR}/"*.desktop /usr/share/applications/

write_fluxbox_menu "${CHROME_FLAGS_STRING}" "${CHROME_ICON}"

log "[6/6] Updating icon cache and permissions"
sudo gtk-update-icon-cache -f /usr/share/icons/hicolor || true
sudo update-desktop-database /usr/share/applications || true
sudo chown -R "$(id -u):$(id -g)" "${HOME}/.config" "${HOME}/.fluxbox" "${DESKTOP_DIR}" || true

log "DevContainer setup completed successfully"
