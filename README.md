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

## 2. Install Arch

Boot USB -> Ventoy -> Arch ISO

```bash
mkdir -p /run/archusb
mount /dev/disk/by-label/Ventoy /run/archusb
/run/archusb/arch-install.sh
```

## 3. Post-Install (First Boot)

Login as user. DO NOT start Hyprland yet.

### Back up default .bashrc

```bash
mv ~/.bashrc ~/.bashrc.default
```

### Clone and stow dotfiles

```bash
cp -r /run/archusb/dotfiles ~/dotfiles  # or git clone
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
