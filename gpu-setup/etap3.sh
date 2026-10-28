#!/bin/bash
# Etap 3: sterownik NVIDIA 580xx dla Quadro P400 + porzadki w Hyprlandzie.
# Uruchomienie: sudo bash ~/gpu-setup/etap3.sh
set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "Uruchom przez sudo"; exit 1; }
user=${SUDO_USER:?uruchom przez sudo, nie jako root}
home=$(getent passwd "$user" | cut -d: -f6)
pkgdir=$home/aur/nvidia-580xx-utils
ver=580.196.07-1

echo "== 1. Naglowki kerneli, DKMS, Thunar, agent polkit"
pacman -Syu --needed --noconfirm dkms linux-headers linux-lts-headers thunar hyprpolkitagent

echo "== 2. Sterownik NVIDIA 580xx (DKMS buduje modul dla linux i linux-lts)"
pacman -U --needed --noconfirm \
  "$pkgdir/nvidia-580xx-utils-$ver-x86_64.pkg.tar.zst" \
  "$pkgdir/nvidia-580xx-dkms-$ver-x86_64.pkg.tar.zst"

echo "== 3. Usuwam programy z KDE (dolphin, polkit-kde-agent)"
for p in dolphin polkit-kde-agent; do
  if pacman -Q "$p" >/dev/null 2>&1; then pacman -Rns --noconfirm "$p"; fi
done

echo "== 4. Wczesne KMS: moduly nvidia w initramfs, bez hooka kms (nouveau)"
install -d /etc/mkinitcpio.conf.d
cat > /etc/mkinitcpio.conf.d/gpu.conf <<'EOF'
# Etap 3 (P400 na nvidia-580xx). Etap 4 dopisze tu moduly vfio przed nvidia.
MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
HOOKS=(base udev autodetect microcode modconf keyboard keymap consolefont block filesystems fsck)
EOF
mkinitcpio -P

echo "== 5. GRUB: domyslnie kernel linux, linux-lts jako zapasowy"
if ! grep -q '^GRUB_TOP_LEVEL=' /etc/default/grub; then
  printf '\nGRUB_TOP_LEVEL="/boot/vmlinuz-linux"\n' >> /etc/default/grub
fi
grub-mkconfig -o /boot/grub/grub.cfg

echo
echo "== KONTROLA"
dkms status
for k in /usr/lib/modules/*/; do
  kv=$(basename "$k")
  [ -f "$k/vmlinuz" ] || continue
  printf '%s: ' "$kv"
  if [ -e "$k/updates/dkms/nvidia.ko.zst" ] || [ -e "$k/updates/dkms/nvidia.ko" ]; then echo -n "modul nvidia OK; "; else echo -n "BRAK modulu nvidia; "; fi
  img=/boot/initramfs-$(cat "$k/pkgbase").img
  if lsinitcpio "$img" | grep -E '/nvidia-drm\.ko' >/dev/null; then echo "initramfs OK"; else echo "BRAK nvidia w $img"; fi
done
grep -E "^\s*(menuentry|submenu) '" /boot/grub/grub.cfg | cut -d"'" -f2 | head -n 6
echo
echo "== GOTOWE. Uruchom ponownie komputer: reboot"
