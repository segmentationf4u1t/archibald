#!/bin/bash
# Etap 5b: definicja VM "win11" (bez uruchamiania).
# Uruchomienie: sudo bash ~/gpu-setup/etap5b.sh [sciezka/do/Win11.iso]
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "Uruchom przez sudo"; exit 1; }
user=${SUDO_USER:?uruchom przez sudo}
home=$(getent passwd "$user" | cut -d: -f6)
img=/var/lib/libvirt/images
iso=$img/win11.iso
xml=$home/gpu-setup/win11.xml

echo "== 1. ISO Windowsa"
if [ ! -f "$iso" ]; then
  src=${1:-$(ls -t "$home"/Downloads/Win11*.iso "$home"/Downloads/*.iso 2>/dev/null | head -n1 || true)}
  [ -n "$src" ] && [ -f "$src" ] || { echo "Nie znalazlem ISO Windowsa w $home/Downloads"; exit 1; }
  echo "  przenosze $src -> $iso"
  mv "$src" "$iso"
fi
chown root:root "$iso"; chmod 644 "$iso"
echo "  SHA256 (porownaj z lista na stronie Microsoftu, sekcja 'Verify your download'):"
sha256sum "$iso" | awk '{print "  " toupper($1)}'

echo "== 2. Definicja VM"
virsh dominfo win11 >/dev/null 2>&1 && { echo "VM win11 juz istnieje, przerywam"; exit 1; }
virt-install --print-xml \
  --name win11 \
  --osinfo win11 \
  --uuid "$(tr 'A-F' 'a-f' < /sys/class/dmi/id/product_uuid)" \
  --sysinfo host \
  --machine q35 \
  --memory 32768 \
  --vcpus 12,sockets=1,dies=1,cores=6,threads=2 \
  --cpu host-passthrough,cache.mode=passthrough \
  --boot uefi,firmware.feature0.name=secure-boot,firmware.feature0.enabled=yes,firmware.feature1.name=enrolled-keys,firmware.feature1.enabled=no \
  --tpm backend.type=emulator,backend.version=2.0,model=tpm-crb \
  --import \
  --disk "$iso",device=cdrom,bus=sata,boot.order=1 \
  --disk "$img/virtio-win.iso",device=cdrom,bus=sata \
  --hostdev 02:00.0,boot.order=2 \
  --hostdev 01:00.0 \
  --hostdev 01:00.1 \
  --network network=default,model=e1000e \
  --graphics spice \
  --video qxl \
  --controller usb,model=qemu-xhci \
  > "$xml"
chown "$user": "$xml"
virsh define "$xml"

echo
echo "== KONTROLA"
d=$(virsh dumpxml win11)
grep -E "<uuid>|<smbios|<loader|<nvram|<tpm|model='tpm|<vcpu|<memory|<topology" <<<"$d" | sed 's/^ */  /'
echo "  urzadzenia PCI z hosta:"
grep -A4 "<hostdev mode='subsystem' type='pci'" <<<"$d" | grep -oE "bus='0x[0-9a-f]+' slot='0x[0-9a-f]+' function='0x[0-9a-f]+'|<boot order='[0-9]+'" | paste -sd' ' | sed 's/^/  /'
echo "  kolejnosc startu: $(grep -oE "<boot order='[0-9]+'" <<<"$d" | paste -sd' ')"
grep -oE "<hyperv mode='[a-z]+'|<timer name='hypervclock'[^/]*|<clock offset='[a-z]+'" <<<"$d" | sed 's/^/  /'
virsh list --all
echo
echo "== GOTOWE. XML: $xml"
