{ pkgs ? import <nixpkgs> { } }:

pkgs.mkShell {
  packages = [
    pkgs.nixpkgs-fmt

    pkgs.libselinux
    pkgs.semodule-utils
    pkgs.checkpolicy
  ];
}
