#!/bin/bash
#
# Arch Linux T480s Installation Scripts
#
# This is NOT a single install script. The installation is split into phases.
# See README.md for full instructions.
#

echo "Arch Linux T480s Installation Scripts"
echo "======================================"
echo
echo "This installation is split into 4 scripts, run at different stages:"
echo
echo "  00-pre-chroot.sh      - Run from live USB (partitioning, pacstrap)"
echo "  01-chroot-setup.sh    - Run in arch-chroot (system config)"
echo "  02-post-reboot-root.sh - Run after reboot as root (packages, user)"
echo "  03-user-setup.sh      - Run as user (keys, dotfiles, AUR)"
echo
echo "Read README.md for detailed instructions."
echo
echo "Quick start (from live USB):"
echo "  chmod +x 00-pre-chroot.sh"
echo "  ./00-pre-chroot.sh"
echo
