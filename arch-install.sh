#!/bin/bash
#
# Arch Linux Installation Script for Lenovo T480s
# Features: LUKS encryption, btrfs, Plymouth, Hyprland, Waybar
#
# Usage: Run from Arch ISO live environment
#   mkdir -p /run/archusb
#   mount /dev/sdX1 /run/archusb      # Optional: mount USB with pkg-cache.tar
#   /run/archusb/arch-install.sh      # Or: bash /path/to/arch-install.sh
#
set -euo pipefail

# set -e

# =============================================================================
# CONFIGURATION - Modify these variables as needed
# =============================================================================

DISK="/dev/nvme0n1"
MYHOSTNAME="t480s"
USERNAME="ben"
TIMEZONE="Europe/Stockholm"
LOCALE="en_US.UTF-8"
KEYMAP="us"

# Partition sizes
EFI_SIZE="1G"
# Rest goes to root

# =============================================================================
# COLORS
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# =============================================================================
# PRE-FLIGHT CHECKS
# =============================================================================

echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║         Arch Linux Installation Script - Lenovo T480s            ║"
echo "║         LUKS + btrfs + Plymouth + Hyprland + Waybar              ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

info "Target disk: ${DISK}"
info "Hostname: ${MYHOSTNAME}"
info "Username: ${USERNAME}"
info "Timezone: ${TIMEZONE}"
echo ""

# Check if running as root
[[ $EUID -ne 0 ]] && error "This script must be run as root"

# Check if disk exists
[[ ! -b "${DISK}" ]] && error "Disk ${DISK} not found"

# Check for UEFI
[[ ! -d /sys/firmware/efi ]] && error "UEFI mode required. Please boot in UEFI mode."

# Check internet connection
ping -c 1 archlinux.org &>/dev/null || error "No internet connection"

# Package cache location (fixed path - user must mount USB here)
PKG_CACHE="/run/archusb"
PKG_CACHE_TAR="${PKG_CACHE}/pkg-cache.tar"

warn "This will ERASE ALL DATA on ${DISK}!"
read -p "Type 'YES' to continue: " confirm
[[ "${confirm}" != "YES" ]] && error "Aborted by user"

# =============================================================================
# DISK SETUP
# =============================================================================

info "Wiping disk signatures..."
wipefs -af "${DISK}"
sgdisk --zap-all "${DISK}"

info "Creating partitions..."
sgdisk --clear \
    --new=1:0:+${EFI_SIZE} --typecode=1:ef00 --change-name=1:EFI \
    --new=2:0:0 --typecode=2:8309 --change-name=2:cryptroot \
    "${DISK}"

partprobe "${DISK}"
sleep 2

# Partition variables
EFI_PART="${DISK}p1"
CRYPT_PART="${DISK}p2"

success "Partitions created"

# =============================================================================
# LUKS ENCRYPTION
# =============================================================================

info "Setting up LUKS encryption on ${CRYPT_PART}..."
echo ""
echo -e "${YELLOW}You will be prompted to enter a passphrase for disk encryption.${NC}"
echo -e "${YELLOW}Choose a strong passphrase and remember it!${NC}"
echo ""

cryptsetup luksFormat --type luks2 \
    --cipher aes-xts-plain64 \
    --key-size 512 \
    --hash sha512 \
    --pbkdf argon2id \
    --label cryptroot \
    "${CRYPT_PART}"

info "Opening LUKS container..."
cryptsetup open "${CRYPT_PART}" cryptroot

success "LUKS encryption configured"

# =============================================================================
# FILESYSTEM SETUP
# =============================================================================

info "Creating btrfs filesystem..."
mkfs.fat -F32 -n EFI "${EFI_PART}"
mkfs.btrfs -L archroot /dev/mapper/cryptroot

info "Creating btrfs subvolumes..."
mount /dev/mapper/cryptroot /mnt

btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@snapshots
btrfs subvolume create /mnt/@var_log
btrfs subvolume create /mnt/@var_cache
btrfs subvolume create /mnt/@var_tmp

umount /mnt

info "Mounting filesystems..."
BTRFS_OPTS="noatime,compress=zstd:1,space_cache=v2,discard=async"

mount -o "${BTRFS_OPTS},subvol=@" /dev/mapper/cryptroot /mnt

mkdir -p /mnt/{home,.snapshots,var/log,var/cache,var/tmp,efi}

mount -o "${BTRFS_OPTS},subvol=@home" /dev/mapper/cryptroot /mnt/home
mount -o "${BTRFS_OPTS},subvol=@snapshots" /dev/mapper/cryptroot /mnt/.snapshots
mount -o "${BTRFS_OPTS},subvol=@var_log" /dev/mapper/cryptroot /mnt/var/log
mount -o "${BTRFS_OPTS},subvol=@var_cache" /dev/mapper/cryptroot /mnt/var/cache
mount -o "${BTRFS_OPTS},subvol=@var_tmp" /dev/mapper/cryptroot /mnt/var/tmp

