# CLAUDE.md

This repository contains an Arch Linux installation guide for a Lenovo ThinkPad T480s.

## Project Overview

A manual installation guide (`arch-linux-t480s-install.md`) with step-by-step commands for setting up:

- UEFI boot with systemd-boot
- LUKS full disk encryption (systemd-based initramfs)
- Hyprland Wayland compositor
- greetd + regreet login manager
- Waybar, rofi-wayland, hyprpaper
- PipeWire audio
- Bluetooth (bluez + blueman)
- NetworkManager

## Dotfiles

User dotfiles are stored in `~/dotfiles` and managed with GNU Stow. Each subdirectory (e.g., `hypr`, `waybar`, `rofi`) contains config files that get symlinked to `~/.config/` when stowed. The `scripts` directory contains user scripts that get symlinked to `~/.local/bin/`.

## Guidelines

- Keep instructions copy-paste friendly with proper code blocks
- Commands should be tested and accurate for current Arch Linux
- Maintain the single-file format for easy reference during installation
- Update package names if they change in Arch repositories
