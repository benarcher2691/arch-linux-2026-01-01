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

When installation completes:
- Do NOT remove USB - you need it for dotfiles in next step
- Reboot and select HDD in boot menu (not USB)

## 3. Post-Install (First Boot)

Login as user. DO NOT start Hyprland yet.

### Connect to internet and update

```bash
nmtui                  # Connect to WiFi
sudo pacman -Syu       # Update system
```

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
git clone https://github.com/benarcher2691/dotfiles_arch_2026.git ~/dotfiles
```

Then stow:
```bash
cd ~/dotfiles
stow bash claude ghostty git hypr mako scripts vim wallpapers waybar yazi
```

### Transfer GPG keys (via LocalSend)

On macOS, export:
```bash
gpg --export-secret-keys --armor > ~/Desktop/gpg-secret.asc
gpg --export-ownertrust > ~/Desktop/gpg-trust.txt
```

Send via LocalSend to Arch, then import:
```bash
gpg --import ~/Downloads/gpg-secret.asc
gpg --import-ownertrust ~/Downloads/gpg-trust.txt
rm ~/Downloads/gpg-secret.asc ~/Downloads/gpg-trust.txt
```

### Transfer SSH public key

From macOS:
```bash
ssh-copy-id ben@<arch-ip>
```

### Copy password store (from USB)

```bash
cp -r /run/archusb/pass-store ~/.password-store
```

### Install yay + AUR packages

```bash
cd /tmp
git clone https://aur.archlinux.org/yay-bin.git
cd yay-bin
makepkg -si --noconfirm
cd ~ && rm -rf /tmp/yay-bin

yay -S --noconfirm brave-bin blueman lazydocker obsidian spotify-launcher swww yazi
```

### Install sdkman and nvm

```bash
curl -s "https://get.sdkman.io" | bash    # Java version manager
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash   # Node version manager
```

Restart shell, then install versions as needed:
- `sdk install java` (list available: `sdk list java`)
- `nvm install --lts` (list available: `nvm ls-remote`)

## 4. Start Hyprland

```bash
start-hyprland
```

## 5. Additional Software

### Media player

```bash
sudo pacman -S vlc vlc-plugin-ffmpeg vlc-plugin-mpeg2
```

### Torrent client

```bash
sudo pacman -S transmission-gtk
xdg-mime default transmission-gtk.desktop x-scheme-handler/magnet
```

### VPN

```bash
yay -S mullvad-vpn-bin   # Use -bin to avoid heavy Rust compilation
sudo systemctl enable --now mullvad-daemon
mullvad account login <account-number>
mullvad connect
```

### File sharing

```bash
yay -S localsend-bin
```

### Claude Code CLI

```bash
yay -S claude-code-bin
```

### fzf integration with bash

If you installed fzf, enable bash integration for enhanced history search:

```bash
# Add to ~/.bashrc
[ -f /usr/share/fzf/key-bindings.bash ] && source /usr/share/fzf/key-bindings.bash
[ -f /usr/share/fzf/completion.bash ] && source /usr/share/fzf/completion.bash
```

Then reload: `source ~/.bashrc`

Key bindings:
- **Ctrl+R**: Interactive command history search
- **Ctrl+T**: File/directory finder
- **Alt+C**: Quick directory navigation
