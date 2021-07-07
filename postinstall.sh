#!/usr/bin/env bash

# Setup group
addgroup --system --gid 30000 nixbld

# Add build users (same as number of cores on the machine to scale with `max-jobs = auto`)
cores=$(nproc)
for i in $(seq 1 $(($cores>32 ? $cores : 32))); do
    adduser --system --disabled-password --disabled-login --home /var/empty --gecos "Nix build user $i" -u $((30000 + i)) --ingroup nixbld nixbld$i
    usermod -a -G nixbld nixbld$i
done

# Create /nix/store if a fresh install, otherwise leave in place
if ! test -e /nix/var/nix/db; then
    tar -xzpf /usr/share/nix/nix.tar.gz
fi

# Enable autostart
systemctl enable nix-daemon
systemctl start nix-daemon

# Make shell script exit with success regardless of systemd units failing to start immediately
true
