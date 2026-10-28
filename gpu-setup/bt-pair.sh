#!/bin/bash
# Parowanie sluchawek Razer przez klasyczny Bluetooth (BR/EDR, A2DP).
# Sluchawki przechodza w tryb parowania same po wlaczeniu.
# Uruchomienie: bash ~/gpu-setup/bt-pair.sh [MAC]
set -u
mac=${1:-44:5E:CD:11:D6:F4}
bt() { timeout "${T:-15}" bluetoothctl "$@"; }

bt power on >/dev/null
bt pairable on >/dev/null
bt remove "$mac" >/dev/null 2>&1   # usun wpis z LE, zeby BlueZ nie parowal przez LE
echo ">>> Wylacz i wlacz sluchawki (po wlaczeniu same mowia 'pairing')."
bluetoothctl --timeout 180 scan bredr >/tmp/bt-scan.log 2>&1 &
scan=$!
trap 'kill $scan 2>/dev/null' EXIT

found=0
for _ in $(seq 1 120); do
  if bluetoothctl info "$mac" 2>/dev/null | grep -q 'Class:'; then found=1; break; fi
  sleep 1
done
if [ $found = 0 ]; then
  echo "Sluchawki nie pojawily sie przez klasyczny Bluetooth (BR/EDR) w 120 s."
  echo "Urzadzenia znalezione przez BR/EDR:"
  for d in $(bluetoothctl devices | awk '{print $2}'); do
    bluetoothctl info "$d" | grep -q 'Class:' && bluetoothctl devices | grep "$d"
  done
  exit 1
fi
bluetoothctl info "$mac" | grep -E 'Name|Class|Icon'
sleep 1

ok=0
for try in 1 2 3; do
  echo "-- proba parowania $try"
  if T=40 bt pair "$mac" | tee /tmp/bt-pair.log | grep -qiE 'Pairing successful|AlreadyExists'; then ok=1; break; fi
  tail -n 1 /tmp/bt-pair.log
  sleep 3
done
[ $ok = 1 ] || { echo "Parowanie nieudane."; exit 2; }

bt trust "$mac"
T=30 bt connect "$mac"
sleep 4
kill $scan 2>/dev/null
echo
bt info "$mac" | grep -E 'Name|Paired|Bonded|Trusted|Connected|Icon'
echo
echo "== Urzadzenia audio PipeWire"
timeout 5 wpctl status | sed -n '/^Audio/,/^Video/p' | grep -iE 'sinks:|sources:|razer|kraken|kitty|\*' | head -n 15
