#!/bin/bash
#
# Arch Linux Minimal DevPod Installation Script
# Features: LUKS encryption, btrfs, Hyprland, Docker, DevPod
#
# Philosophy: Minimal host with Hyprland desktop, development in containers
#
# Usage: Run from Arch ISO live environment
#   mkdir -p /run/archusb
#   mount /dev/sdX1 /run/archusb
#   /run/archusb/arch-install-devpod.sh
#
set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

DISK="/dev/nvme0n1"
MYHOSTNAME="devpod"
USERNAME="ben"
TIMEZONE="Europe/Stockholm"
LOCALE="en_US.UTF-8"
KEYMAP="us"
EFI_SIZE="1G"

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
echo "║       Arch Linux DevPod Installation (Hyprland + Containers)     ║"
echo "║       LUKS + btrfs + Hyprland + Docker + DevPod                  ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

info "Target disk: ${DISK}"
info "Hostname: ${MYHOSTNAME}"
info "Username: ${USERNAME}"
echo ""

[[ $EUID -ne 0 ]] && error "This script must be run as root"
[[ ! -b "${DISK}" ]] && error "Disk ${DISK} not found"
[[ ! -d /sys/firmware/efi ]] && error "UEFI mode required"
ping -c 1 archlinux.org &>/dev/null || error "No internet connection"

PKG_CACHE="/run/archusb"
PKG_CACHE_TAR="${PKG_CACHE}/pkg-cache-devpod.tar"

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

EFI_PART="${DISK}p1"
CRYPT_PART="${DISK}p2"

success "Partitions created"

# =============================================================================
# LUKS ENCRYPTION
# =============================================================================

info "Setting up LUKS encryption..."
echo -e "${YELLOW}Enter a strong passphrase for disk encryption:${NC}"

cryptsetup luksFormat --type luks2 \
    --cipher aes-xts-plain64 \
    --key-size 512 \
    --hash sha512 \
    --pbkdf argon2id \
    --label cryptroot \
    "${CRYPT_PART}"

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
btrfs subvolume create /mnt/@docker

umount /mnt

info "Mounting filesystems..."
BTRFS_OPTS="noatime,compress=zstd:1,space_cache=v2,discard=async"

mount -o "${BTRFS_OPTS},subvol=@" /dev/mapper/cryptroot /mnt
mkdir -p /mnt/{home,.snapshots,var/log,var/cache,var/tmp,var/lib/docker,efi}

mount -o "${BTRFS_OPTS},subvol=@home" /dev/mapper/cryptroot /mnt/home
mount -o "${BTRFS_OPTS},subvol=@snapshots" /dev/mapper/cryptroot /mnt/.snapshots
mount -o "${BTRFS_OPTS},subvol=@var_log" /dev/mapper/cryptroot /mnt/var/log
mount -o "${BTRFS_OPTS},subvol=@var_cache" /dev/mapper/cryptroot /mnt/var/cache
mount -o "${BTRFS_OPTS},subvol=@var_tmp" /dev/mapper/cryptroot /mnt/var/tmp
mount -o "${BTRFS_OPTS},subvol=@docker" /dev/mapper/cryptroot /mnt/var/lib/docker
mount "${EFI_PART}" /mnt/efi

success "Filesystems mounted"

# =============================================================================
# BASE INSTALLATION
# =============================================================================

USE_CACHE=""
if [[ -f "${PKG_CACHE_TAR}" ]]; then
    info "Extracting cached packages..."
    mkdir -p /mnt/var/cache/pacman/pkg
    tar xf "${PKG_CACHE_TAR}" -C /mnt/var/cache/pacman/pkg/
    mkdir -p /var/cache/pacman
    rm -rf /var/cache/pacman/pkg
    ln -s /mnt/var/cache/pacman/pkg /var/cache/pacman/pkg
    success "Package cache ready"
    USE_CACHE="-c"
fi

info "Installing base system..."
pacstrap -K ${USE_CACHE} /mnt \
    base \
    base-devel \
    btrfs-progs \
    docker \
    git \
    intel-ucode \
    linux \
    linux-firmware \
    linux-headers \
    man-db \
    man-pages \
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

info "Configuring system..."
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

# Timezone & Locale
ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
hwclock --systohc
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

# Install packages: Hyprland desktop + tools for waybar + essentials
pacman -S --noconfirm \
    bluez \
    bluez-utils \
    brightnessctl \
    btop \
    dosfstools \
    efibootmgr \
    fd \
    fzf \
    ghostty \
    gnupg \
    grim \
    htop \
    hyprland \
    kitty \
    mako \
    network-manager-applet \
    noto-fonts \
    noto-fonts-emoji \
    openssh \
    pass \
    pipewire \
    pipewire-alsa \
    pipewire-jack \
    pipewire-pulse \
    playerctl \
    polkit-kde-agent \
    qt5-wayland \
    qt6-wayland \
    ripgrep \
    slurp \
    snap-pac \
    snapper \
    stow \
    thunar \
    ttf-font-awesome \
    ttf-jetbrains-mono-nerd \
    ufw \
    waybar \
    wireplumber \
    wl-clipboard \
    wofi \
    xdg-desktop-portal-gtk \
    xdg-desktop-portal-hyprland \
    xdg-user-dirs

