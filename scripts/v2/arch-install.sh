#!/bin/bash
#
# Arch Linux Installation Script for Lenovo T480s
# Features: LUKS encryption, btrfs, Plymouth, Hyprland, Waybar
#
# Usage: Run from Arch ISO live environment
#   chmod +x arch-install.sh
#   ./arch-install.sh
#

set -e

# =============================================================================
# CONFIGURATION - Modify these variables as needed
# =============================================================================

DISK="/dev/nvme0n1"
HOSTNAME="t480s"
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
info "Hostname: ${HOSTNAME}"
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

info "Installing base system..."
pacstrap -K /mnt \
    base \
    base-devel \
    linux \
    linux-headers \
    linux-lts \
    linux-lts-headers \
    linux-firmware \
    intel-ucode \
    btrfs-progs \
    networkmanager \
    vim \
    nano \
    git \
    sudo \
    man-db \
    man-pages

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

cat << CHROOT_EOF | arch-chroot /mnt /bin/bash
set -e

# Timezone
ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
hwclock --systohc

# Locale
echo "${LOCALE} UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=${LOCALE}" > /etc/locale.conf
echo "KEYMAP=${KEYMAP}" > /etc/vconsole.conf

# Hostname
echo "${HOSTNAME}" > /etc/hostname
cat > /etc/hosts << EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME}.localdomain ${HOSTNAME}
EOF

# Install additional packages
pacman -S --noconfirm \
    ghostty \
    kitty \
    hyprland \
    waybar \
    xdg-desktop-portal-hyprland \
    xdg-desktop-portal-gtk \
    xdg-user-dirs \
    polkit-kde-agent \
    qt5-wayland \
    qt6-wayland \
    pipewire \
    pipewire-alsa \
    pipewire-pulse \
    pipewire-jack \
    wireplumber \
    wofi \
    mako \
    grim \
    slurp \
    wl-clipboard \
    brightnessctl \
    playerctl \
    ttf-font-awesome \
    ttf-jetbrains-mono-nerd \
    noto-fonts \
    noto-fonts-emoji \
    efibootmgr \
    dosfstools \
    gnupg \
    openssh \
    bluez \
    bluez-utils \
    cups \
    cups-pdf \
    snapper \
    snap-pac

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
    if [[ -f "\$f" ]]; then
        cp "\$f" /efi/
        echo "  Copied \$f"
    else
        echo "  WARNING: \$f not found!"
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

# Basic Hyprland config for user
mkdir -p /home/${USERNAME}/.config/hypr
cat > /home/${USERNAME}/.config/hypr/hyprland.conf << EOF
# Hyprland Configuration for Lenovo T480s

# Monitor configuration
monitor=,preferred,auto,1

# Execute at launch
exec-once = waybar
exec-once = mako
exec-once = /usr/lib/polkit-kde-authentication-agent-1

# Input configuration
input {
    kb_layout = ${KEYMAP}
    follow_mouse = 1
    touchpad {
        natural_scroll = true
        tap-to-click = true
    }
    sensitivity = 0
}

# General settings
general {
    gaps_in = 5
    gaps_out = 10
    border_size = 2
    col.active_border = rgba(33ccffee) rgba(00ff99ee) 45deg
    col.inactive_border = rgba(595959aa)
    layout = dwindle
}

# Decoration
decoration {
    rounding = 10
    blur {
        enabled = true
        size = 3
        passes = 1
    }
    shadow {
        enabled = true
        range = 4
        render_power = 3
        color = rgba(1a1a1aee)
    }
}

# Animations
animations {
    enabled = false
    bezier = myBezier, 0.05, 0.9, 0.1, 1.05
    animation = windows, 1, 7, myBezier
    animation = windowsOut, 1, 7, default, popin 80%
    animation = border, 1, 10, default
    animation = fade, 1, 7, default
    animation = workspaces, 1, 6, default
}

# Layouts
dwindle {
    pseudotile = true
    preserve_split = true
}

# Window rules
windowrulev2 = suppressevent maximize, class:.*

# Key bindings
\$mainMod = SUPER

