#!/bin/bash
#
# 00-pre-chroot.sh - Arch Linux T480s Pre-Chroot Setup
#
# Run this from the Arch Linux live USB environment.
# WARNING: This will wipe the target disk!
#

set -e  # Exit on error

#------------------------------------------------------------------------------
# CONFIGURATION - Edit these as needed
#------------------------------------------------------------------------------
DISK="/dev/nvme0n1"
TIMEZONE="Europe/Stockholm"
HOSTNAME="t480s"

#------------------------------------------------------------------------------
# Derived variables (don't edit)
#------------------------------------------------------------------------------
EFI_PART="${DISK}p1"
ROOT_PART="${DISK}p2"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

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

# Check we're in live environment
if [[ ! -d /run/archiso ]]; then
    warn "This doesn't look like an Arch live environment"
    read -p "Continue anyway? [y/N] " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]] || exit 1
fi

# Check disk exists
if [[ ! -b "$DISK" ]]; then
    error "Disk $DISK not found. Run 'lsblk' to see available disks."
fi

# Verify UEFI mode
if [[ ! -d /sys/firmware/efi ]]; then
    error "Not booted in UEFI mode. Check BIOS settings."
fi

# Final warning
warn "This will WIPE $DISK completely!"
echo "Partitions to be created:"
echo "  ${EFI_PART} - 1G EFI System Partition"
echo "  ${ROOT_PART} - Rest of disk (LUKS encrypted, btrfs)"
echo
read -p "Type 'yes' to continue: " confirm
[[ "$confirm" == "yes" ]] || exit 1

#------------------------------------------------------------------------------
# Update system clock
#------------------------------------------------------------------------------
info "Setting system clock"
timedatectl set-ntp true

#------------------------------------------------------------------------------
# Partition the disk
#------------------------------------------------------------------------------
info "Partitioning $DISK"

# Wipe existing partition table
wipefs -af "$DISK"

# Create GPT and partitions
parted -s "$DISK" mklabel gpt
parted -s "$DISK" mkpart "EFI" fat32 1MiB 1025MiB
parted -s "$DISK" set 1 esp on
parted -s "$DISK" mkpart "root" btrfs 1025MiB 100%

# Verify
echo "Partition table:"
parted -s "$DISK" print

#------------------------------------------------------------------------------
# Set up LUKS encryption
#------------------------------------------------------------------------------
info "Setting up LUKS encryption on $ROOT_PART"
echo "You will be prompted to enter your encryption passphrase."
echo

cryptsetup luksFormat "$ROOT_PART"

info "Opening encrypted partition"
cryptsetup open "$ROOT_PART" cryptroot

#------------------------------------------------------------------------------
# Format partitions
#------------------------------------------------------------------------------
info "Formatting EFI partition"
mkfs.fat -F32 "$EFI_PART"

info "Formatting root partition (btrfs)"
mkfs.btrfs /dev/mapper/cryptroot

#------------------------------------------------------------------------------
# Create btrfs subvolumes
#------------------------------------------------------------------------------
info "Creating btrfs subvolumes"

mount /dev/mapper/cryptroot /mnt

btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@snapshots
btrfs subvolume create /mnt/@var_log

umount /mnt

#------------------------------------------------------------------------------
# Mount filesystems
#------------------------------------------------------------------------------
info "Mounting filesystems"

# Mount root subvolume
mount -o subvol=@,compress=zstd,noatime /dev/mapper/cryptroot /mnt

# Create mount points
mkdir -p /mnt/{boot,home,.snapshots,var/log}

# Mount other subvolumes
mount -o subvol=@home,compress=zstd,noatime /dev/mapper/cryptroot /mnt/home
mount -o subvol=@snapshots,compress=zstd,noatime /dev/mapper/cryptroot /mnt/.snapshots
mount -o subvol=@var_log,compress=zstd,noatime /dev/mapper/cryptroot /mnt/var/log

# Mount EFI partition
mount "$EFI_PART" /mnt/boot

# Verify mounts
echo "Mount points:"
findmnt -R /mnt

#------------------------------------------------------------------------------
# Install base system
#------------------------------------------------------------------------------
info "Installing base system (this may take a while)"

# Install base first to create directory structure
pacstrap -K /mnt base

# Create vconsole.conf before kernel install (avoids mkinitcpio warning)
info "Creating vconsole.conf"
cat > /mnt/etc/vconsole.conf << EOF
KEYMAP=us
XKBLAYOUT=us
EOF

# Install remaining packages (kernels will now find vconsole.conf)
pacstrap /mnt \
    linux \
    linux-lts \
    linux-firmware \
    intel-ucode \
    btrfs-progs \
    networkmanager \
    plymouth \
    sudo \
    terminus-font \
    vim

#------------------------------------------------------------------------------
# Generate fstab
#------------------------------------------------------------------------------
info "Generating fstab"
genfstab -U /mnt >> /mnt/etc/fstab

echo "Generated fstab:"
cat /mnt/etc/fstab

#------------------------------------------------------------------------------
# Copy scripts to new system
#------------------------------------------------------------------------------
info "Copying installation scripts to new system"
mkdir -p /mnt/root/arch-setup
cp -r "$SCRIPT_DIR"/* /mnt/root/arch-setup/

#------------------------------------------------------------------------------
# Save configuration for next script
#------------------------------------------------------------------------------
cat > /mnt/root/arch-setup/.config << EOF
TIMEZONE="$TIMEZONE"
HOSTNAME="$HOSTNAME"
ROOT_PART="$ROOT_PART"
EOF

#------------------------------------------------------------------------------
# Done
#------------------------------------------------------------------------------
info "Pre-chroot setup complete!"
echo
echo "Next steps:"
echo "  1. arch-chroot /mnt"
echo "  2. cd /root/arch-setup"
echo "  3. chmod +x 01-chroot-setup.sh"
echo "  4. ./01-chroot-setup.sh"
echo
