# Arch Linux ThinkPad T480s

Automated Arch Linux installation with LUKS encryption, btrfs, Hyprland.

## What's Included

- Ventoy USB setup with install script, dotfiles, password store
- Automated installer: LUKS2, btrfs snapshots, systemd-boot
- Hyprland + Waybar + PipeWire

## 1. Create Ventoy USB

From any Linux:

```bash
curl -LO https://github.com/ventoy/Ventoy/releases/download/v1.1.10/ventoy-1.1.10-linux.tar.gz
tar xzf ventoy-1.1.10-linux.tar.gz
cd ventoy-1.1.10
sudo sh Ventoy2Disk.sh -i /dev/sdX
```

Copy to USB:
- `archlinux-2026.01.01-x86_64.iso`
- `arch-install.sh`
- `dotfiles/`
- `pass-store/`

If copying from macOS, clean up resource fork files:
```bash
dot_clean /Volumes/Ventoy/dotfiles
```

## 2. Install Arch

Boot USB -> Ventoy -> Arch ISO

```bash
mkdir -p /run/archusb
udevadm trigger                       # Initialize Ventoy device mapper
mount /dev/mapper/sda1 /run/archusb   # Use /dev/mapper/, not /dev/sda1
/run/archusb/arch-install.sh
```

> **Note:** Ventoy requires mounting via `/dev/mapper/sdX1`, not the raw block device.
> If `/dev/mapper/sda1` doesn't exist, run `dmsetup ls` to find the correct device.

## 3. Post-Install (First Boot)

Login as user. DO NOT start Hyprland yet.

### Mount USB (if using Ventoy stick)

```bash
sudo mkdir -p /run/archusb
sudo mount /dev/sda1 /run/archusb   # Direct mount (not /dev/mapper)
```

### Back up default .bashrc

```bash
mv ~/.bashrc ~/.bashrc.default
```

### Clone and stow dotfiles

From USB:
```bash
cp -r /run/archusb/dotfiles ~/dotfiles
find ~/dotfiles -name '._*' -delete   # Remove macOS resource forks
```

Or from GitHub:
```bash
git clone https://github.com/benarcher2691/dotfiles.git ~/dotfiles
```

Then stow:
```bash
cd ~/dotfiles
stow bash git hypr waybar ghostty mako rofi scripts vim yazi wallpapers
```

### Install yay + AUR packages

```bash
cd /tmp
git clone https://aur.archlinux.org/yay-bin.git
cd yay-bin
makepkg -si --noconfirm
cd ~ && rm -rf /tmp/yay-bin

yay -S --noconfirm brave-bin blueman
```

## 4. Start Hyprland

```bash
start-hyprland
```
