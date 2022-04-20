{ pkgs ? (
    let
      flakeLock = builtins.fromJSON (builtins.readFile ./flake.lock);
    in
    import "${builtins.fetchTree flakeLock.nodes.nixpkgs.locked}" { }
  )
, lib ? pkgs.lib
}:

pkgs.mkShell {
  packages = [
    pkgs.nixpkgs-fmt

    pkgs.libselinux
    pkgs.semodule-utils
    pkgs.checkpolicy
  ];
}
