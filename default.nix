{ pkgs ? (
    let
      flakeLock = builtins.fromJSON (builtins.readFile ./flake.lock);
    in
    import "${builtins.fetchTree flakeLock.nodes.nixpkgs.locked}" { }
  )
, lib ? pkgs.lib
}:

let
  inherit (pkgs) stdenv;
  inherit (builtins) elem baseNameOf;

  channel' = pkgs.runCommand "channel-nixpkgs" { } ''
    mkdir $out
    ln -s ${pkgs.path} $out/nixpkgs
    echo "[]" > $out/manifest.nix
  '';

  selinux' =
    let
      ignores = [
        "nix.mod"
        "nix.pp"
      ];
      checkIgnore = f: ! elem (baseNameOf f) ignores;
    in
    stdenv.mkDerivation {
      name = "nix-selinux";
      src = builtins.filterSource (f: t: t == "regular" && checkIgnore f) ./selinux;

      nativeBuildInputs =
        let
          inherit (pkgs.buildPackages) libselinux semodule-utils checkpolicy;
        in
        [
          libselinux
          semodule-utils
          checkpolicy
        ];

      dontConfigure = true;

      installPhase = ''
        runHook preInstall
        mkdir $out
        cp nix.pp $out/
        runHook postInstall
      '';
    };

  buildNixTarball = (
    { nix ? pkgs.nix
    , cacert ? pkgs.cacert
    , drvs ? [ ]
    , channel ? channel'
    }:
    let

      contents = [ nix cacert ] ++ drvs;

      # Packages used during build
      # These are not necessarily the same as the ones used in the output
      # for cases such as cross compilation
      buildPackages = {
        inherit (pkgs.buildPackages) nix;
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
        rootPaths = [ profile ] ++ lib.optional (channel != null) channel;
      };

    in
    pkgs.runCommand "nix-root.tar.xz"
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
      rm -r nix/var/nix/profiles/per-user/nixbld
      chmod -R 755 nix/var/nix/profiles/per-user

      for path in $(cat ${closure}/store-paths); do
        cp -va $path nix/store/
      done

      # Create a tarball with the Nix store for bootstraping
      XZ_OPT="-T$NIX_BUILD_CORES" tar --owner=0 --group=0 --lzma -c -p -f $out nix
    ''
  );

  buildLegacyPkg = lib.makeOverridable (
    { type
    , nix ? pkgs.nix
    , tarball ? buildNixTarball { inherit channel nix; }
    , pname ? "nix-multi-user"
    , ext ? {
        "pacman" = "pkg.tar.zst";
      }.${type} or type
    , selinux ? selinux'
    , channel ? channel'
    , channelName ? "nixpkgs"
    , channelURL ? "https://nixos.org/channels/nixpkgs-unstable"
    }: pkgs.runCommand "${pname}-${nix.version}.${ext}"
      {
        nativeBuildInputs =
          let
            inherit (pkgs.buildPackages) fakeroot fpm rpm libarchive zstd;
            inherit (pkgs.buildPackages.buildPackages) binutils-unwrapped;
          in
          [
            fakeroot
            fpm
          ]
          ++ lib.optional (type == "deb") binutils-unwrapped
          ++ lib.optional (type == "rpm") rpm
          ++ lib.optionals (type == "pacman") [ libarchive zstd ]
        ;

        inherit pname;
        inherit (nix) version;

        passthru = {
          inherit tarball selinux channel channelName channelURL;
        };
      } ''
      export HOME=$(mktemp -d)

      # Setup root fs
      cp -a ${./rootfs} rootfs
      find rootfs -type f | xargs chmod 644
      find rootfs -type d | xargs chmod 755

      cp ${tarball} rootfs/usr/share/nix/nix.tar.xz

      chmod +x rootfs/etc/profile.d/nix-env.sh
      chmod +x rootfs/usr/share/nix/nix-setup

      mkdir -p rootfs/usr/share/selinux/packages
      cp ${selinux}/nix.pp rootfs/usr/share/selinux/packages/

      # For rpm nix-setup.service will create the directory
      test "${type}" == rpm || mkdir -p rootfs/nix/var/nix/daemon-socket

      ${lib.optionalString (channel != null) ''
        mkdir -p rootfs/nix/var/nix/profiles/per-user/root
        ln -s ${channel} rootfs/nix/var/nix/profiles/per-user/root/channels-1-link
        ln -s /nix/var/nix/profiles/per-user/root/channels-1-link rootfs/nix/var/nix/profiles/per-user/root/channels
      ''}

      # Create package
      fakeroot fpm \
        -a ${stdenv.targetPlatform.linuxArch} \
        -s dir \
        -t ${type} \
        --name ${pname} \
        --version ${nix.version} \
        --after-install ${pkgs.substituteAll { src = ./hooks/after-install.sh; inherit channelName channelURL; }} \
        --after-remove ${./hooks/after-remove.sh} \
        -C rootfs \
        .

      mv *.${ext} $out
    ''
  );

in
{

  deb = buildLegacyPkg { type = "deb"; };

  pacman = buildLegacyPkg { type = "pacman"; };

  rpm = buildLegacyPkg { type = "rpm"; channel = null; };

}
