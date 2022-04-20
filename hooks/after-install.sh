#!/usr/bin/env bash

NIX_BUILD_GROUP_ID="30000"
NIX_BUILD_GROUP_NAME="nixbld"

# Setup group
groupadd -g "$NIX_BUILD_GROUP_ID" --system "$NIX_BUILD_GROUP_NAME"

# Add build users (same as number of cores on the machine to scale with `max-jobs = auto`)
cores=$(nproc)
for i in $(seq 1 $(($cores>32 ? $cores : 32))); do
    username="nixbld$i"
    uid=$((30000 + i))
    useradd \
      --home-dir /var/empty \
      --comment "Nix build user $i" \
      --gid "$NIX_BUILD_GROUP_ID" \
      --groups "$NIX_BUILD_GROUP_NAME" \
      --no-user-group \
      --system \
      --shell /sbin/nologin \
      --uid "$uid" \
      --password "!" \
      "$username"
done

# Create /nix/store if a fresh install, otherwise leave in place
if ! test -e /nix/var/nix/db; then
    tar -xzpf /usr/share/nix/nix.tar.gz
    rm -f /usr/share/nix/nix.tar.gz
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
systemctl start nix-daemon

# Make shell script exit with success regardless of systemd units failing to start immediately
true
