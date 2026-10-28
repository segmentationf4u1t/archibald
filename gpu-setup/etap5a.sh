#!/bin/bash
# Etap 5a: QEMU/KVM + libvirt + virt-manager, siec NAT, ISO ze sterownikami virtio.
# Uruchomienie: sudo bash ~/gpu-setup/etap5a.sh
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "Uruchom przez sudo"; exit 1; }
user=${SUDO_USER:?uruchom przez sudo}

echo "== 1. Pakiety"
pacman -S --needed --noconfirm qemu-desktop libvirt virt-manager virt-install edk2-ovmf swtpm dnsmasq dmidecode

echo "== 2. libvirt: usluga, grupa libvirt dla $user, siec NAT 'default'"
systemctl enable --now libvirtd.service
usermod -aG libvirt "$user"
virsh net-autostart default
virsh net-info default | grep -qE '^Active:\s+yes' || virsh net-start default

echo "== 3. ISO ze sterownikami virtio dla Windowsa"
install -d /var/lib/libvirt/images
curl -fL --retry 3 --progress-bar -o /var/lib/libvirt/images/virtio-win.iso \
  https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso

echo
echo "== KONTROLA"
virsh version | head -n 3
virsh net-list --all
osinfo-query os | grep -iE 'win11|windows 11' | head -n 3
ls -lh /var/lib/libvirt/images/
id "$user"
virt-host-validate qemu 2>&1 | grep -vE ': PASS$' || true
echo
echo "== GOTOWE"
