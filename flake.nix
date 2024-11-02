{
  description = "Build Nix bootstraping packages for legacy distributions";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      treefmt-nix,
      ...
    }:
    (
      let
        inherit (nixpkgs) lib;
        forSystems = lib.genAttrs [
          "x86_64-linux"
          "aarch64-linux"
        ];

      in
      {
        packages = forSystems (
          system:
          import self {
            pkgs = nixpkgs.legacyPackages.${system};
            inherit lib;
          }
        );

        checks = forSystems (
          system:
          let
            pkgs = nixpkgs.legacyPackages.${system};
          in
          {
            treefmt =
              pkgs.runCommand "treefmt-check"
                {
                  nativeBuildInputs = [ self.formatter.${system} ];
                }
                ''
                  cp -r ${self}/* .
                  env HOME=$(mktemp -d) treefmt --fail-on-change
                  touch $out
                '';
          }
        );

        formatter = forSystems (
          system:
          let
            pkgs = nixpkgs.legacyPackages.${system};
          in
          (treefmt-nix.lib.evalModule pkgs ./treefmt.nix).config.build.wrapper
        );

        devShells = forSystems (
          system:
          let
            pkgs = nixpkgs.legacyPackages.${system};
          in
          {
            default = pkgs.callPackage ./shell.nix { };
          }
        );
      }
    );

}
