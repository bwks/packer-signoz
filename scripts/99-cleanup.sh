#!/usr/bin/env bash
# Prepare the image for cloning:
#   - Lock the build-time ubuntu password
#   - Remove SSH host keys (regenerated at first boot)
#   - Reset cloud-init so it runs again on first boot
#   - Zero out free space so qemu-img convert can produce a sparse image
set -euo pipefail

echo "==> Locking build-time ubuntu password"
passwd -l ubuntu

echo "==> Removing SSH host keys"
rm -f /etc/ssh/ssh_host_*

echo "==> Cleaning package cache"
apt-get clean -y
apt-get autoremove -y --purge

echo "==> Removing temporary build artifacts"
rm -rf /tmp/packer

echo "==> Truncating logs"
find /var/log -type f | while IFS= read -r f; do
  truncate -s 0 "${f}" 2>/dev/null || true
done

echo "==> Resetting machine-id (will be regenerated at first boot)"
truncate -s 0 /etc/machine-id
rm -f /var/lib/dbus/machine-id
ln -sf /etc/machine-id /var/lib/dbus/machine-id

echo "==> Resetting cloud-init"
cloud-init clean --logs

echo "==> Zeroing free space (enables sparse qcow2 after conversion)"
# fstrim is preferred on VMs; fall back to dd if unavailable
if fstrim -v / 2>/dev/null; then
  echo "    fstrim succeeded"
else
  echo "    fstrim unavailable, using dd fallback"
  dd if=/dev/zero of=/tmp/zeros bs=4M 2>/dev/null || true
  rm -f /tmp/zeros
fi
sync

echo "==> Cleanup complete — image is ready for sparsification"
