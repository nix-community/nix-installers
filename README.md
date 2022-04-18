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
