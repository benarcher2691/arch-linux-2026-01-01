# Arch Linux ThinkPad T480s

Personal Arch Linux installation guide and dotfiles for Lenovo ThinkPad T480s.

## Contents

- `arch-linux-t480s-install.md` - Step-by-step installation guide
- `dotfiles/` - Configuration files (stow-managed)
- `scripts/` - Setup automation scripts

## Setup

LUKS encryption, systemd-boot, Hyprland, Waybar, PipeWire, NetworkManager.

## Dotfiles

Deploy with [GNU Stow](https://www.gnu.org/software/stow/):

```bash
cd ~/dotfiles
stow bash git hypr waybar ghostty mako rofi yazi wallpapers
```
