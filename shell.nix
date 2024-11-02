{
  pkgs ? (
    let
      flakeLock = builtins.fromJSON (builtins.readFile ./flake.lock);
    in
    import "${builtins.fetchTree flakeLock.nodes.nixpkgs.locked}" { }
  ),
}:

let
  pythonEnv = pkgs.python3.withPackages (_ps: [ ]);

in
pkgs.mkShell {
  packages = [
    pkgs.nixpkgs-fmt

    pkgs.libselinux
    pkgs.semodule-utils
    pkgs.checkpolicy

    pkgs.reuse

    pythonEnv
  ];
}
