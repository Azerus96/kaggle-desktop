#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
nohup bash "${SCRIPT_DIR}/run-desktop.sh" >/tmp/desktop-startup.log 2>&1 &
disown
