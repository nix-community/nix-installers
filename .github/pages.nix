{ pkgs ? (
    let
      flakeLock = builtins.fromJSON (builtins.readFile ../flake.lock);
    in
      import "${builtins.fetchTree flakeLock.nodes.nixpkgs.locked}" { }
  )
, lib ? pkgs.lib
}:

pkgs.runCommand "github-pages"
{
  installers = import ../. { inherit pkgs lib; };
  __structuredAttrs = true;
  PATH = "${pkgs.coreutils}/bin:${pkgs.python3}/bin:${pkgs.pandoc}/bin";
  builder = builtins.toFile "builder"
    ''
      . .attrs.sh
      python3 ${./pages.py} ${../README.md} .attrs.json ''${outputs[out]}
    '';
  }
  ""