mount "${EFI_PART}" /mnt/efi

success "Filesystems mounted"

# =============================================================================
# BASE INSTALLATION
# =============================================================================

# Extract cached packages if available at fixed path
USE_CACHE=""
if [[ -f "${PKG_CACHE_TAR}" ]]; then
    info "Extracting cached packages from ${PKG_CACHE_TAR}..."
    # Extract to target cache (for chroot pacman -S)
    mkdir -p /mnt/var/cache/pacman/pkg
    tar xf "${PKG_CACHE_TAR}" -C /mnt/var/cache/pacman/pkg/
    # Symlink host cache to target cache (for pacstrap)
    mkdir -p /var/cache/pacman
    rm -rf /var/cache/pacman/pkg
    ln -s /mnt/var/cache/pacman/pkg /var/cache/pacman/pkg
    PKG_COUNT=$(ls /mnt/var/cache/pacman/pkg/*.pkg.tar.zst 2>/dev/null | wc -l)
    success "Package cache ready (${PKG_COUNT} packages)"
    USE_CACHE="-c"
else
    warn "No cache at ${PKG_CACHE_TAR} - will download packages"
    info "To use cache: mount USB to /run/archusb with pkg-cache.tar"
fi

info "Installing base system..."
pacstrap -K ${USE_CACHE} /mnt \
    base \
    base-devel \
    btrfs-progs \
    git \
    intel-ucode \
    linux \
    linux-firmware \
    linux-headers \
    linux-lts \
    linux-lts-headers \
    man-db \
    man-pages \
    nano \
    networkmanager \
    sudo \
    vim

success "Base system installed"

# =============================================================================
# FSTAB
# =============================================================================

info "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab
success "fstab generated"

# =============================================================================
# CHROOT CONFIGURATION
# =============================================================================

info "Configuring system in chroot..."

# Get LUKS UUID for bootloader
LUKS_UUID=$(blkid -s UUID -o value "${CRYPT_PART}")

# Create chroot setup script - first write variable definitions (unquoted heredoc expands them)
cat > /mnt/root/chroot-setup.sh << VARS_END
#!/bin/bash
set -e
# Variables injected from installer
TIMEZONE="${TIMEZONE}"
LOCALE="${LOCALE}"
KEYMAP="${KEYMAP}"
MYHOSTNAME="${MYHOSTNAME}"
USERNAME="${USERNAME}"
LUKS_UUID="${LUKS_UUID}"
VARS_END

# Append rest of script (quoted heredoc preserves nested heredocs and $vars)
cat >> /mnt/root/chroot-setup.sh << 'CHROOT_END'

# Timezone
ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
hwclock --systohc

# Locale
echo "${LOCALE} UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=${LOCALE}" > /etc/locale.conf
echo "KEYMAP=${KEYMAP}" > /etc/vconsole.conf

# Hostname
echo "${MYHOSTNAME}" > /etc/hostname
cat > /etc/hosts << EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${MYHOSTNAME}.localdomain ${MYHOSTNAME}
EOF

# Install additional packages
pacman -S --noconfirm \
    bluez \
    bluez-utils \
    brightnessctl \
    cups \
    cups-pdf \
    dosfstools \
    efibootmgr \
    exfatprogs \
    fd \
    fzf \
    ghostty \
    gnupg \
    grim \
    hyprland \
    kitty \
    mako \
    noto-fonts \
    network-manager-applet \
    noto-fonts-emoji \
    openssh \
    pipewire \
    pipewire-alsa \
    pipewire-jack \
    pipewire-pulse \
    playerctl \
    polkit-kde-agent \
    qt5-wayland \
    qt6-wayland \
    ripgrep \
    rofi \
    slurp \
    snap-pac \
    snapper \
    stow \
    terminus-font \
    thunar \
    ttf-font-awesome \
    ttf-jetbrains-mono-nerd \
    waybar \
    wireplumber \
    wl-clipboard \
    wofi \
    xdg-desktop-portal-gtk \
    xdg-desktop-portal-hyprland \
    xdg-user-dirs

# mkinitcpio configuration for LUKS
cat > /etc/mkinitcpio.conf << EOF
MODULES=(i915)
BINARIES=()
FILES=()
HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole sd-encrypt block filesystems fsck)
EOF

# Install systemd-boot
bootctl install

# Bootloader configuration
mkdir -p /efi/loader/entries

cat > /efi/loader/loader.conf << EOF
default arch.conf
timeout 3
console-mode max
editor no
EOF

# Main kernel entry
cat > /efi/loader/entries/arch.conf << EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux.img
options rd.luks.name=${LUKS_UUID}=cryptroot root=/dev/mapper/cryptroot rootflags=subvol=@ rw quiet
EOF

# Main kernel fallback
cat > /efi/loader/entries/arch-fallback.conf << EOF
title   Arch Linux (fallback)
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux-fallback.img
options rd.luks.name=${LUKS_UUID}=cryptroot root=/dev/mapper/cryptroot rootflags=subvol=@ rw
EOF

# LTS kernel entry
cat > /efi/loader/entries/arch-lts.conf << EOF
title   Arch Linux (LTS)
linux   /vmlinuz-linux-lts
initrd  /intel-ucode.img
initrd  /initramfs-linux-lts.img
options rd.luks.name=${LUKS_UUID}=cryptroot root=/dev/mapper/cryptroot rootflags=subvol=@ rw quiet
EOF

# LTS kernel fallback
cat > /efi/loader/entries/arch-lts-fallback.conf << EOF
title   Arch Linux (LTS fallback)
linux   /vmlinuz-linux-lts
initrd  /intel-ucode.img
initrd  /initramfs-linux-lts-fallback.img
options rd.luks.name=${LUKS_UUID}=cryptroot root=/dev/mapper/cryptroot rootflags=subvol=@ rw
EOF

# Regenerate initramfs FIRST
mkinitcpio -P

# Verify and copy kernels to EFI
echo "Copying kernels to EFI partition..."
for f in /boot/vmlinuz-linux /boot/vmlinuz-linux-lts /boot/initramfs-linux.img \
         /boot/initramfs-linux-fallback.img /boot/initramfs-linux-lts.img \
         /boot/initramfs-linux-lts-fallback.img /boot/intel-ucode.img; do
    if [[ -f "$f" ]]; then
        cp "$f" /efi/
        echo "  Copied $f"
    else
        echo "  WARNING: $f not found!"
    fi
done

# Verify files are on EFI
echo "Files on EFI partition:"
ls -la /efi/*.img /efi/vmlinuz-* 2>/dev/null || echo "WARNING: No kernel files found on /efi!"

# Pacman hook to update EFI on kernel updates
mkdir -p /etc/pacman.d/hooks
cat > /etc/pacman.d/hooks/95-systemd-boot.hook << EOF
[Trigger]
Type = Package
Operation = Upgrade
Target = linux
Target = linux-lts
Target = intel-ucode

[Action]
Description = Updating systemd-boot entries...
When = PostTransaction
Exec = /usr/bin/bash -c 'cp /boot/vmlinuz-linux /efi/ 2>/dev/null || true; cp /boot/vmlinuz-linux-lts /efi/ 2>/dev/null || true; cp /boot/initramfs-linux.img /efi/ 2>/dev/null || true; cp /boot/initramfs-linux-fallback.img /efi/ 2>/dev/null || true; cp /boot/initramfs-linux-lts.img /efi/ 2>/dev/null || true; cp /boot/initramfs-linux-lts-fallback.img /efi/ 2>/dev/null || true; cp /boot/intel-ucode.img /efi/ 2>/dev/null || true'
EOF

# Enable services
systemctl enable NetworkManager
systemctl enable systemd-boot-update
systemctl enable sshd
systemctl enable bluetooth
systemctl enable cups

# Create user with necessary groups
# - wheel: sudo access
# - input: direct input device access (for Hyprland/brightnessctl)
# - video: video device access
# - lp: printing
useradd -m -G wheel,input,video,lp -s /bin/bash ${USERNAME}
echo "${USERNAME} ALL=(ALL:ALL) ALL" > /etc/sudoers.d/${USERNAME}

# Configure snapper for root snapshots
umount /.snapshots 2>/dev/null || true
rm -rf /.snapshots
snapper --no-dbus -c root create-config /
btrfs subvolume delete /.snapshots 2>/dev/null || true
mkdir -p /.snapshots
mount -o noatime,compress=zstd:1,space_cache=v2,discard=async,subvol=@snapshots /dev/mapper/cryptroot /.snapshots
chmod 750 /.snapshots

# Snapper configuration for daily snapshots
cat > /etc/snapper/configs/root << EOF
SUBVOLUME="/"
FSTYPE="btrfs"
QGROUP=""
SPACE_LIMIT="0.5"
FREE_LIMIT="0.2"
ALLOW_USERS="${USERNAME}"
ALLOW_GROUPS=""
SYNC_ACL="no"
BACKGROUND_COMPARISON="yes"
NUMBER_CLEANUP="yes"
NUMBER_MIN_AGE="1800"
NUMBER_LIMIT="50"
NUMBER_LIMIT_IMPORTANT="10"
TIMELINE_CREATE="yes"
TIMELINE_CLEANUP="yes"
TIMELINE_MIN_AGE="1800"
TIMELINE_LIMIT_HOURLY="5"
TIMELINE_LIMIT_DAILY="7"
TIMELINE_LIMIT_WEEKLY="0"
TIMELINE_LIMIT_MONTHLY="0"
TIMELINE_LIMIT_YEARLY="0"
EMPTY_PRE_POST_CLEANUP="yes"
EMPTY_PRE_POST_MIN_AGE="1800"
EOF

# Enable snapper timers
systemctl enable snapper-timeline.timer
systemctl enable snapper-cleanup.timer


# Final verification
echo ""
echo "=== VERIFICATION ==="
echo "EFI partition contents:"
ls -la /efi/
echo ""
echo "Boot entries:"
ls -la /efi/loader/entries/
echo ""

CHROOT_END

# Make script executable and run it
chmod +x /mnt/root/chroot-setup.sh
arch-chroot /mnt /root/chroot-setup.sh
rm /mnt/root/chroot-setup.sh

# Set passwords (must be outside heredoc for interactive input)
info "Setting password for root..."
arch-chroot /mnt passwd

info "Setting password for ${USERNAME}..."
arch-chroot /mnt passwd ${USERNAME}

success "System configuration complete"

# =============================================================================
# SAVE PACKAGE CACHE (optional)
# =============================================================================

if [[ -d "${PKG_CACHE}" ]] && mountpoint -q "${PKG_CACHE}"; then
    echo ""
    info "USB detected at ${PKG_CACHE}"
    read -p "Save package cache to USB for future installs? [y/N]: " save_cache
    if [[ "${save_cache}" =~ ^[Yy]$ ]]; then
        PKG_COUNT=$(ls /mnt/var/cache/pacman/pkg/*.pkg.tar.zst 2>/dev/null | wc -l)
        info "Archiving ${PKG_COUNT} packages to USB (be patient, USB is slow)..."
        rm -f "${PKG_CACHE_TAR}"
        tar cvf "${PKG_CACHE_TAR}" -C /mnt/var/cache/pacman/pkg . 2>&1 | \
            awk 'NR % 50 == 0 { printf "  %d files...\n", NR } END { printf "  %d files total\n", NR }'
        info "Syncing to USB (may take 1-2 minutes)..."
        sync
        success "Package cache saved to ${PKG_CACHE_TAR}"
    fi
fi

# =============================================================================
# CLEANUP
# =============================================================================

info "Unmounting filesystems..."
umount -R /mnt
cryptsetup close cryptroot

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    Installation Complete!                         ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "  1. Remove the USB installation media"
echo -e "  2. Reboot: ${YELLOW}reboot${NC}"
echo "  3. Enter your LUKS passphrase at boot"
echo "  4. Login as '${USERNAME}'"
echo "  5. Stow dotfiles and install AUR packages (see README)"
echo -e "  6. Start Hyprland: ${YELLOW}start-hyprland${NC}"
echo ""
echo -e "${BLUE}Key bindings (in Hyprland):${NC}"
echo "  SUPER + Enter     - Terminal (kitty)"
echo "  SUPER + D         - Application launcher (wofi)"
echo "  SUPER + Q         - Close window"
echo "  SUPER + 1-0       - Switch workspace"
echo "  SUPER + SHIFT + E - Exit Hyprland"
echo ""
echo -e "${BLUE}Installed features:${NC}"
echo "  • LUKS2 encrypted root with btrfs"
echo "  • Daily automatic snapshots (snapper)"
echo "  • Bluetooth support (use blueman-manager)"
echo "  • Printing support (CUPS at http://localhost:631)"
echo "  • SSH server enabled"
echo "  • LTS kernel available in boot menu"
echo ""
echo -e "${YELLOW}Tip: Configure WiFi after reboot with: nmtui${NC}"
echo ""
echo -e "${BLUE}Troubleshooting - If boot fails with 'initrd not found':${NC}"
echo "  1. Boot back into Arch ISO"
echo "  2. Run these commands:"
echo -e "     ${YELLOW}cryptsetup open /dev/nvme0n1p2 cryptroot${NC}"
echo -e "     ${YELLOW}mount -o subvol=@ /dev/mapper/cryptroot /mnt${NC}"
echo -e "     ${YELLOW}mount /dev/nvme0n1p1 /mnt/efi${NC}"
echo -e "     ${YELLOW}arch-chroot /mnt${NC}"
echo -e "     ${YELLOW}cp /boot/vmlinuz-linux /boot/initramfs-linux.img /boot/intel-ucode.img /efi/${NC}"
echo -e "     ${YELLOW}exit && reboot${NC}"
echo ""
