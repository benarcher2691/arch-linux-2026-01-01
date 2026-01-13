#!/bin/bash
#
# 03-user-setup.sh - Arch Linux T480s User Setup
#
# Run this as your user after logging in via regreet.
#

set -e  # Exit on error

#------------------------------------------------------------------------------
# CONFIGURATION
#------------------------------------------------------------------------------
DOTFILES_REPO="git@github.com:benarcher2691/dotfiles_arch_2026.git"
PASS_REPO="git@github.com:benarcher2691/pass-store.git"

# Where LocalSend saves received files (check LocalSend settings)
LOCALSEND_DIR="$HOME"

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

success() {
    echo -e "\033[1;32m✓\033[0m $1"
}

#------------------------------------------------------------------------------
# Pre-flight checks
#------------------------------------------------------------------------------
info "Pre-flight checks"

# Should NOT be root
if [[ $EUID -eq 0 ]]; then
    error "This script should be run as your regular user, not root"
fi

# Check network
if ! ping -c 1 github.com &>/dev/null; then
    warn "No network connectivity detected"
    echo "Connect to network first (use nm-applet in system tray or nmtui)"
    exit 1
fi

#------------------------------------------------------------------------------
# Key Transfer via LocalSend
#------------------------------------------------------------------------------
info "SSH and GPG Key Transfer"

echo
echo "This step transfers your SSH and GPG keys from another device using LocalSend."
echo
echo "On your SOURCE device (phone/laptop), have these files ready:"
echo "  - id_ed25519        (SSH private key)"
echo "  - id_ed25519.pub    (SSH public key)"
echo "  - private-key.asc   (GPG secret key export)"
echo "  - trustdb.txt       (GPG trust database)"
echo
echo "If you need to export GPG keys on the source device:"
echo "  gpg --list-secret-keys --keyid-format LONG"
echo "  gpg --export-secret-keys --armor KEY_ID > private-key.asc"
echo "  gpg --export-ownertrust > trustdb.txt"
echo

read -p "Press Enter to open LocalSend and wait for file transfer..."

# Start LocalSend in background
localsend &
LOCALSEND_PID=$!

echo
echo "LocalSend is now running."
echo "1. Open LocalSend on your source device"
echo "2. Make sure both devices are on the same WiFi network"
echo "3. Send the 4 key files to this machine"
echo
read -p "Press Enter when all files have been received..."

# Kill LocalSend
kill $LOCALSEND_PID 2>/dev/null || true

#------------------------------------------------------------------------------
# Set up SSH keys
#------------------------------------------------------------------------------
info "Setting up SSH keys"

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

# Look for SSH keys in LocalSend download location
SSH_PRIVATE=""
SSH_PUBLIC=""

for dir in "$LOCALSEND_DIR" "$HOME/Downloads" "$HOME"; do
    if [[ -f "$dir/id_ed25519" ]]; then
        SSH_PRIVATE="$dir/id_ed25519"
    fi
    if [[ -f "$dir/id_ed25519.pub" ]]; then
        SSH_PUBLIC="$dir/id_ed25519.pub"
    fi
done

if [[ -z "$SSH_PRIVATE" ]] || [[ -z "$SSH_PUBLIC" ]]; then
    warn "SSH keys not found automatically"
    read -p "Enter path to id_ed25519: " SSH_PRIVATE
    read -p "Enter path to id_ed25519.pub: " SSH_PUBLIC
fi

# Move keys to .ssh
mv "$SSH_PRIVATE" "$HOME/.ssh/id_ed25519"
mv "$SSH_PUBLIC" "$HOME/.ssh/id_ed25519.pub"
chmod 600 "$HOME/.ssh/id_ed25519"
chmod 644 "$HOME/.ssh/id_ed25519.pub"

success "SSH keys installed"

#------------------------------------------------------------------------------
# Set up GPG keys
#------------------------------------------------------------------------------
info "Setting up GPG keys"

GPG_KEY=""
GPG_TRUST=""

for dir in "$LOCALSEND_DIR" "$HOME/Downloads" "$HOME"; do
    if [[ -f "$dir/private-key.asc" ]]; then
        GPG_KEY="$dir/private-key.asc"
    fi
    if [[ -f "$dir/trustdb.txt" ]]; then
        GPG_TRUST="$dir/trustdb.txt"
    fi
done

if [[ -z "$GPG_KEY" ]]; then
    warn "GPG key not found automatically"
    read -p "Enter path to private-key.asc: " GPG_KEY
fi

if [[ -z "$GPG_TRUST" ]]; then
    warn "GPG trust database not found automatically"
    read -p "Enter path to trustdb.txt (or press Enter to skip): " GPG_TRUST
fi

# Import GPG key
gpg --import "$GPG_KEY"
rm "$GPG_KEY"  # Remove after import for security

if [[ -n "$GPG_TRUST" ]] && [[ -f "$GPG_TRUST" ]]; then
    gpg --import-ownertrust "$GPG_TRUST"
    rm "$GPG_TRUST"
fi

success "GPG keys imported"
gpg --list-secret-keys --keyid-format LONG

#------------------------------------------------------------------------------
# Test GitHub SSH connection
#------------------------------------------------------------------------------
info "Testing GitHub SSH connection"

