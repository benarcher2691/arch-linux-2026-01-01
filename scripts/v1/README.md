# Arch Linux T480s Installation Scripts

Automated installation scripts for Arch Linux on ThinkPad T480s with LUKS encryption, btrfs, and Hyprland.

## Overview

| Script | When to Run | Run As | Description |
|--------|-------------|--------|-------------|
| `00-pre-chroot.sh` | Live USB | root | Partition, encrypt, pacstrap |
| `01-chroot-setup.sh` | arch-chroot | root | System config, bootloader |
| `02-post-reboot-root.sh` | After reboot | root | Packages, user, services |
| `03-user-setup.sh` | After reboot | ben | Keys, dotfiles, AUR |

## Prerequisites

1. Boot from Arch Linux live USB
2. Disable Secure Boot in BIOS if needed
3. Connect to the internet

```bash
# Set readable font
setfont ter-132b

# For WiFi
iwctl
# station wlan0 connect "YourNetwork"
# exit

# Verify connection
ping -c 3 archlinux.org
```

## Quick Start

```bash
# Get the scripts
pacman -Sy git
git clone https://github.com/benarcher2691/arch-linux-2026-01-01.git /tmp/arch-setup
cd /tmp/arch-setup/scripts
```

---

## Step 1: Pre-Chroot (Live USB)

**WARNING: This will wipe the target disk!**

```bash
# Review configuration at top of script
vim 00-pre-chroot.sh

# Make executable and run
chmod +x 00-pre-chroot.sh
./00-pre-chroot.sh
```

**Configuration variables:**
```bash
DISK="/dev/nvme0n1"        # Target disk
TIMEZONE="Europe/Stockholm"
HOSTNAME="t480s"
```

**What it does:**
- Partitions disk (1G EFI + encrypted root)
- Sets up LUKS encryption (prompts for passphrase)
- Formats btrfs with subvolumes (@, @home, @snapshots, @var_log)
- Mounts with compress=zstd,noatime
- Runs pacstrap with base packages
- Generates fstab
- Copies scripts to /mnt/root/arch-setup

**Interactive prompts:** LUKS passphrase (enter twice)

---

## Step 2: Chroot Setup

```bash
arch-chroot /mnt
cd /root/arch-setup
chmod +x 01-chroot-setup.sh
./01-chroot-setup.sh
```

**What it does:**
- Sets timezone and locale (en_US.UTF-8)
- Configures hostname and /etc/hosts
- Sets up mkinitcpio for encryption + plymouth
- Sets root password (prompts)
- Enables NetworkManager
- Installs systemd-boot with boot entries

**Interactive prompts:** Root password

**After completion:**
```bash
exit
umount -R /mnt
reboot
```

Remove the USB drive when system restarts.

---

## Step 3: Post-Reboot Root Setup

After entering LUKS passphrase, log in as root:

```bash
setfont ter-132b
nmtui  # Connect to network

cd /root/arch-setup
chmod +x 02-post-reboot-root.sh
./02-post-reboot-root.sh
```

**What it does:**
- Installs desktop packages (Hyprland, Waybar, PipeWire, etc.)
- Creates user "ben" (prompts for password)
- Configures sudo for wheel group
- Installs yay (AUR helper)
- Installs greetd-regreet from AUR
- Installs localsend-bin for key transfer
- Enables services (bluetooth, cups, greetd, tlp)
- Configures greetd (vt=7 to prevent flicker)

**Interactive prompts:** User password, pacman confirmations

**After completion:**
```bash
reboot
```

---

## Step 4: User Setup

Log in via regreet as `ben`, select **Hyprland** session, open terminal (SUPER+Return):

```bash
cd ~/arch-setup  # Scripts were copied here
chmod +x 03-user-setup.sh
./03-user-setup.sh
```

### Key Transfer with LocalSend

The script uses LocalSend to receive SSH and GPG keys from another device.

**Before running the script, prepare on your source device:**

1. Export your GPG key (if not already done):
   ```bash
   gpg --list-secret-keys --keyid-format LONG  # Find KEY_ID
   gpg --export-secret-keys --armor KEY_ID > private-key.asc
   gpg --export-ownertrust > trustdb.txt
   ```

2. Have these files ready to send:
   - `id_ed25519` (SSH private key)
   - `id_ed25519.pub` (SSH public key)
   - `private-key.asc` (GPG key)
   - `trustdb.txt` (GPG trust)

**During the script:**

```
┌─────────────────┐    LocalSend    ┌─────────────────┐
│  Source Device  │ ──────────────► │  New T480s      │
│  (phone/laptop) │   WiFi LAN      │  (Arch Linux)   │
└─────────────────┘                 └─────────────────┘
```

1. Script opens LocalSend on the T480s
2. Open LocalSend on your source device
3. Send the 4 key files
4. Press Enter in the script when transfer completes

**What the script does after key transfer:**
- Sets up SSH keys with correct permissions
- Imports GPG keys
- Tests GitHub SSH connection
- Clones password-store
- Authenticates with GitHub CLI
- Clones dotfiles and stows all packages
- Enables PipeWire audio services
- Installs AUR packages (brave, claude-code, etc.)
- Installs nvm + Node.js LTS
- Installs SDKMAN + Java

---

## Configuration Reference

### 00-pre-chroot.sh
```bash
DISK="/dev/nvme0n1"         # NVMe drive (check with lsblk)
TIMEZONE="Europe/Stockholm" # Your timezone
HOSTNAME="t480s"            # Machine hostname
```

### 03-user-setup.sh
```bash
DOTFILES_REPO="git@github.com:benarcher2691/dotfiles_arch_2026.git"
PASS_REPO="git@github.com:benarcher2691/pass-store.git"
```

---

## Btrfs Subvolume Layout

```
/dev/mapper/cryptroot (btrfs)
├── @           → /
├── @home       → /home
├── @snapshots  → /.snapshots
└── @var_log    → /var/log
```

Mount options: `subvol=@,compress=zstd,noatime`

---

## Troubleshooting

### Script fails partway through
Most scripts are idempotent. Fix the issue and re-run.

### Wrong LUKS passphrase during setup
Restart `00-pre-chroot.sh` from the beginning.

### Network issues after reboot
```bash
nmtui
# or
nmcli device wifi connect "SSID" password "password"
```

### LocalSend not finding devices
- Ensure both devices are on the same WiFi network
- Check firewall isn't blocking LocalSend (ports 53317 TCP/UDP)

### Bootloader issues
Boot from live USB:
```bash
cryptsetup open /dev/nvme0n1p2 cryptroot
mount -o subvol=@ /dev/mapper/cryptroot /mnt
mount /dev/nvme0n1p1 /mnt/boot
arch-chroot /mnt
bootctl install
# Recreate boot entries
```

### GitHub SSH connection fails
```bash
ssh -vT git@github.com  # Verbose output for debugging
```

---

## After Installation

See the main guide (`../arch-linux-t480s-install.md`) for:
- Key bindings reference
- Bluetooth pairing
- Audio troubleshooting
- Snapper snapshot setup
