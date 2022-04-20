{ pkgs ? (
    let
      flakeLock = builtins.fromJSON (builtins.readFile ../flake.lock);
    in
      import "${builtins.fetchTree flakeLock.nodes.nixpkgs.locked}" { }
  )
, lib ? pkgs.lib
}:

let
  installers = import ../. { inherit pkgs lib; };

in pkgs.runCommand "github-pages" { } ''
  mkdir $out
  echo "foo" > $out/index.html
''
