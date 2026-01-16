# Arch Linux ThinkPad T480s

Automated Arch Linux installation for Lenovo ThinkPad T480s.

## Features

- LUKS2 full disk encryption (argon2id)
- btrfs with subvolumes and snapshots (snapper)
- systemd-boot with LTS kernel fallback
- Hyprland, Waybar, PipeWire, NetworkManager

## Quick Install

```bash
# Boot Arch ISO, then:
mkdir -p /run/archusb
mount /dev/sdX1 /run/archusb          # USB with script (+ optional pkg-cache.tar)
/run/archusb/arch-install.sh
```

The script will prompt for LUKS passphrase and user passwords. After install, answer `y` to save package cache for faster future installs.

## Contents

- `scripts/arch-install.sh` - Automated installation script
- `arch-linux-t480s-install.md` - Manual step-by-step guide

## Dotfiles

After installation, deploy with [GNU Stow](https://www.gnu.org/software/stow/):

```bash
cd ~/dotfiles
stow hypr waybar ghostty mako rofi
```
