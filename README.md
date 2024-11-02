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
# Remote flake (Lix)
$ nix build github:nix-community/nix-installers#lix-deb
$ nix build github:nix-community/nix-installers#lix-pacman
$ nix build github:nix-community/nix-installers#lix-rpm

# Remote flake (Nix)
$ nix build github:nix-community/nix-installers#nix-deb
$ nix build github:nix-community/nix-installers#nix-pacman
$ nix build github:nix-community/nix-installers#nix-rpm
```

### Classic Nix
``` bash
# In a cloned repository (Lix)
$ nix build .#lix.deb
$ nix build .#lix.pacman
$ nix build .#lix.rpm

# In a cloned repository (Nix)
$ nix build .#nix.deb
$ nix build .#nix.pacman
$ nix build .#nix.rpm
```

## Contributing
[https://github.com/nix-community/nix-installers](https://github.com/nix-community/nix-installers)
