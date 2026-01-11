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

### 1.2 Verify UEFI Boot Mode

```bash
cat /sys/firmware/efi/fw_platform_size
```

This should return `64` (or `32`). If the file doesn't exist, you're in BIOS mode.

### 1.3 Connect to the Internet

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

### 1.4 Update System Clock

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

### 4.2 Mount Partitions

```bash
mount /dev/mapper/cryptroot /mnt
mount --mkdir /dev/nvme0n1p1 /mnt/boot
```

---

## Part 5: Install Base System

### 5.1 Install Essential Packages

```bash
pacstrap -K /mnt base linux linux-firmware intel-ucode nano sudo
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
ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime
hwclock --systohc
```

Replace `America/New_York` with your timezone. List available zones with:

```bash
ls /usr/share/zoneinfo/
```

### 6.3 Localization

Edit locale file:

```bash
nano /etc/locale.gen
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

### 6.4 Network Configuration

Set hostname:

```bash
echo "t480s" > /etc/hostname
```

### 6.5 Configure mkinitcpio for Encryption

Edit the configuration:

```bash
nano /etc/mkinitcpio.conf
```

Find the `HOOKS` line and replace it with:

```
HOOKS=(base systemd autodetect microcode modconf kms keyboard block sd-encrypt filesystems fsck)
```

Regenerate initramfs:

```bash
mkinitcpio -P
```

### 6.6 Set Root Password

```bash
passwd
```

### 6.7 Install Bootloader (systemd-boot)

```bash
bootctl install
```

Get the UUID of your encrypted partition:

```bash
blkid -s UUID -o value /dev/nvme0n1p2
```

Copy this UUID. Now create the boot entry:

```bash
nano /boot/loader/entries/arch.conf
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
nano /boot/loader/loader.conf
```

Add:

```
default arch.conf
timeout 3
console-mode max
editor no
```

---

## Part 7: Install Desktop Environment Packages

### 7.1 Install All Required Packages

```bash
pacman -S networkmanager \
    greetd greetd-tuigreet \
    hyprland xdg-desktop-portal-hyprland \
    waybar \
    hyprpaper \
    rofi-wayland \
    pipewire pipewire-pulse pipewire-alsa wireplumber \
    bluez bluez-utils blueman \
    polkit \
    kitty \
    ttf-dejavu ttf-liberation noto-fonts \
    brightnessctl \
    grim slurp \
    wl-clipboard \
    thunar \
    mako \
    pavucontrol
```

### 7.2 Enable Services

```bash
systemctl enable NetworkManager
systemctl enable greetd
systemctl enable bluetooth
```

---

## Part 8: Create User Account

### 8.1 Create Your User

```bash
useradd -m -G wheel -s /bin/bash yourusername
passwd yourusername
```

Replace `yourusername` with your desired username.

### 8.2 Enable sudo for wheel group

```bash
EDITOR=nano visudo
```

Uncomment this line:

```
%wheel ALL=(ALL:ALL) ALL
```

---

## Part 9: Configure greetd

### 9.1 Edit greetd Configuration

```bash
nano /etc/greetd/config.toml
```

Replace contents with:

```toml
[terminal]
vt = 1

[default_session]
command = "tuigreet --time --remember --cmd Hyprland"
user = "greeter"
```

---

## Part 10: Reboot

### 10.1 Exit and Unmount

```bash
exit
umount -R /mnt
reboot
```

Remove the USB drive when the system restarts.

---

## Part 11: Post-Installation (First Boot)

After entering your encryption passphrase and logging in via tuigreet:

### 11.1 Connect to Wi-Fi (if needed)

```bash
nmtui
```

Or use:

```bash
nmcli device wifi connect "YourNetwork" password "YourPassword"
```

### 11.2 Enable PipeWire Audio (as your user)

```bash
systemctl --user enable pipewire-pulse.socket
systemctl --user enable wireplumber.service
systemctl --user start pipewire-pulse.socket
systemctl --user start wireplumber.service
```

### 11.3 Create Hyprland Configuration

```bash
mkdir -p ~/.config/hypr
cp /usr/share/hypr/hyprland.conf ~/.config/hypr/hyprland.conf
```

Edit your config:

```bash
nano ~/.config/hypr/hyprland.conf
```

Add/modify these essentials:

```bash
# Startup applications
exec-once = waybar
exec-once = hyprpaper
exec-once = mako

# Set your terminal
$terminal = kitty

# Set your launcher
$menu = rofi -show drun

# Key bindings (add these or modify existing)
bind = $mainMod, Return, exec, $terminal
bind = $mainMod, D, exec, $menu
bind = $mainMod, Q, killactive
bind = $mainMod SHIFT, E, exit
```

### 11.4 Configure Hyprpaper

```bash
mkdir -p ~/.config/hypr
nano ~/.config/hypr/hyprpaper.conf
```

Add:

```
preload = /path/to/your/wallpaper.jpg
wallpaper = ,/path/to/your/wallpaper.jpg
```

### 11.5 Configure Waybar

```bash
mkdir -p ~/.config/waybar
cp /etc/xdg/waybar/* ~/.config/waybar/
```

Edit as desired:

```bash
nano ~/.config/waybar/config
```

### 11.6 Test Bluetooth

```bash
bluetoothctl
```

Inside bluetoothctl:

```
power on
agent on
default-agent
scan on
# Wait for your device to appear
pair XX:XX:XX:XX:XX:XX
connect XX:XX:XX:XX:XX:XX
exit
```

### 11.7 Test Audio

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

## Optional Enhancements

### Install AUR Helper (yay)

```bash
sudo pacman -S git base-devel
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
```

### Additional Recommended Packages

```bash
sudo pacman -S firefox htop neofetch unzip zip wget
```

### Power Management (for laptop)

```bash
sudo pacman -S tlp
sudo systemctl enable tlp
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
