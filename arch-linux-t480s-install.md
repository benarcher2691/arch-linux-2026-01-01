# Arch Linux Installation Guide - Lenovo ThinkPad T480s

A manual installation guide for Arch Linux with full disk encryption, Hyprland (Wayland), and a modern desktop environment.

## Target Configuration

| Component | Choice |
|-----------|--------|
| Keyboard | US English |
| Boot Mode | UEFI |
| Bootloader | systemd-boot |
| Encryption | LUKS with systemd initramfs |
| Network | NetworkManager |
| Display Manager | greetd + tuigreet |
| Compositor | Hyprland (Wayland) |
| Status Bar | Waybar |
| Launcher | rofi-wayland |
| Wallpaper | hyprpaper |
| Audio | PipeWire |
| Bluetooth | bluez + blueman |

---

## Part 1: Pre-Installation (Live USB)

### 1.1 Boot the Live Environment

Boot from the Arch Linux USB. Disable Secure Boot in BIOS if necessary.

### 1.2 Set Console Font

```bash
setfont ter-132b
```

### 1.3 Verify UEFI Boot Mode

```bash
cat /sys/firmware/efi/fw_platform_size
```

This should return `64` (or `32`). If the file doesn't exist, you're in BIOS mode.

### 1.4 Connect to the Internet

**For Ethernet:** Should work automatically.

**For Wi-Fi:**

```bash
iwctl
```

Inside iwctl:

```
device list
station wlan0 scan
station wlan0 get-networks
station wlan0 connect "YourNetworkName"
exit
```

Verify connection:

```bash
ping -c 3 archlinux.org
```

### 1.5 Update System Clock

```bash
timedatectl set-ntp true
timedatectl status
```

---

## Part 2: Disk Partitioning

### 2.1 Identify Your Disk

```bash
lsblk
```

The T480s NVMe drive is typically `/dev/nvme0n1`. Adjust commands if yours differs.

### 2.2 Wipe and Partition the Disk

```bash
fdisk /dev/nvme0n1
```

Inside fdisk:

1. `g` - Create a new GPT partition table (wipes everything)
2. `n` - New partition (EFI)
   - Partition number: 1
   - First sector: Enter (default)
   - Last sector: `+1G`
3. `t` - Change partition type
   - Type: `1` (EFI System)
4. `n` - New partition (Root, encrypted)
   - Partition number: 2
   - First sector: Enter (default)
   - Last sector: Enter (use remaining space)
5. `w` - Write changes and exit

Verify:

```bash
lsblk
```

You should see:
- `/dev/nvme0n1p1` - 1G EFI partition
- `/dev/nvme0n1p2` - Remaining space for encrypted root

---

## Part 3: Encryption Setup

### 3.1 Encrypt the Root Partition

```bash
cryptsetup luksFormat /dev/nvme0n1p2
```

- Type `YES` (uppercase) to confirm
- Enter your encryption passphrase (use a strong one!)

### 3.2 Open the Encrypted Partition

```bash
cryptsetup open /dev/nvme0n1p2 cryptroot
```

Enter your passphrase. This creates `/dev/mapper/cryptroot`.

---

## Part 4: Format and Mount

### 4.1 Format Partitions

```bash
mkfs.fat -F32 /dev/nvme0n1p1
mkfs.ext4 /dev/mapper/cryptroot
```

### 4.2 Test Encryption

Close and reopen the encrypted volume to verify your passphrase works:

```bash
cryptsetup close cryptroot
cryptsetup open /dev/nvme0n1p2 cryptroot
```

### 4.3 Mount Partitions

```bash
mount /dev/mapper/cryptroot /mnt
mount --mkdir /dev/nvme0n1p1 /mnt/boot
```

---

## Part 5: Install Base System

### 5.1 Install Essential Packages

```bash
pacstrap -K /mnt base linux linux-firmware intel-ucode networkmanager sudo terminus-font vim
```

### 5.2 Generate fstab

```bash
genfstab -U /mnt >> /mnt/etc/fstab
```

Verify it looks correct:

```bash
cat /mnt/etc/fstab
```

---

## Part 6: System Configuration (chroot)

### 6.1 Enter the New System

```bash
arch-chroot /mnt
```

### 6.2 Set Timezone

```bash
ln -sf /usr/share/zoneinfo/Europe/Stockholm /etc/localtime
hwclock --systohc
```

### 6.3 Localization

Edit locale file:

```bash
vim /etc/locale.gen
```

Uncomment this line:

```
en_US.UTF-8 UTF-8
```

Generate locales:

```bash
locale-gen
```

