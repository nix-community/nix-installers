{ pkgs ? (
    let
      flakeLock = builtins.fromJSON (builtins.readFile ../flake.lock);
    in
    import "${builtins.fetchTree flakeLock.nodes.nixpkgs.locked}" { }
  )
, lib ? pkgs.lib
}:

let
  systems = {
    "x86_64" = pkgs;
    "aarch64" = pkgs.pkgsCross.aarch64-multiplatform;
  };
  formats = lib.attrNames (import ../. { inherit pkgs lib; });

  # Map (format -> arch -> drv)
  # Example: deb -> aarch64 -> <<derivation: foo>>
  installers = lib.listToAttrs (map
    (
      fmt: {
        name = fmt;
        value = lib.mapAttrs (_: pkgs: (import ../. { inherit pkgs lib; }).${fmt}) systems;
      }
    )
    formats);

in
pkgs.runCommand "github-pages"
{
  inherit installers;
  __structuredAttrs = true;
  PATH = "${pkgs.coreutils}/bin:${pkgs.python3}/bin:${pkgs.pandoc}/bin";
  builder = builtins.toFile "builder"
    ''
      . .attrs.sh
      python3 ${./pages.py} ${../README.md} .attrs.json ''${outputs[out]}
    '';
}
  ""
