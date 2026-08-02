#!/bin/bash

nohup bash -c '
  export DISPLAY=:1

  # 1. Запуск службы WARP
  if command -v warp-svc >/dev/null 2>&1; then
    sudo warp-svc > /tmp/warp-svc.log 2>&1 &
    for i in {1..15}; do
      warp-cli --accept-tos status >/dev/null 2>&1 && break
      sleep 1
    done
    warp-cli --accept-tos registration new || true
    warp-cli --accept-tos mode proxy || true
    warp-cli --accept-tos connect || true
  fi

  # 2. Ожидание готовности X-сервера (:1)
  for i in {1..30}; do
    if xdpyinfo -display :1 >/dev/null 2>&1 || xset -q -display :1 >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done

  # 3. Очистка старых блокировок и конфликтующих процессов
  pkill -f nautilus || true
  rm -f ~/.config/pcmanfm/default/desktop-items-0.conf.lock

  # 4. Присвоение метаданных доверия GIO для ярлыков
  if command -v gio >/dev/null 2>&1; then
    for item in "$HOME/Desktop/"*.desktop; do
      if [ -f "$item" ]; then
        gio set -t string "$item" metadata::trusted true 2>/dev/null || true
      fi
    done
  fi

  # 5. Чистый запуск единого менеджера рабочего стола PCManFM
  if ! pgrep -f "pcmanfm --desktop" >/dev/null; then
    pcmanfm --desktop --profile=default > /tmp/pcmanfm.log 2>&1 &
  fi

  # 6. Обновление конфигурации Fluxbox
  if command -v fluxbox-remote >/dev/null 2>&1; then
    fluxbox-remote reconfigure || true
  fi
' > /tmp/desktop-startup.log 2>&1 &
