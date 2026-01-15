# Arch Linux Install Script for Lenovo T480s

Automated installation with LUKS encryption, btrfs, Hyprland, and Wayland.

## Features

- LUKS2 encrypted root (argon2id)
- btrfs with subvolumes and zstd compression
- Daily automatic snapshots (snapper)
- Plymouth boot splash
- Hyprland + Waybar + Ghostty + Wofi
- PipeWire audio
- Bluetooth support
- CUPS printing
- SSH server
- linux-lts fallback kernel

## Prerequisites

1. Boot Arch Linux ISO (2026-01-01) in UEFI mode
2. Connect to internet via ethernet

## Installation

```bash
# Mount USB with script
lsblk                         # Find USB (e.g., /dev/sda1)
mkdir /mnt/usb
mount /dev/sda1 /mnt/usb

# Run installer
cp /mnt/usb/arch-install.sh /root/
chmod +x /root/arch-install.sh
/root/arch-install.sh
```

You'll be prompted for:
- Confirmation to wipe disk
- LUKS passphrase
- Root password
- User password

## Post-Reboot Workflow

1. Remove USB installation media
2. Reboot: `reboot`
3. Enter LUKS passphrase at boot prompt
4. Login as `ben`
5. Run the post-install script:
   ```bash
   ./post-install.sh
   ```
   This installs from AUR:
   - yay (AUR helper)
   - Ghostty (terminal)
   - Brave (browser)
   - Blueman (Bluetooth manager)

6. Start the desktop:
   ```bash
   Hyprland
   ```

7. Configure WiFi (if needed):
   ```bash
   nmtui
   ```

## Key Bindings

| Keys | Action |
|------|--------|
| `Super + Enter` | Terminal (Ghostty) |
| `Super + D` | App launcher (Wofi) |
| `Super + Q` | Close window |
| `Super + F` | Fullscreen |
| `Super + V` | Toggle floating |
| `Super + 1-0` | Switch workspace |
| `Super + Shift + 1-0` | Move window to workspace |
| `Super + Shift + E` | Exit Hyprland |

## Useful Commands

```bash
nmtui                 # Configure WiFi
blueman-manager       # Bluetooth devices
snapper list          # View snapshots
snapper undochange N  # Restore snapshot N
systemctl status cups # Check print service
```

## Partition Layout

| Partition | Size | Type | Mount |
|-----------|------|------|-------|
| nvme0n1p1 | 1G | EFI | /efi |
| nvme0n1p2 | Rest | LUKS → btrfs | / |

## btrfs Subvolumes

- `@` → `/`
- `@home` → `/home`
- `@snapshots` → `/.snapshots`
- `@var_log` → `/var/log`
- `@var_cache` → `/var/cache`
- `@var_tmp` → `/var/tmp`
