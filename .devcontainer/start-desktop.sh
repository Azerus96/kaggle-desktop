#!/bin/bash

export DISPLAY=:1

# Запуск демона WARP в фоне
sudo warp-svc > /dev/null 2>&1 &

# Ожидание готовности демона WARP и подключение прокси
(
  for i in {1..30}; do
    warp-cli --accept-tos status >/dev/null 2>&1 && break
    sleep 1
  done
  warp-cli --accept-tos registration new
  warp-cli --accept-tos mode proxy
  warp-cli --accept-tos connect
) &

# Ждем, пока X-дисплей реально поднимется (до 30 секунд)
for i in {1..30}; do
  if xdpyinfo -display :1 >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

# Ждем, пока запустится сам fluxbox
for i in {1..30}; do
  pgrep -x fluxbox >/dev/null 2>&1 && break
  sleep 1
done

# Жестко убиваем nautilus, если он успел запуститься и захватить рабочий стол
pkill -f nautilus

# Запускаем pcmanfm для отрисовки наших ярлыков
pcmanfm --desktop &