Create locale config:

```bash
echo "LANG=en_US.UTF-8" > /etc/locale.conf
```

### 6.4 Console Configuration

```bash
cat > /etc/vconsole.conf << EOF
KEYMAP=us
XKBLAYOUT=us
FONT=ter-132b
EOF
```

### 6.5 Network Configuration

Set hostname:

```bash
echo "t480s" > /etc/hostname
```

Create hosts file:

```bash
cat > /etc/hosts << EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   t480s
EOF
```

### 6.6 Configure mkinitcpio for Encryption

Edit the configuration:

```bash
vim /etc/mkinitcpio.conf
```

Find the `HOOKS` line and replace it with:

```
HOOKS=(base systemd autodetect microcode modconf kms keyboard block sd-encrypt filesystems fsck)
```

Regenerate initramfs:

```bash
mkinitcpio -P
```

### 6.7 Set Root Password

```bash
passwd
```

### 6.8 Enable NetworkManager

```bash
systemctl enable NetworkManager
```

### 6.9 Install Bootloader (systemd-boot)

```bash
bootctl install
```

Get the UUID of your encrypted partition:

```bash
blkid -s UUID -o value /dev/nvme0n1p2
```

Copy this UUID. Now create the boot entry:

```bash
vim /boot/loader/entries/arch.conf
```

Add (replace `YOUR-UUID-HERE` with the actual UUID):

```
title   Arch Linux
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux.img
options rd.luks.name=YOUR-UUID-HERE=cryptroot root=/dev/mapper/cryptroot rw
```

Configure the loader:

```bash
vim /boot/loader/loader.conf
```

Add:

```
default arch.conf
timeout 3
console-mode max
editor no
```

---

## Part 7: First Reboot

Verify the base system boots correctly before continuing.

### 7.1 Exit and Unmount

```bash
exit
umount -R /mnt
reboot
```

Remove the USB drive when the system restarts.

### 7.2 Verify Boot

- You should see the systemd-boot menu
- Select "Arch Linux"
- Enter your LUKS encryption passphrase
- Log in as `root` with the password you set

Set console font:

```bash
setfont ter-132b
```

### 7.3 Connect to the Internet

```bash
nmtui
```

Or for Wi-Fi via command line:

```bash
nmcli device wifi connect "YourNetwork" password "YourPassword"
```

---

## Part 8: System Setup (as root)

### 8.1 Install Desktop Environment Packages

```bash
pacman -S \
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
    greetd \
    greetd-tuigreet \
    grim \
    htop \
    hyprland \
    hyprpaper \
    kitty \
    libreoffice-fresh \
    mako \
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
    xdg-desktop-portal-hyprland \
    yazi \
    zip
```

When prompted for a JACK provider, select `pipewire-jack` (integrates with PipeWire).

### 8.2 Create User Account

```bash
useradd -m -G wheel,input -s /bin/bash ben
passwd ben
```

### 8.3 Enable sudo for wheel group

```bash
EDITOR=vim visudo
```

Uncomment this line:

```
%wheel ALL=(ALL:ALL) ALL
```

### 8.4 Enable Services

```bash
systemctl enable bluetooth
systemctl enable cups
systemctl enable greetd
systemctl enable tlp
```

### 8.5 Configure greetd

```bash
vim /etc/greetd/config.toml
```

Replace contents with:

```toml
[terminal]
vt = 1

[default_session]
command = "tuigreet --time --remember --cmd start-hyprland"
user = "greeter"
```

### 8.6 Reboot to Desktop

```bash
reboot
```

---

## Part 9: Post-Installation (as ben)

After entering your encryption passphrase, log in as `ben` via tuigreet:

### 9.1 Connect to Wi-Fi (if needed)

```bash
nmtui
```

Or use:

```bash
nmcli device wifi connect "YourNetwork" password "YourPassword"
```

### 9.2 Set Up SSH and GPG Keys

