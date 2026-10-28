#!/bin/bash
# Etap 6 (host, root): Looking Glass B7-829-cdba29f2 - modul KVMFR, uprawnienia, libvirt, ISO z instalatorem IDD.
# Uruchomienie: sudo bash ~/gpu-setup/etap6.sh
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "Uruchom przez sudo"; exit 1; }
src=/home/segfault/src/looking-glass/looking-glass-B7-829-cdba29f2
zip=/home/segfault/src/looking-glass/looking-glass-idd-B7-829-cdba29f2.zip
ver=0.0.12
size_mb=64

echo "== 1. Pakiety do budowy klienta"
pacman -S --needed --noconfirm cmake ttf-dejavu

echo "== 2. Modul kvmfr $ver w DKMS (linux i linux-lts)"
dkms status -m kvmfr -v "$ver" | grep -q kvmfr || dkms add "$src/module"
for k in /usr/lib/modules/*/; do
  [ -f "$k/pkgbase" ] || continue
  dkms install "kvmfr/$ver" -k "$(basename "$k")"
done

echo "== 3. Konfiguracja modulu i uprawnienia /dev/kvmfr0"
echo "options kvmfr static_size_mb=$size_mb" > /etc/modprobe.d/kvmfr.conf
printf '# Looking Glass\nkvmfr\n' > /etc/modules-load.d/kvmfr.conf
echo 'SUBSYSTEM=="kvmfr", GROUP="kvm", MODE="0660", TAG+="uaccess"' > /etc/udev/rules.d/70-kvmfr.rules
udevadm control --reload
if [ -e /dev/kvmfr0 ] && [ ! -c /dev/kvmfr0 ]; then echo "BLAD: /dev/kvmfr0 jest zwyklym plikiem (VM wystartowala przed modulem)"; exit 1; fi
modprobe kvmfr
udevadm trigger --subsystem-match=kvmfr --action=add || true
sleep 1

echo "== 4. libvirt: /dev/kvmfr0 w cgroup_device_acl"
if ! grep -qE '^\s*cgroup_device_acl' /etc/libvirt/qemu.conf; then
  cat >> /etc/libvirt/qemu.conf <<'EOF'

# Looking Glass (KVMFR)
cgroup_device_acl = [
    "/dev/null", "/dev/full", "/dev/zero",
    "/dev/random", "/dev/urandom",
    "/dev/ptmx", "/dev/userfaultfd",
    "/dev/kvmfr0"
]
EOF
fi
systemctl restart libvirtd.service

echo "== 5. ISO z instalatorem IDD dla Windowsa"
tmp=$(mktemp -d)
unzip -q -o "$zip" -d "$tmp"
xorriso -as mkisofs -quiet -J -R -V LG_IDD -o /var/lib/libvirt/images/lg-idd.iso "$tmp"
rm -rf "$tmp"

echo
echo "== KONTROLA"
dkms status -m kvmfr
journalctl -k -b --no-pager -o cat | grep -m1 'kvmfr: creating' || true
ls -l /dev/kvmfr0
getfacl -p /dev/kvmfr0 2>/dev/null | grep -E '^(user|group):' || true
grep -A6 '^cgroup_device_acl' /etc/libvirt/qemu.conf | tr -s ' ' | paste -sd' '
systemctl is-active libvirtd
ls -l /var/lib/libvirt/images/lg-idd.iso
echo "== GOTOWE"
