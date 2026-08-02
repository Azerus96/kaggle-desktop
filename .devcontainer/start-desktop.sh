#!/bin/bash

# Запускаем всю логику в изолированном фоновом процессе, чтобы система не убила его
nohup bash -c '
  export DISPLAY=:1

  # Запуск демона WARP
  sudo warp-svc > /tmp/warp-svc.log 2>&1 &
  
  # Ожидание и подключение WARP
  for i in {1..30}; do
    warp-cli --accept-tos status >/dev/null 2>&1 && break
    sleep 1
  done
  warp-cli --accept-tos registration new
  warp-cli --accept-tos mode proxy
  warp-cli --accept-tos connect

  # Ожидание X-сервера
  for i in {1..30}; do
    if xdpyinfo -display :1 >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done

  # Убиваем мешающий Nautilus
  pkill -f nautilus

  # Запускаем оба менеджера рабочего стола для 100% гарантии
  pcmanfm --desktop > /tmp/pcmanfm.log 2>&1 &
  idesk > /tmp/idesk.log 2>&1 &
' > /tmp/desktop-startup.log 2>&1 &