**SSH Keys:**

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
```

Copy your keys from backup/USB (e.g., `id_ed25519`, `id_ed25519.pub`), then set permissions:

```bash
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub
```

Test SSH connection to GitHub:

```bash
ssh -T git@github.com
```

**GPG Keys:**

Copy your exported GPG files from backup/USB (`private-key.asc`, `trustdb.txt`), then import:

```bash
gpg --import private-key.asc
gpg --import-ownertrust trustdb.txt
```

Verify import:

```bash
gpg --list-secret-keys --keyid-format LONG
```

To export keys on your old machine beforehand:

```bash
gpg --list-secret-keys --keyid-format LONG          # Find your key ID
gpg --export-secret-keys --armor KEY_ID > private-key.asc
gpg --export-ownertrust > trustdb.txt
```

**Password Store (pass):**

Clone your password store (encrypted with the GPG key above):

```bash
git clone git@github.com:benarcher2691/pass-store.git ~/.password-store
```

Verify:

```bash
pass          # List entries
pass show test-entry   # Decrypt an entry
```

### 9.3 Clone and Stow Dotfiles

Authenticate with GitHub CLI:

```bash
gh auth login
```

Clone your dotfiles repository:

```bash
git clone git@github.com:benarcher2691/dotfiles_arch_2026.git ~/dotfiles
cd ~/dotfiles
```

Stow all configurations (creates symlinks to ~/.config):

```bash
stow bash claude ghostty git hypr mako rofi vim wallpapers waybar yazi
```

This sets up configs for Hyprland, Waybar, rofi, mako notifications, and more.

### 9.4 Enable PipeWire Audio

```bash
systemctl --user enable pipewire-pulse.socket
systemctl --user enable wireplumber.service
systemctl --user start pipewire-pulse.socket
systemctl --user start wireplumber.service
```

### 9.5 Customize Configs (Optional)

Your dotfiles are now symlinked. To customize:

```bash
vim ~/.config/hypr/hyprland.conf    # Hyprland compositor
vim ~/.config/hypr/hyprpaper.conf   # Wallpaper settings
vim ~/.config/waybar/config         # Status bar
vim ~/.config/waybar/style.css      # Waybar styling
```

### 9.6 Test Bluetooth

```bash
bluetoothctl
```

Inside bluetoothctl:

```
power on
agent on
default-agent
scan on
```

Wait for your device to appear (e.g., `[NEW] Device XX:XX:XX:XX:XX:XX Rexcore Halo`), then:

```
scan off
pair XX:XX:XX:XX:XX:XX
connect XX:XX:XX:XX:XX:XX
trust XX:XX:XX:XX:XX:XX
exit
```

Use `trust` so it auto-reconnects in the future.

### 9.7 Test Audio

```bash
pavucontrol
```

Or use the command line:

```bash
pactl info
wpctl status
```

---

## Quick Reference - Key Bindings (Default Hyprland)

| Keys | Action |
|------|--------|
| `SUPER + Return` | Open terminal |
| `SUPER + D` | Open rofi launcher |
| `SUPER + Q` | Close window |
| `SUPER + 1-9` | Switch workspace |
| `SUPER + SHIFT + 1-9` | Move window to workspace |
| `SUPER + Arrow Keys` | Move focus |
| `SUPER + SHIFT + E` | Exit Hyprland |

---

## Troubleshooting

### No audio output
```bash
wpctl status
wpctl set-default <sink-id>
```

### Bluetooth not working
```bash
sudo systemctl status bluetooth
sudo systemctl restart bluetooth
```

### Screen brightness
```bash
brightnessctl set 50%
brightnessctl set +10%
brightnessctl set 10%-
```

### Wi-Fi issues
```bash
nmcli device wifi list
nmcli device wifi connect "SSID" password "password"
```

---

## Part 10: AUR and Additional Software (as ben)

### 10.1 Install AUR Helper (yay)

```bash
sudo pacman -S --needed base-devel
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
cd ..
rm -rf yay
```

### 10.2 Install AUR Packages

```bash
yay -S brave-bin claude-code localsend-bin opencode-bin
```

### 10.3 Install NVM (Node Version Manager)

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
```

Log out and back in, then:

```bash
nvm install --lts
```

### 10.4 Install SDKMAN (Java/Kotlin/Gradle)

```bash
curl -s "https://get.sdkman.io" | bash
```

Log out and back in, then:

```bash
sdk install java
```

### 10.5 Set Up Claude Code

Claude Code (installed via AUR in 10.2) is Anthropic's CLI coding assistant.

Authenticate with your Anthropic account:

```bash
claude
```

Follow the prompts to log in via browser. Once authenticated, your status line and other settings are already configured via dotfiles (stowed in 9.3).

Useful commands:

```bash
claude              # Start interactive session
claude "question"   # Quick question
claude -c           # Continue previous conversation
```

---

## Summary

You now have a fully encrypted Arch Linux installation with:

- LUKS encryption with systemd-boot
- Hyprland Wayland compositor
- Waybar status bar
- rofi-wayland application launcher
- hyprpaper wallpaper manager
- PipeWire audio
- Bluetooth support
- greetd login manager with tuigreet

Enjoy your new Arch Linux system!
