{
  description = "Build Nix bootstraping packages for legacy distributions";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { nixpkgs, ... }: (
    let
      inherit (nixpkgs) lib;
      forSystems = lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
      ];

    in
    {
      packages = forSystems (system: import ./. {
        pkgs = nixpkgs.legacyPackages.${system};
        inherit lib;
      });

      devShells = forSystems (system: import ./. {
        pkgs = nixpkgs.legacyPackages.${system};
        inherit lib;
      });
    }
  );

}
