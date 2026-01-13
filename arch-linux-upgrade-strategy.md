# Arch Linux Upgrade Strategy

## Regular Updates

**Update frequently** (weekly or more) rather than letting updates pile up. Arch is rolling release, so smaller, frequent updates are safer than large infrequent ones.

```bash
sudo pacman -Syu
```

## Before Upgrading

1. **Check the Arch news** at https://archlinux.org/news/ for manual intervention notices
2. **Review pacman output** before confirming - watch for replaced packages or conflicts

## Best Practices

- **Never do partial upgrades** (`pacman -Sy package`) - always full system upgrade first
- **Keep your system bootable** - don't upgrade kernel without rebooting promptly, or keep the previous kernel installed
- **Handle .pacnew files** after upgrades:
  ```bash
  sudo pacdiff
  ```
- **Clean package cache periodically**:
  ```bash
  sudo paccache -r    # keeps last 3 versions
  ```

## AUR Packages

If using AUR helpers like `yay` or `paru`:

```bash
yay -Syu   # updates official + AUR packages
```

Rebuild AUR packages after major library updates (Python, etc.).

## Recovery Preparation

- Keep a bootable USB with Arch ISO handy
- **If using btrfs**: Set up snapper for automatic snapshots (see install guide). The `snap-pac` package creates pre/post snapshots on every pacman transaction, making rollbacks trivial.
- **linux-lts kernel**: Already installed as fallback. Select "Arch Linux (LTS)" from systemd-boot menu if main kernel breaks.

## If Something Breaks

1. Boot the LTS kernel from systemd-boot menu (select "Arch Linux (LTS)")
2. Chroot from live USB if needed
3. Check Arch forums/wiki for the specific issue

The key principle: stay current, read before updating, and don't skip intervention notices.
