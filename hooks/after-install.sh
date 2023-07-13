#!/usr/bin/env bash

set -e

# Create /nix/store if a fresh install, otherwise leave in place
if ! test -e /nix/var/nix/db; then
    tar -xpf /usr/share/nix/nix.tar.xz
    rm -f /usr/share/nix/nix.tar.xz
fi

# Inspired by https://github.com/NixOS/nix/pull/2670
if test -e /sys/fs/selinux; then
    # Install the Nix SELinux policy
    semodule -i "/usr/share/selinux/packages/nix.pp"

    # Relabel the SELinux security context
    restorecon -FR /nix

    # Reexec systemd (is this really required?)
    systemctl daemon-reexec
fi

if ! test -e /root/.nix-defexpr && test -e /nix/var/nix/profiles/per-user/root/channels; then
    mkdir -p $out/root/.nix-defexpr
    ln -s /nix/var/nix/profiles/per-user/root/channels /root/.nix-defexpr/channels
fi
if ! [[ "@channelURL@" = "" || "@channelName@" = "" ]] && ! test -e /root/.nix-channels; then
    echo "@channelURL@ @channelName@" > /root/.nix-channels
fi

# Enable autostart
systemctl enable nix-daemon
# Make shell script exit with success regardless of systemd units failing to start immediately
systemctl start nix-daemon || true