bind = \$mainMod, Return, exec, kitty
bind = \$mainMod, Q, killactive,
bind = \$mainMod SHIFT, E, exit,
bind = \$mainMod, E, exec, thunar
bind = \$mainMod, V, togglefloating,
bind = \$mainMod, D, exec, wofi --show drun
bind = \$mainMod, P, pseudo,
bind = \$mainMod, J, togglesplit,
bind = \$mainMod, F, fullscreen,

# Move focus
bind = \$mainMod, left, movefocus, l
bind = \$mainMod, right, movefocus, r
bind = \$mainMod, up, movefocus, u
bind = \$mainMod, down, movefocus, d

# Switch workspaces
bind = \$mainMod, 1, workspace, 1
bind = \$mainMod, 2, workspace, 2
bind = \$mainMod, 3, workspace, 3
bind = \$mainMod, 4, workspace, 4
bind = \$mainMod, 5, workspace, 5
bind = \$mainMod, 6, workspace, 6
bind = \$mainMod, 7, workspace, 7
bind = \$mainMod, 8, workspace, 8
bind = \$mainMod, 9, workspace, 9
bind = \$mainMod, 0, workspace, 10

# Move active window to workspace
bind = \$mainMod SHIFT, 1, movetoworkspace, 1
bind = \$mainMod SHIFT, 2, movetoworkspace, 2
bind = \$mainMod SHIFT, 3, movetoworkspace, 3
bind = \$mainMod SHIFT, 4, movetoworkspace, 4
bind = \$mainMod SHIFT, 5, movetoworkspace, 5
bind = \$mainMod SHIFT, 6, movetoworkspace, 6
bind = \$mainMod SHIFT, 7, movetoworkspace, 7
bind = \$mainMod SHIFT, 8, movetoworkspace, 8
bind = \$mainMod SHIFT, 9, movetoworkspace, 9
bind = \$mainMod SHIFT, 0, movetoworkspace, 10

# Mouse bindings
bindm = \$mainMod, mouse:272, movewindow
bindm = \$mainMod, mouse:273, resizewindow

# Laptop multimedia keys
bind = , XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
bind = , XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bind = , XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
bind = , XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
bind = , XF86MonBrightnessUp, exec, brightnessctl s +5%
bind = , XF86MonBrightnessDown, exec, brightnessctl s 5%-
bind = , XF86AudioPlay, exec, playerctl play-pause
bind = , XF86AudioPrev, exec, playerctl previous
bind = , XF86AudioNext, exec, playerctl next

# Screenshot
bind = , Print, exec, grim - | wl-copy
bind = SHIFT, Print, exec, grim -g "\$(slurp)" - | wl-copy
EOF

# Waybar config
mkdir -p /home/${USERNAME}/.config/waybar
cat > /home/${USERNAME}/.config/waybar/config << EOF
{
    "layer": "top",
    "position": "top",
    "height": 30,
    "spacing": 4,

    "modules-left": ["hyprland/workspaces", "hyprland/window"],
    "modules-center": ["clock"],
    "modules-right": ["pulseaudio", "bluetooth", "network", "cpu", "memory", "backlight", "battery", "tray"],

    "hyprland/workspaces": {
        "format": "{icon}",
        "on-click": "activate"
    },

    "hyprland/window": {
        "max-length": 50
    },

    "clock": {
        "format": "{:%Y-%m-%d %H:%M}",
        "tooltip-format": "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>"
    },

    "cpu": {
        "format": " {usage}%",
        "tooltip": false
    },

    "memory": {
        "format": " {}%"
    },

    "backlight": {
        "format": "{icon} {percent}%",
        "format-icons": ["", "", "", "", "", "", "", "", ""]
    },

    "battery": {
        "states": {
            "warning": 30,
            "critical": 15
        },
        "format": "{icon} {capacity}%",
        "format-charging": " {capacity}%",
        "format-plugged": " {capacity}%",
        "format-icons": ["", "", "", "", ""]
    },

    "network": {
        "format-wifi": " {signalStrength}%",
        "format-ethernet": " {ipaddr}",
        "format-disconnected": "⚠ Disconnected",
        "tooltip-format": "{ifname}: {ipaddr}"
    },

    "bluetooth": {
        "format": " {status}",
        "format-connected": " {device_alias}",
        "format-connected-battery": " {device_alias} {device_battery_percentage}%",
        "tooltip-format": "{controller_alias}\t{controller_address}\n\n{num_connections} connected",
        "tooltip-format-connected": "{controller_alias}\t{controller_address}\n\n{num_connections} connected\n\n{device_enumerate}",
        "tooltip-format-enumerate-connected": "{device_alias}\t{device_address}",
        "tooltip-format-enumerate-connected-battery": "{device_alias}\t{device_address}\t{device_battery_percentage}%",
        "on-click": "blueman-manager"
    },

    "pulseaudio": {
        "format": "{icon} {volume}%",
        "format-muted": "",
        "format-icons": {
            "default": ["", "", ""]
        },
        "on-click": "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
    },

    "tray": {
        "spacing": 10
    }
}
EOF

