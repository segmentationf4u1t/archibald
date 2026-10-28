#!/bin/bash
# Wi-Fi TP-Link Archer TX20U Plus: naprawa autostartu + test z odlaczeniem adaptera.
# Uruchomienie: sudo bash ~/gpu-setup/wifi-fix.sh
set -u
[ "$(id -u)" -eq 0 ] || { echo "Uruchom przez sudo"; exit 1; }

WIFI=2357:013f   # tryb Wi-Fi (sterownik rtw89_8852au)
CD=0bda:1a2b     # tryb "plyty CD" ze sterownikiem dla Windowsa, po kazdej utracie zasilania

find_dev() {
  local d
  for d in /sys/bus/usb/devices/*; do
    [ -f "$d/idVendor" ] || continue
    [ "$(cat "$d/idVendor"):$(cat "$d/idProduct")" = "$1" ] && { basename "$d"; return 0; }
  done
  return 1
}
wifi_connected() { nmcli -t -f TYPE,STATE device | grep -qx 'wifi:connected'; }
now() { date +%s; }

echo "== 1. usb_modeswitch i tcl z oficjalnego repo (podpisane), usbutils (lsusb)"
pacman -S --noconfirm usb_modeswitch tcl usbutils || { echo "pacman nie powiodl sie"; exit 1; }

echo "== 2. Profile Wi-Fi: usuwam przypisanie do nazwy interfejsu (zalezy od portu USB)"
mapfile -t profiles < <(nmcli -g NAME,TYPE connection show | awk -F: '$2=="802-11-wireless"{print $1}')
for c in "${profiles[@]}"; do
  nmcli connection modify "$c" connection.interface-name ""
  printf '  %s: interface-name="%s" autoconnect=%s\n' "$c" \
    "$(nmcli -g connection.interface-name connection show "$c")" \
    "$(nmcli -g connection.autoconnect connection show "$c")"
done

echo
echo "== 3. TEST. Internet zniknie na chwile."
echo ">>> ODLACZ adapter Wi-Fi z USB."
t=$(now)
while find_dev "$WIFI" >/dev/null || find_dev "$CD" >/dev/null; do
  sleep 0.5
  [ $(( $(now) - t )) -gt 180 ] && { echo "Adapter nie zostal odlaczony w 180 s, przerywam test."; exit 2; }
done
echo ">>> Odlaczony. PODLACZ go z powrotem, najlepiej do INNEGO portu niz przed chwila."
t=$(now)
until find_dev "$WIFI" >/dev/null || find_dev "$CD" >/dev/null; do
  sleep 0.2
  [ $(( $(now) - t )) -gt 300 ] && { echo "Adapter nie zostal podlaczony w 300 s."; exit 3; }
done
t0=$(now); since=$(date '+%Y-%m-%d %H:%M:%S' -d "@$((t0 - 2))")
switch_ok=1; nm_ok=1
if find_dev "$CD" >/dev/null; then echo "  0 s: widoczny jako $CD (tryb CD), czekam na usb_modeswitch"; fi

until find_dev "$WIFI" >/dev/null; do
  sleep 0.2
  if [ $(( $(now) - t0 )) -gt 45 ]; then
    switch_ok=0
    echo "  BLAD: brak automatycznego przelaczenia w 45 s, przelaczam recznie"
    usb_modeswitch -v 0x0bda -p 0x1a2b -K
    sleep 5
    break
  fi
done
find_dev "$WIFI" >/dev/null && echo "  $(( $(now) - t0 )) s: adapter w trybie Wi-Fi ($WIFI) na porcie $(find_dev "$WIFI")"

until wifi_connected; do
  sleep 0.5
  if [ $(( $(now) - t0 )) -gt 90 ]; then
    nm_ok=0
    echo "  BLAD: NetworkManager nie polaczyl sie sam w 90 s, lacze recznie"
    for c in "${profiles[@]}"; do nmcli connection up "$c" && break; done
    break
  fi
done
wifi_connected && echo "  $(( $(now) - t0 )) s: polaczono"

echo
echo "== Przebieg wg dziennika systemowego"
journalctl --since "$since" --no-pager -o short-precise |
  grep -iE 'usb_modeswitch|idVendor=|rtw89.*(firmware version|registered)|NetworkManager.*(device \(wl[^)]*\): state change: .* -> (activated|disconnected|unavailable)|policy: set .* \(wl)' |
  sed -E 's/^[A-Za-z]+ [0-9]+ //' | tail -n 30

echo
echo "== Stan koncowy"
nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device | grep ':wifi:'
ping -c 2 -W 3 archlinux.org >/dev/null 2>&1 && echo "internet: OK" || echo "internet: BRAK"
echo
if [ $switch_ok = 1 ] && [ $nm_ok = 1 ]; then
  echo ">>> WYNIK: OK - przelaczenie trybu i polaczenie zadzialaly automatycznie."
else
  echo ">>> WYNIK: BLAD - switch_ok=$switch_ok nm_ok=$nm_ok (szczegoly powyzej)."
fi
