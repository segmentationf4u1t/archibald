#!/bin/bash
# Etap 4: RTX 4070 (01:00.0) i jej audio (01:00.1) do vfio-pci, IOMMU wlaczone.
# Uruchomienie: sudo bash ~/gpu-setup/etap4.sh   (potem reboot)
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "Uruchom przez sudo"; exit 1; }

IDS=10de:2786,10de:22bc

echo "== 1. modprobe: vfio-pci przejmuje 4070 i jej audio przed nvidia i snd_hda_intel"
cat > /etc/modprobe.d/vfio.conf <<EOF
# Etap 4: RTX 4070 + HDMI audio dla VM
options vfio-pci ids=$IDS
softdep nvidia pre: vfio-pci
softdep snd_hda_intel pre: vfio-pci
EOF
cat /etc/modprobe.d/vfio.conf

echo "== 2. initramfs: vfio ladowane przed nvidia"
cat > /etc/mkinitcpio.conf.d/gpu.conf <<'EOF'
# Etap 4: vfio-pci musi przejac RTX 4070, zanim zaladuje sie nvidia (P400).
MODULES=(vfio_pci vfio vfio_iommu_type1 nvidia nvidia_modeset nvidia_uvm nvidia_drm)
HOOKS=(base udev autodetect microcode modconf keyboard keymap consolefont block filesystems fsck)
EOF
mkinitcpio -P

echo "== 3. GRUB: intel_iommu=on iommu=pt"
if ! grep -q '^GRUB_CMDLINE_LINUX=".*intel_iommu=on' /etc/default/grub; then
  sed -i -E 's/^(GRUB_CMDLINE_LINUX="[^"]*)"/\1 intel_iommu=on iommu=pt"/' /etc/default/grub
fi
grep '^GRUB_CMDLINE_LINUX=' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

echo
echo "== KONTROLA"
for img in /boot/initramfs-linux.img /boot/initramfs-linux-lts.img; do
  list=$(lsinitcpio "$img")
  printf '%s:' "$img"
  for m in vfio-pci vfio-pci-core vfio vfio_iommu_type1 nvidia nvidia-drm; do
    if grep -qE "/$m\.ko" <<<"$list"; then printf ' %s' "$m"; else printf ' BRAK:%s' "$m"; fi
  done
  if grep -q 'etc/modprobe.d/vfio.conf' <<<"$list"; then echo ' | vfio.conf OK'; else echo ' | BRAK vfio.conf'; fi
done
echo "wpisy GRUB z intel_iommu=on: $(grep -c 'intel_iommu=on iommu=pt' /boot/grub/grub.cfg)"
echo
echo "== GOTOWE. Zrestartuj komputer: reboot"
