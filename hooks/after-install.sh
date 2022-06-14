#!/usr/bin/env bash
set -uo pipefail

NIX_BUILD_GROUP_NAME="nixbld"

# Setup group if it didn't exist (exit code 9 = it exists already)
getent group "$NIX_BUILD_GROUP_NAME" >/dev/null || groupadd --system "$NIX_BUILD_GROUP_NAME"

# Add build users (same as number of cores on the machine to scale with `max-jobs = auto`)
cores=$(nproc)
for i in $(seq 1 $(($cores>32 ? $cores : 32))); do
    username="nixbld$i"
    getent passwd "$username" >/dev/null || useradd \
      --home-dir /var/empty \
      --comment "Nix build user $i" \
      --gid "$NIX_BUILD_GROUP_NAME" \
      --no-user-group \
      --system \
      --shell /sbin/nologin \
      --password "!" \
      "$username"
done

set -e

if test -e /sys/fs/selinux; then
    semodule -i "/usr/share/selinux/packages/nix.pp"
fi

systemctl enable nix-daemon
# Make shell script exit with success regardless of systemd units failing to start immediately
systemctl start nix-daemon || true