echo "Testing connection to GitHub..."
if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
    success "GitHub SSH connection successful"
else
    # GitHub returns exit code 1 even on success, check output
    ssh -T git@github.com 2>&1 || true
    echo
    read -p "Did the above show successful authentication? [Y/n] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        error "GitHub SSH connection failed. Check your SSH keys."
    fi
fi

#------------------------------------------------------------------------------
# Clone password store
#------------------------------------------------------------------------------
info "Cloning password store"

if [[ -d "$HOME/.password-store" ]]; then
    warn "Password store already exists, skipping"
else
    git clone "$PASS_REPO" "$HOME/.password-store"
    success "Password store cloned"

    # Verify
    echo "Testing password store..."
    pass || true
fi

#------------------------------------------------------------------------------
# Authenticate with GitHub CLI
#------------------------------------------------------------------------------
info "Authenticating with GitHub CLI"

if gh auth status &>/dev/null; then
    warn "Already authenticated with GitHub CLI"
else
    gh auth login
fi

#------------------------------------------------------------------------------
# Clone and stow dotfiles
#------------------------------------------------------------------------------
info "Setting up dotfiles"

if [[ -d "$HOME/dotfiles" ]]; then
    warn "Dotfiles directory already exists"
    read -p "Remove and re-clone? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$HOME/dotfiles"
    fi
fi

if [[ ! -d "$HOME/dotfiles" ]]; then
    git clone "$DOTFILES_REPO" "$HOME/dotfiles"
fi

cd "$HOME/dotfiles"

# Stow all packages
info "Stowing dotfiles packages"

STOW_PACKAGES=(bash claude ghostty git hypr mako rofi scripts vim wallpapers waybar yazi)

for pkg in "${STOW_PACKAGES[@]}"; do
    if [[ -d "$pkg" ]]; then
        echo "Stowing $pkg..."
        stow "$pkg" 2>/dev/null || warn "Failed to stow $pkg (may already exist)"
    fi
done

success "Dotfiles stowed"

#------------------------------------------------------------------------------
# Configure Git identity
#------------------------------------------------------------------------------
info "Configuring Git identity"

echo
echo "Git needs your name and email for commits."
echo "This will be visible in your commit history."
echo

while true; do
    read -p "Enter your full name: " GIT_NAME
    read -p "Enter your email: " GIT_EMAIL

    echo
    echo "You entered:"
    echo "  Name:  $GIT_NAME"
    echo "  Email: $GIT_EMAIL"
    echo
    read -p "Is this correct? [Y/n/q] " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Qq]$ ]]; then
        warn "Skipping git configuration"
        break
    elif [[ ! $REPLY =~ ^[Nn]$ ]]; then
        git config --global user.name "$GIT_NAME"
        git config --global user.email "$GIT_EMAIL"
        success "Git identity configured"
        break
    fi
    echo "Let's try again..."
    echo
done

#------------------------------------------------------------------------------
# Enable PipeWire audio
#------------------------------------------------------------------------------
info "Enabling PipeWire audio services"

systemctl --user enable pipewire-pulse.socket
systemctl --user enable wireplumber.service
systemctl --user start pipewire-pulse.socket
systemctl --user start wireplumber.service

success "PipeWire enabled"

#------------------------------------------------------------------------------
# Install additional AUR packages
#------------------------------------------------------------------------------
info "Installing additional AUR packages"

yay -S --needed --noconfirm \
    brave-bin \
    claude-code \
    opencode-bin

success "AUR packages installed"

#------------------------------------------------------------------------------
# Install NVM and Node.js
#------------------------------------------------------------------------------
info "Installing NVM and Node.js"

if [[ -d "$HOME/.nvm" ]]; then
    warn "NVM already installed"
else
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash

    # Load NVM for this session
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

    # Install LTS Node
    nvm install --lts
    success "Node.js LTS installed"
fi

#------------------------------------------------------------------------------
# Install SDKMAN and Java
#------------------------------------------------------------------------------
info "Installing SDKMAN and Java"

if [[ -d "$HOME/.sdkman" ]]; then
    warn "SDKMAN already installed"
else
    curl -s "https://get.sdkman.io" | bash

    # Load SDKMAN for this session
    export SDKMAN_DIR="$HOME/.sdkman"
    [[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]] && source "$SDKMAN_DIR/bin/sdkman-init.sh"

    # Install Java
    sdk install java
    success "Java installed"
fi

#------------------------------------------------------------------------------
# Done
#------------------------------------------------------------------------------
info "User setup complete!"
echo
echo "Your system is now fully configured with:"
echo "  - Hyprland desktop environment"
echo "  - Waybar, rofi, mako"
echo "  - PipeWire audio"
echo "  - Brave browser"
echo "  - Claude Code and OpenCode"
echo "  - Node.js (via nvm)"
echo "  - Java (via SDKMAN)"
echo
echo "Key bindings:"
echo "  SUPER+Return    - Terminal"
echo "  SUPER+D         - Application launcher (rofi)"
echo "  SUPER+Q         - Close window"
echo "  SUPER+W         - Cycle wallpaper"
echo "  SUPER+1-9       - Switch workspace"
echo "  SUPER+Shift+E   - Exit Hyprland"
echo
echo "Log out and back in for all changes to take effect."
echo
