#!/usr/bin/env bash
# Shared helpers for configuring the desktop's browser proxy.
#
# Sourced by setup.sh and run-desktop.sh so both scripts always agree on
# whether Chrome should go through the Cloudflare WARP SOCKS5 proxy.
#
# KEY FIX vs the original scripts: we never *assume* the proxy is up just
# because `warp-cli connect` returned success. We prove it by making a real
# request through the proxy. If that fails for any reason (WARP not
# installed, no NET_ADMIN/tun device, no registration, transient network
# issue, etc.) Chrome silently falls back to a direct connection instead of
# being pointed at a dead port (which is what caused ERR_PROXY_CONNECTION_FAILED).

WARP_SOCKS_HOST="127.0.0.1"
WARP_SOCKS_PORT="40000"
WARP_READY_MARKER="/tmp/.warp-proxy-ready"

warp_log() {
  echo "[$(date -Is)] $*"
}

# Attempt to bring up Cloudflare WARP in SOCKS5 proxy mode.
# This function NEVER fails the calling script (no `set -e` propagation
# issue) - WARP is always treated as optional.
warp_try_start() {
  rm -f "${WARP_READY_MARKER}"

  if ! command -v warp-svc >/dev/null 2>&1; then
    warp_log "WARP: client not installed - Chrome will use a direct connection"
    return 0
  fi

  if [ ! -e /dev/net/tun ]; then
    warp_log "WARP: /dev/net/tun is not available in this container."
    warp_log "WARP: add capAdd: [\"NET_ADMIN\"] and mounts: [\"source=/dev/net/tun,target=/dev/net/tun,type=bind\"] to devcontainer.json to enable the tunnel."
    warp_log "WARP: falling back to a direct connection for now."
    return 0
  fi

  if ! pgrep -x warp-svc >/dev/null 2>&1; then
    sudo -n warp-svc >/tmp/warp-svc.log 2>&1 &
  fi

  local i
  for i in $(seq 1 15); do
    warp-cli --accept-tos status >/dev/null 2>&1 && break
    sleep 1
  done

  # Support both the current warp-cli syntax and the legacy one from older
  # client versions, in case an older cloudflare-warp package gets installed
  # (e.g. via the jammy fallback repo above).
  warp-cli --accept-tos registration new                >/tmp/warp-register.log 2>&1 \
    || warp-cli --accept-tos register                   >>/tmp/warp-register.log 2>&1 || true
  warp-cli --accept-tos mode proxy                       >/tmp/warp-mode.log     2>&1 \
    || warp-cli --accept-tos set-mode proxy              >>/tmp/warp-mode.log    2>&1 || true
  warp-cli --accept-tos proxy port "${WARP_SOCKS_PORT}"  >/tmp/warp-port.log     2>&1 || true
  warp-cli --accept-tos connect                          >/tmp/warp-connect.log  2>&1 || true

  # Don't trust warp-cli's exit code - prove traffic actually flows through
  # the proxy before we ever tell Chrome to depend on it.
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
  return 0
}

# Prints the Chrome flag string appropriate for the CURRENT proxy state.
# Call this fresh every time you need it - do not cache the result, since
# proxy availability can change between container starts.
chrome_flags() {
  local flags="--no-sandbox --disable-dev-shm-usage --disable-gpu --password-store=basic"

  if [ -f "${WARP_READY_MARKER}" ]; then
    flags="${flags} --proxy-server=socks5://${WARP_SOCKS_HOST}:${WARP_SOCKS_PORT}"
  fi

  local ext_dir="${HOME}/.config/chrome-extensions/canvas-defender"
  if [ -f "${ext_dir}/manifest.json" ]; then
    flags="${flags} --load-extension=${ext_dir}"
  fi

  echo "${flags}"
}

# Writes ~/.fluxbox/menu (the right-click desktop menu) with the SAME
# Chrome flags used for the desktop icons and the app menu. This used to be
# duplicated inline in setup.sh only, which meant right-click > Chrome could
# silently launch a direct (non-proxied) connection even when WARP was
# confirmed working - a real traffic-leak vector for a setup that pairs WARP
# with Canvas Defender. Call this every time chrome_flags() is recomputed.
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
