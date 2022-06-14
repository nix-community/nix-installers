# Nix-installers for legacy (imperative) distributions

Getting Nix onto legacy distributions can be difficult and the official installer
is not always a viable option, especially when considering reproducibility and automation.

This approach is different from others in that we:

- Package using distribution-native packaging formats (`deb`/`rpm`).
  And use these packages to manage systemd and environment integrations.

- Create a /nix/store imperatively as a postinstall hook.
  This uses a prepopulated Nix store embedded inside the distribution-native
  packaging format.

- Properly cleans up after uninstallation.
  We use package manager hooks to cleanly remove any traces of Nix post removal.

To achieve a reproducible setup for these distributions that doesn't rely on
pulling files from the internet at install-time.

These installer packages are intended to be used in a one-shot fashion to bootstrap the Nix installation, and then let Nix deal with managing itself from that point on.

## Usage

### Prebuilt installers
We provide prebuilt installers at [https://nix-community.github.io/nix-installers/](https://nix-community.github.io/nix-installers/)

### Flakes
``` bash
# Remote flake
$ nix build github:nix-community/nix-installers#deb
$ nix build github:nix-community/nix-installers#pacman
$ nix build github:nix-community/nix-installers#rpm

# In a cloned repository
$ nix build .#deb
$ nix build .#pacman
$ nix build .#rpm
```

### Classic Nix
``` bash
# In a cloned repository
$ nix-build ./. -A deb
$ nix-build ./. -A pacman
$ nix-build ./. -A rpm
```

## Contributing
[https://github.com/nix-community/nix-installers](https://github.com/nix-community/nix-installers)

## Installing on rpm-ostree distros

Nix requires a special top-level path `/nix` to work. This is not included in the [FHS](https://es.wikipedia.org/wiki/Filesystem_Hierarchy_Standard) and thus is not supported natively in [rpm-ostree](https://rpm-ostree.readthedocs.io/en/stable/)-based distros, such as [Fedora Silverblue](https://silverblue.fedoraproject.org/).

Provided RPM packages support special hacks to work fine with these distros, at least until upstream solves [the issue](https://github.com/coreos/rpm-ostree/issues/337) or [the nix store is moved to `/var/lib/nix` upstream](https://github.com/NixOS/rfcs/pull/17). These hacks consist in a combination of systemd units that create `/var/nix`, bind-mounts it on `/nix` and populate it the 1st time before starting nix-daemon.

These hacks also are used for non-rpm-ostree installations. They wouldn't be necessary, but they shouldn't harm.

Thus, to be able to use these packages in those distros, first download or build it. Then install it with:

```sh
rpm-ostree install --reboot ./nix-multi-user.rpm
```

As usual with these distros, [you need special handling for groups and users](https://docs.fedoraproject.org/en-US/fedora-silverblue/troubleshooting/#_unable_to_add_user_to_group) created by the package. These are needed for [nix multi-user mode](https://nixos.org/manual/nix/stable/installation/multi-user.html). After the previous reboot, do:

```sh
# Create nixbld group and users
grep -E '^nixbld:' /usr/lib/group | sudo tee -a /etc/group
grep -E '^nixbld' /usr/lib/passwd | sudo tee -a /etc/passwd
sudo groupmod nixbld -aU $(grep -oE '^nixbld[[:digit:]]+' /usr/lib/passwd | tr '\n' ,)

# Reboot again
systemctl reboot

# Verify all works
nix --version
nix-channel --update
nix-shell -p hello --run hello
```

After the next reboot, you should be able to use nix as usual.