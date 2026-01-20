# Arch Linux DevPod Setup

Arch Linux installation optimized for containerized development with DevPod.

## Philosophy

**Host (Hyprland desktop + essentials):**
- Arch Linux base
- Hyprland + Waybar + PipeWire
- Docker + DevPod
- Git, SSH, GPG, vim
- Snapper for btrfs snapshots

**Everything else in containers:**
- Languages (Node, Python, Java, Go, Rust...)
- Project toolchains
- Database clients
- Build tools

Benefits:
- No version conflicts between projects
- Clean host system
- Reproducible environments
- Fast setup on new machines
- Share `.devcontainer.json` with team

## 1. Install

Boot Arch ISO, mount USB:

```bash
mkdir -p /run/archusb
udevadm trigger                       # Initialize Ventoy device mapper
mount /dev/mapper/sda1 /run/archusb   # Use /dev/mapper/, not /dev/sda1
/run/archusb/arch-install-devpod.sh
```

This installs:
- LUKS2 encrypted root
- btrfs with subvolumes (including @docker)
- Hyprland + Waybar + PipeWire
- Docker (pre-installed)
- Snapper for snapshots
- NO swapfile (breaks btrfs snapshots)

When complete, reboot (keep USB mounted for dotfiles).

## 2. Post-Install (First Boot)

Login as user. DO NOT start Hyprland yet.

### Connect to internet and update

```bash
nmtui                  # Connect to WiFi
sudo pacman -Syu       # Update system
```

### Back up default .bashrc

```bash
mv ~/.bashrc ~/.bashrc.default
```

### Clone and stow dotfiles

From USB:
```bash
sudo mkdir -p /run/archusb
sudo mount /dev/sda1 /run/archusb
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

On source machine, export:
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

### Copy password store (from USB)

```bash
cp -r /run/archusb/pass-store ~/.password-store
```

## 3. Install yay + AUR packages

```bash
cd /tmp
git clone https://aur.archlinux.org/yay-bin.git
cd yay-bin
makepkg -si --noconfirm
cd ~ && rm -rf /tmp/yay-bin

# Install AUR packages (waybar deps: yazi, spotify; plus tools)
yay -S --noconfirm arch-audit brave-bin blueman lazydocker rkhunter spotify-launcher swww yazi

# Disable interactive prompts
yay -Y --diffmenu=false --editmenu=false --cleanmenu=false --removemake=yes --provides=false --combinedupgrade=false --save
```

## 4. Install DevPod

```bash
yay -S devpod-bin
echo 'alias devpod="devpod-cli"' >> ~/.bashrc
source ~/.bashrc

# Add Docker as provider
devpod provider add docker

# Use SSH instead of IDE
devpod ide use none
```

## 5. Security Hardening

Based on Lynis audit recommendations.

### Enable firewall

```bash
sudo systemctl enable --now ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw enable
```

### SSH hardening

Create `/etc/ssh/sshd_config.d/50-hardening.conf`:
```bash
sudo tee /etc/ssh/sshd_config.d/50-hardening.conf << 'EOF'
AllowTcpForwarding no
ClientAliveCountMax 2
LogLevel VERBOSE
MaxAuthTries 3
MaxSessions 2
TCPKeepAlive no
AllowAgentForwarding no
EOF

sudo systemctl restart sshd
```

### Kernel hardening

Create `/etc/sysctl.d/99-security.conf`:
```bash
sudo tee /etc/sysctl.d/99-security.conf << 'EOF'
# Disable ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0

# Log martian packets
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# Restrict kernel pointer access
kernel.kptr_restrict = 2

# Disable TTY line discipline autoload
dev.tty.ldisc_autoload = 0

# Protect FIFOs and regular files in world-writable directories
fs.protected_fifos = 2
fs.protected_regular = 2

# Disable core dumps for setuid programs
fs.suid_dumpable = 0

# Disable Magic SysRq key
kernel.sysrq = 0

