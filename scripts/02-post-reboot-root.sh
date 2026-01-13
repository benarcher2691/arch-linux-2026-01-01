#!/bin/bash
#
# 02-post-reboot-root.sh - Arch Linux T480s Post-Reboot Root Setup
#
# Run this as root after first reboot.
#

set -e  # Exit on error

#------------------------------------------------------------------------------
# CONFIGURATION
#------------------------------------------------------------------------------
USERNAME="ben"

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

# Check network connectivity
if ! ping -c 1 archlinux.org &>/dev/null; then
    warn "No network connectivity detected"
    echo "Run 'nmtui' to connect to a network, then re-run this script"
    exit 1
fi

#------------------------------------------------------------------------------
# Install desktop packages
#------------------------------------------------------------------------------
info "Installing desktop packages"

pacman -S --needed \
    blueman \
    bluez \
    bluez-utils \
    brightnessctl \
    cups \
    fastfetch \
    fd \
    ghostty \
    git \
    github-cli \
    cage \
    greetd \
    grim \
    htop \
    hyprland \
    imagemagick \
    swww \
    jq \
    kitty \
    libreoffice-fresh \
    mako \
    network-manager-applet \
    neovim \
    noto-fonts \
    openssh \
    otf-font-awesome \
    pass \
    pavucontrol \
    pipewire \
    pipewire-alsa \
    pipewire-pulse \
    polkit \
    ripgrep \
    rofi-wayland \
    slurp \
    stow \
    thunar \
    tlp \
    tmux \
    ttf-dejavu \
    ttf-jetbrains-mono-nerd \
    ttf-liberation \
    unzip \
    waybar \
    wget \
    wireplumber \
    wl-clipboard \
    wtype \
    xdg-desktop-portal-hyprland \
    yazi \
    zip \
    base-devel

#------------------------------------------------------------------------------
# Create user account
#------------------------------------------------------------------------------
info "Creating user account: $USERNAME"

if id "$USERNAME" &>/dev/null; then
    warn "User $USERNAME already exists, skipping creation"
else
    useradd -m -G wheel,input -s /bin/bash "$USERNAME"
    echo "Set password for $USERNAME:"
    passwd "$USERNAME"
fi

#------------------------------------------------------------------------------
# Configure sudo
#------------------------------------------------------------------------------
info "Configuring sudo for wheel group"

# Uncomment wheel group in sudoers
if grep -q "^# %wheel ALL=(ALL:ALL) ALL" /etc/sudoers; then
    sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
    echo "Sudo configured for wheel group"
else
    echo "Wheel group already configured or sudoers has different format"
fi

#------------------------------------------------------------------------------
# Install yay (AUR helper)
#------------------------------------------------------------------------------
info "Installing yay (AUR helper)"

YAY_DIR="/tmp/yay-install"
rm -rf "$YAY_DIR"
mkdir -p "$YAY_DIR"

# Clone and build as the new user
sudo -u "$USERNAME" bash << EOF
cd "$YAY_DIR"
git clone https://aur.archlinux.org/yay-bin.git
cd yay-bin
makepkg -si --noconfirm
EOF

rm -rf "$YAY_DIR"

#------------------------------------------------------------------------------
# Install AUR packages (as user)
#------------------------------------------------------------------------------
info "Installing AUR packages"

sudo -u "$USERNAME" yay -S --noconfirm \
    greetd-regreet \
    localsend-bin

#------------------------------------------------------------------------------
# Enable services
#------------------------------------------------------------------------------
info "Enabling services"

systemctl enable bluetooth
systemctl enable cups
systemctl enable greetd
systemctl enable tlp

#------------------------------------------------------------------------------
# Configure greetd
#------------------------------------------------------------------------------
info "Configuring greetd"

cat > /etc/greetd/config.toml << EOF
[terminal]
vt = 7

[default_session]
command = "cage -s -- regreet"
user = "greeter"
EOF

echo "greetd configured to use regreet on VT 7"

#------------------------------------------------------------------------------
# Copy scripts to user home for next phase
#------------------------------------------------------------------------------
info "Copying scripts to user home directory"

USER_HOME="/home/$USERNAME"
mkdir -p "$USER_HOME/arch-setup"
cp -r "$SCRIPT_DIR"/* "$USER_HOME/arch-setup/"
chown -R "$USERNAME:$USERNAME" "$USER_HOME/arch-setup"

#------------------------------------------------------------------------------
# Done
#------------------------------------------------------------------------------
info "Root setup complete!"
echo
echo "Next steps:"
echo "  1. reboot"
echo "  2. Log in via regreet as '$USERNAME'"
echo "  3. Select 'Hyprland' as session"
echo "  4. Open terminal (SUPER+Return)"
echo "  5. cd ~/arch-setup && ./03-user-setup.sh"
echo
