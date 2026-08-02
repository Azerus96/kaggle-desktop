#!/usr/bin/env bash
# Runs in the background (launched by start-desktop.sh). Splitting this out
# of the old inline heredoc lets us `source` the shared warp-proxy.sh lib
# cleanly instead of duplicating its logic.
set -u
export DISPLAY="${DISPLAY:-:1}"
export XDG_CURRENT_DESKTOP="LXDE"
export DESKTOP_SESSION="LXDE"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/warp-proxy.sh
source "${SCRIPT_DIR}/lib/warp-proxy.sh"

log() {
  echo "[$(date -Is)] $*"
}

DESKTOP_DIR="$(xdg-user-dir DESKTOP 2>/dev/null || printf '%s/Desktop' "${HOME}")"
mkdir -p "${DESKTOP_DIR}" "${HOME}/.config/pcmanfm/default"

log "Starting optional WARP service (with real connectivity verification)"
warp_try_start

log "Waiting for X server on ${DISPLAY}"
X_READY=0
for _ in $(seq 1 30); do
  if xdpyinfo -display "${DISPLAY}" >/dev/null 2>&1 || xset -q -display "${DISPLAY}" >/dev/null 2>&1; then
    X_READY=1
    break
  fi
  sleep 1
done

if [ "${X_READY}" != "1" ]; then
  log "WARNING: X server did not become ready; shortcuts will still be created, but PCManFM desktop cannot be started in this environment"
fi

log "Ensuring Chrome desktop shortcuts exist"
CHROME_ICON="/opt/google/chrome/product_logo_48.png"
[ -f "${CHROME_ICON}" ] || CHROME_ICON="/usr/share/icons/hicolor/48x48/apps/google-chrome.png"
[ -f "${CHROME_ICON}" ] || CHROME_ICON="google-chrome"

# Always recomputed here, using the marker warp_try_start just verified -
# never trusted from a previous run.
CHROME_FLAGS="$(chrome_flags)"
if [ -f "${WARP_READY_MARKER}" ]; then
  log "Desktop shortcuts will route Chrome through the WARP SOCKS5 proxy"
else
  log "Desktop shortcuts will use a DIRECT connection (no working proxy detected)"
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

# Extra always-direct shortcut as a manual escape hatch, in case someone
# wants to bypass the proxy on purpose even when it IS working.
create_desktop_file "${DESKTOP_DIR}/Chrome-Direct.desktop" "Chrome (Direct, no proxy)" "Force a direct connection, bypassing WARP"

# IMPORTANT: re-sync the system-wide app menu AND the Fluxbox right-click
# menu on every start, using the freshly-verified flags above. setup.sh also
# writes both of these once at container creation time (before WARP has even
# attempted to connect), so without this re-sync either menu could stay
# pinned to stale/incorrect flags forever - meaning Chrome launched from
# there would silently bypass WARP even after it comes up successfully.
sudo -n cp "${DESKTOP_DIR}/"*.desktop /usr/share/applications/ 2>/dev/null || true
write_fluxbox_menu "${CHROME_FLAGS}" "${CHROME_ICON}"

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

if [ "${X_READY}" = "1" ]; then
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