# mkinitcpio for LUKS
cat > /etc/mkinitcpio.conf << EOF
MODULES=(i915)
BINARIES=()
FILES=()
HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole sd-encrypt block filesystems fsck)
EOF

# systemd-boot
bootctl install
mkdir -p /efi/loader/entries

cat > /efi/loader/loader.conf << EOF
default arch.conf
timeout 3
console-mode max
editor no
EOF

cat > /efi/loader/entries/arch.conf << EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux.img
options rd.luks.name=${LUKS_UUID}=cryptroot root=/dev/mapper/cryptroot rootflags=subvol=@ rw quiet
EOF

cat > /efi/loader/entries/arch-fallback.conf << EOF
title   Arch Linux (fallback)
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux-fallback.img
options rd.luks.name=${LUKS_UUID}=cryptroot root=/dev/mapper/cryptroot rootflags=subvol=@ rw
EOF

mkinitcpio -P

# Copy kernels to EFI
for f in /boot/vmlinuz-linux /boot/initramfs-linux.img \
         /boot/initramfs-linux-fallback.img /boot/intel-ucode.img; do
    [[ -f "$f" ]] && cp "$f" /efi/
done

# Pacman hook for kernel updates
mkdir -p /etc/pacman.d/hooks
cat > /etc/pacman.d/hooks/95-systemd-boot.hook << EOF
[Trigger]
Type = Package
Operation = Upgrade
Target = linux
Target = intel-ucode

[Action]
Description = Updating systemd-boot entries...
When = PostTransaction
Exec = /usr/bin/bash -c 'cp /boot/vmlinuz-linux /efi/ 2>/dev/null; cp /boot/initramfs-linux.img /efi/ 2>/dev/null; cp /boot/initramfs-linux-fallback.img /efi/ 2>/dev/null; cp /boot/intel-ucode.img /efi/ 2>/dev/null'
EOF

# Enable services
systemctl enable NetworkManager
systemctl enable systemd-boot-update
systemctl enable systemd-timesyncd
systemctl enable sshd
systemctl enable bluetooth
systemctl enable docker

# Create user (add to docker group)
useradd -m -G wheel,input,video,docker -s /bin/bash ${USERNAME}
echo "${USERNAME} ALL=(ALL:ALL) ALL" > /etc/sudoers.d/${USERNAME}

# Snapper config
umount /.snapshots 2>/dev/null || true
rm -rf /.snapshots
snapper --no-dbus -c root create-config /
btrfs subvolume delete /.snapshots 2>/dev/null || true
mkdir -p /.snapshots
mount -o noatime,compress=zstd:1,space_cache=v2,discard=async,subvol=@snapshots /dev/mapper/cryptroot /.snapshots
chmod 750 /.snapshots

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

systemctl enable snapper-timeline.timer
systemctl enable snapper-cleanup.timer

# NO SWAPFILE - breaks btrfs snapshots, use zram if needed

CHROOT_END

chmod +x /mnt/root/chroot-setup.sh
arch-chroot /mnt /root/chroot-setup.sh
rm /mnt/root/chroot-setup.sh

info "Setting password for root..."
arch-chroot /mnt passwd

info "Setting password for ${USERNAME}..."
arch-chroot /mnt passwd ${USERNAME}

success "System configuration complete"

# =============================================================================
# SAVE PACKAGE CACHE
# =============================================================================

if [[ -d "${PKG_CACHE}" ]] && mountpoint -q "${PKG_CACHE}"; then
    read -p "Save package cache to USB? [y/N]: " save_cache
    if [[ "${save_cache}" =~ ^[Yy]$ ]]; then
        info "Archiving packages to USB..."
        rm -f "${PKG_CACHE_TAR}"
        tar cf "${PKG_CACHE_TAR}" -C /mnt/var/cache/pacman/pkg .
        sync
        success "Package cache saved"
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
echo -e "${GREEN}║              DevPod Installation Complete!                        ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "  1. Reboot and enter LUKS passphrase"
echo "  2. Login as '${USERNAME}'"
echo "  3. Connect to WiFi: nmtui"
echo "  4. Follow README-devpod.md for post-install setup"
echo ""
echo -e "${BLUE}Installed:${NC}"
echo "  • LUKS2 encrypted root with btrfs"
echo "  • Hyprland + Waybar + PipeWire"
echo "  • Docker (ready for devcontainers)"
echo "  • Daily automatic snapshots (snapper)"
echo "  • SSH server enabled"
echo ""
echo -e "${YELLOW}Development languages/tools go in containers!${NC}"
echo ""
