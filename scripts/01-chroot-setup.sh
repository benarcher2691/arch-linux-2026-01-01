#!/bin/bash
#
# 01-chroot-setup.sh - Arch Linux T480s Chroot Configuration
#
# Run this inside arch-chroot after 00-pre-chroot.sh
#

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

#------------------------------------------------------------------------------
# Load configuration from previous script
#------------------------------------------------------------------------------
if [[ -f "$SCRIPT_DIR/.config" ]]; then
    source "$SCRIPT_DIR/.config"
else
    # Defaults if config not found
    TIMEZONE="Europe/Stockholm"
    HOSTNAME="t480s"
    ROOT_PART="/dev/nvme0n1p2"
fi

#------------------------------------------------------------------------------
# Helper functions
#------------------------------------------------------------------------------
info() {
    echo -e "\n\033[1;34m==>\033[0m \033[1m$1\033[0m"
}

warn() {
    echo -e "\n\033[1;33m==> WARNING:\033[0m $1"
}

error() {
    echo -e "\n\033[1;31m==> ERROR:\033[0m $1"
    exit 1
}

#------------------------------------------------------------------------------
# Pre-flight checks
#------------------------------------------------------------------------------
info "Pre-flight checks"

# Must be root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root"
fi

# Should be in chroot
if ! systemd-detect-virt --chroot > /dev/null 2>&1; then
    error "This script should be run inside arch-chroot, not in the live environment"
fi

#------------------------------------------------------------------------------
# Set timezone
#------------------------------------------------------------------------------
info "Setting timezone to $TIMEZONE"
ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
hwclock --systohc

#------------------------------------------------------------------------------
# Localization
#------------------------------------------------------------------------------
info "Configuring locale"

# Enable en_US.UTF-8
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen

# Set system locale
echo "LANG=en_US.UTF-8" > /etc/locale.conf

#------------------------------------------------------------------------------
# Console configuration
#------------------------------------------------------------------------------
info "Configuring console"
cat > /etc/vconsole.conf << EOF
KEYMAP=us
XKBLAYOUT=us
EOF

#------------------------------------------------------------------------------
# Network configuration
#------------------------------------------------------------------------------
info "Configuring network"

echo "$HOSTNAME" > /etc/hostname

cat > /etc/hosts << EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME
EOF

#------------------------------------------------------------------------------
# Configure mkinitcpio for encryption + plymouth
#------------------------------------------------------------------------------
info "Configuring mkinitcpio"

# Backup original
cp /etc/mkinitcpio.conf /etc/mkinitcpio.conf.bak

# Set HOOKS for systemd-based initramfs with encryption (no plymouth for initial setup)
sed -i 's/^HOOKS=.*/HOOKS=(base systemd autodetect microcode modconf kms keyboard keymap sd-vconsole block sd-encrypt filesystems fsck)/' /etc/mkinitcpio.conf

# Regenerate initramfs
mkinitcpio -P

#------------------------------------------------------------------------------
# Set root password (required for first boot)
#------------------------------------------------------------------------------
info "Set root password"
echo "You MUST set a root password to be able to log in after reboot."
while ! passwd; do
    warn "Password setting failed. Please try again."
done
echo "Root password set successfully."
sleep 1

#------------------------------------------------------------------------------
# Enable NetworkManager
#------------------------------------------------------------------------------
info "Enabling NetworkManager"
systemctl enable NetworkManager

#------------------------------------------------------------------------------
# Install bootloader
#------------------------------------------------------------------------------
info "Installing systemd-boot"
bootctl install

# Fix /boot permissions (suppress world-accessible warnings)
chmod 700 /boot

#------------------------------------------------------------------------------
# Get UUID for boot entries
#------------------------------------------------------------------------------
info "Configuring boot entries"

ROOT_UUID=$(blkid -s UUID -o value "$ROOT_PART")
if [[ -z "$ROOT_UUID" ]]; then
    error "Could not determine UUID of $ROOT_PART"
fi

echo "Root partition UUID: $ROOT_UUID"

#------------------------------------------------------------------------------
# Create boot entries
#------------------------------------------------------------------------------
# Main kernel
cat > /boot/loader/entries/arch.conf << EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux.img
options rd.luks.name=$ROOT_UUID=cryptroot root=/dev/mapper/cryptroot rw
EOF

# LTS kernel (fallback/debug - no quiet)
cat > /boot/loader/entries/arch-lts.conf << EOF
title   Arch Linux (LTS)
linux   /vmlinuz-linux-lts
initrd  /intel-ucode.img
initrd  /initramfs-linux-lts.img
options rd.luks.name=$ROOT_UUID=cryptroot root=/dev/mapper/cryptroot rw
EOF

# Loader configuration
cat > /boot/loader/loader.conf << EOF
default arch.conf
timeout 3
console-mode max
editor no
EOF

echo "Boot entries created:"
ls -la /boot/loader/entries/

#------------------------------------------------------------------------------
# Done
#------------------------------------------------------------------------------
info "Chroot setup complete!"
echo
echo "Next steps:"
echo "  1. exit"
echo "  2. umount -R /mnt"
echo "  3. reboot"
echo
echo "After reboot:"
echo "  - Enter LUKS passphrase"
echo "  - Log in as root"
echo "  - Run: cd /root/arch-setup && ./02-post-reboot-root.sh"
echo