# Disable unprivileged BPF
kernel.unprivileged_bpf_disabled = 1

# Harden BPF JIT compiler
net.core.bpf_jit_harden = 2
EOF

sudo sysctl --system
```

### Security tools

Run vulnerability scan: `arch-audit`
Run rootkit scan: `sudo rkhunter --check`

## 6. Start Hyprland

```bash
start-hyprland
```

Key bindings:
- **SUPER + Enter** - Terminal (ghostty)
- **SUPER + D** - Application launcher (wofi)
- **SUPER + Q** - Close window
- **SUPER + 1-0** - Switch workspace
- **SUPER + SHIFT + E** - Exit Hyprland

## 7. DevPod Usage

### Start a dev environment

```bash
# From a git repo
devpod up https://github.com/user/project

# From local directory
devpod up ~/projects/myapp

# SSH into it
devpod ssh myapp
```

### Manage workspaces

```bash
devpod list                    # Show workspaces
devpod stop <name>             # Stop (keeps state)
devpod delete <name>           # Remove completely
devpod up <path> --recreate    # Rebuild from scratch
```

## 8. devcontainer.json Examples

Create `.devcontainer/devcontainer.json` in your project:

### Node.js project

```json
{
  "name": "Node Project",
  "image": "mcr.microsoft.com/devcontainers/javascript-node:20",
  "postCreateCommand": "npm install",
  "forwardPorts": [3000]
}
```

### Python project

```json
{
  "name": "Python Project",
  "image": "mcr.microsoft.com/devcontainers/python:3.12",
  "postCreateCommand": "pip install -r requirements.txt"
}
```

### React Native project

```json
{
  "name": "React Native",
  "image": "mcr.microsoft.com/devcontainers/javascript-node:20",
  "features": {
    "ghcr.io/devcontainers/features/java:1": { "version": "17" }
  },
  "postCreateCommand": "npm install"
}
```

### Full-stack with multiple features

```json
{
  "name": "Full Stack",
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
  "features": {
    "ghcr.io/devcontainers/features/node:1": { "version": "20" },
    "ghcr.io/devcontainers/features/python:1": { "version": "3.12" },
    "ghcr.io/devcontainers/features/docker-in-docker:2": {}
  },
  "containerEnv": {
    "NODE_ENV": "development"
  },
  "forwardPorts": [3000, 5000, 8080],
  "postCreateCommand": "npm install && pip install -r requirements.txt"
}
```

### Mount host dotfiles

```json
{
  "name": "With Dotfiles",
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
  "mounts": [
    "source=${localEnv:HOME}/.gitconfig,target=/home/vscode/.gitconfig,type=bind",
    "source=${localEnv:HOME}/.ssh,target=/home/vscode/.ssh,type=bind,readonly"
  ]
}
```

Browse features: https://containers.dev/features

## 9. Additional Software (Optional)

### VPN

```bash
yay -S mullvad-vpn-bin
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

Or use in containers:
```json
{
  "features": {
    "ghcr.io/devcontainers/features/node:1": {}
  },
  "postCreateCommand": "npm install -g @anthropic-ai/claude-code"
}
```

## Tips

### Check Docker is working

```bash
docker run hello-world
```

### Prune unused containers/images

```bash
docker system prune -a
```

### Backup strategy

Your host only has:
- `~/.ssh/` - SSH keys
- `~/.gnupg/` - GPG keys
- `~/.password-store/` - pass passwords
- `~/projects/` - your code (in git)
- `~/dotfiles/` - configuration (in git)

Everything else is reproducible from:
- This install script
- Your dotfiles repo
- Your project's devcontainer.json

## Comparison: Full vs DevPod Install

| Component | Full Install | DevPod Install |
|-----------|--------------|----------------|
| Desktop | Hyprland + full apps | Hyprland + minimal |
| Languages | Installed on host | In containers |
| Docker | Optional | Required |
| New project setup | Install deps | `devpod up` |
| Host pollution | Yes | No |