cat > /home/${USERNAME}/.config/waybar/style.css << EOF
* {
    font-family: "JetBrainsMono Nerd Font", "Font Awesome 6 Free";
    font-size: 13px;
}

window#waybar {
    background-color: rgba(26, 27, 38, 0.9);
    color: #c0caf5;
    border-bottom: 2px solid rgba(122, 162, 247, 0.5);
}

#workspaces button {
    padding: 0 5px;
    color: #c0caf5;
    background-color: transparent;
    border-radius: 5px;
}

#workspaces button:hover {
    background: rgba(122, 162, 247, 0.2);
}

#workspaces button.active {
    background-color: #7aa2f7;
    color: #1a1b26;
}

#clock,
#battery,
#cpu,
#memory,
#network,
#pulseaudio,
#bluetooth,
#backlight,
#tray {
    padding: 0 10px;
    margin: 3px 2px;
    border-radius: 5px;
    background-color: rgba(122, 162, 247, 0.1);
}

#battery.charging, #battery.plugged {
    color: #9ece6a;
}

#battery.critical:not(.charging) {
    color: #f7768e;
    animation: blink 0.5s linear infinite alternate;
}

#bluetooth.connected {
    color: #7aa2f7;
}

@keyframes blink {
    to {
        color: #ff0000;
    }
}
EOF

# Fix ownership
chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.config

# Create post-install script for AUR packages (run as user after first boot)
cat > /home/${USERNAME}/post-install.sh << EOF
#!/bin/bash
set -e

echo "Installing yay (AUR helper)..."
cd /tmp
git clone https://aur.archlinux.org/yay-bin.git
cd yay-bin
makepkg -si --noconfirm
cd ~
rm -rf /tmp/yay-bin

echo "Installing AUR packages..."
yay -S --noconfirm brave-bin blueman

echo ""
echo "Post-installation complete!"
echo "You can now start Hyprland by typing: Hyprland"
rm -f ~/post-install.sh
EOF
chmod +x /home/${USERNAME}/post-install.sh
chown ${USERNAME}:${USERNAME} /home/${USERNAME}/post-install.sh

# Final verification
echo ""
echo "=== VERIFICATION ==="
echo "EFI partition contents:"
ls -la /efi/
echo ""
echo "Boot entries:"
ls -la /efi/loader/entries/
echo ""

CHROOT_EOF

# Set passwords (must be outside heredoc for interactive input)
info "Setting password for root..."
arch-chroot /mnt passwd

info "Setting password for ${USERNAME}..."
arch-chroot /mnt passwd ${USERNAME}

success "System configuration complete"

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
echo "  2. Reboot: ${YELLOW}reboot${NC}"
echo "  3. Enter your LUKS passphrase at boot"
echo "  4. Login as '${USERNAME}'"
echo "  5. Run the post-install script: ${YELLOW}./post-install.sh${NC}"
echo "     (This installs yay, Brave, and Blueman from AUR)"
echo "  6. Start Hyprland: ${YELLOW}Hyprland${NC}"
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
echo "     ${YELLOW}cryptsetup open /dev/nvme0n1p2 cryptroot${NC}"
echo "     ${YELLOW}mount -o subvol=@ /dev/mapper/cryptroot /mnt${NC}"
echo "     ${YELLOW}mount /dev/nvme0n1p1 /mnt/efi${NC}"
echo "     ${YELLOW}arch-chroot /mnt${NC}"
echo "     ${YELLOW}cp /boot/vmlinuz-linux /boot/initramfs-linux.img /boot/intel-ucode.img /efi/${NC}"
echo "     ${YELLOW}exit && reboot${NC}"
echo ""
