{ pkgs ? (
    let
      flakeLock = builtins.fromJSON (builtins.readFile ./flake.lock);
    in
    import "${builtins.fetchTree flakeLock.nodes.nixpkgs.locked}" { }
  )
, lib ? pkgs.lib
}:

let
  pythonEnv = pkgs.python3.withPackages (ps: [ ps.black ps.mypy ]);
in
pkgs.mkShell {
  packages = [
    pkgs.nixpkgs-fmt

    pkgs.libselinux
    pkgs.semodule-utils
    pkgs.checkpolicy

    pythonEnv
  ];
}
