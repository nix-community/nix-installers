#!/usr/bin/env bash
set -euo pipefail

# Inspired by https://github.com/NixOS/nix/pull/2670
if test -e /sys/fs/selinux; then
    # Install the Nix SELinux policy
    semodule -i "/usr/share/selinux/packages/nix.pp"
fi

# Enable autostart
systemctl enable nix-daemon
# Make shell script exit with success regardless of systemd units failing to start immediately
systemctl start nix-daemon || true
