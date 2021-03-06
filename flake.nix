{
  description = "Build Nix bootstraping packages for legacy distributions";

  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs, flake-utils }: (
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        inherit (pkgs) lib;
      in
      {
        packages = import ./. { inherit pkgs lib; };
        devShell = import ./shell.nix { inherit pkgs lib; };
      }
    )
  );

}
