{
  description = "Build Nix bootstraping packages for legacy distributions";

  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.nixpkgs.url = "github:tweag/nixpkgs/fpm-1_13_0";

  outputs = { self, nixpkgs, flake-utils }: (
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        inherit (pkgs) lib;

        version = "0.1";

        buildNixTarball = (
          { nix ? pkgs.nixFlakes
          , drvs ? [ ]
          }:
          let

            contents = [ nix ] ++ drvs;

            # Packages used during build
            # These are not necessarily the same as the ones used in the output
            # for cases such as cross compilation
            buildPackages = {
              inherit (pkgs) nix;
            };

            profile =
              let
                rootEnv = pkgs.buildEnv {
                  name = "root-profile-env";
                  paths = contents;
                };
              in
              pkgs.runCommand "user-environment" { } ''
                mkdir $out
                cp -a ${rootEnv}/* $out/
                cat > $out/manifest.nix <<EOF
                [
                ${lib.concatStringsSep "\n" (builtins.map (drv: let
                  outputs = drv.outputsToInstall or [ "out" ];
                in ''
                  {
                    ${lib.concatStringsSep "\n" (builtins.map (output: ''
                      ${output} = { outPath = "${lib.getOutput output drv}"; };
                    '') outputs)}
                    outputs = [ ${lib.concatStringsSep " " (builtins.map (x: "\"${x}\"") outputs)} ];
                    name = "${drv.name}";
                    outPath = "${drv}";
                    system = "${drv.system}";
                    type = "derivation";
                    meta = { };
                  }
                '') contents)}
                ]
                EOF
              '';

            closure = pkgs.closureInfo {
              rootPaths = profile;
            };

          in
          pkgs.runCommand "nix-root.tar.gz"
            {
              passthru = {
                inherit nix;
              };
            } ''
            export NIX_REMOTE=local?root=$PWD

            # A user is required by nix
            # https://github.com/NixOS/nix/blob/9348f9291e5d9e4ba3c4347ea1b235640f54fd79/src/libutil/util.cc#L478
            export USER=nobody
            ${buildPackages.nix}/bin/nix-store --load-db < ${closure}/registration

            mkdir -p nix/var/nix/profiles nix/var/nix/gcroots/profiles
            ln -s ${profile} nix/var/nix/gcroots/default
            ln -s ${profile} nix/var/nix/profiles/default
            ln -s ${profile} nix/var/nix/profiles/system

            for path in $(cat ${closure}/store-paths); do
              cp -va $path nix/store/
            done

            # Create a tarball with the Nix store for bootstraping
            tar -cpzf $out nix
          ''
        );

        buildLegacyPkg = (
          {
            type
            , tarball
          }: pkgs.runCommand "nix-setup-${version}.${type}"
            {
              nativeBuildInputs = [
                pkgs.fpm
              ]
              ++ lib.optional (type == "deb") pkgs.binutils
              ++ lib.optional (type == "rpm") pkgs.rpm;
            } ''
            export HOME=$(mktemp -d)

            # Setup root fs
            cp -a ${./rootfs} rootfs
            find rootfs -type f | xargs chmod 644
            find rootfs -type d | xargs chmod 755
            mkdir -p rootfs/usr/share/nix
            cp ${tarball} rootfs/usr/share/nix/nix.tar.gz

            chmod +x rootfs/etc/profile.d/nix-env.sh

            # Create package
            ${pkgs.fakeroot}/bin/fakeroot fpm \
              -s dir \
              -t ${type} \
              --name nix-setup \
              --version ${version} \
              --after-install ${./postinstall.sh} \
              -C rootfs \
              .

            mv *.${type} $out
          ''
        );

        packages = lib.fix (self: {

          tarball = buildNixTarball { };

          deb = buildLegacyPkg {
            type = "deb";
            inherit (self) tarball;
          };

          # Note: Needs additional work
          # rpm = buildLegacyPkg {
          #   type = "rpm";
          #   inherit (self) tarball;
          # };

        });

      in
      {
        inherit packages;
        defaultPackage = packages.deb;
      }

    )
  );
}
