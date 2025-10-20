{
  pkgs ? (
    let
      flakeLock = builtins.fromJSON (builtins.readFile ./flake.lock);
    in
    import "${builtins.fetchTree flakeLock.nodes.nixpkgs.locked}" { }
  ),
  lib ? pkgs.lib,
}:

let
  inherit (builtins)
    baseNameOf
    elem
    filterSource
    map
    ;
  inherit (lib.customisation) makeOverridable;
  inherit (lib.lists) optional optionals;
  inherit (lib.strings) concatStringsSep escapeNixString escapeNixIdentifier;

  channel' = pkgs.runCommand "channel-nixpkgs" { } ''
    mkdir "$out"
    ln -s "${pkgs.path}" "$out"/nixpkgs
    echo "[]" > "$out"/manifest.nix
  '';

  selinux' =
    let
      ignores = [
        "nix.mod"
        "nix.pp"
      ];
      checkIgnore = f: !elem (baseNameOf f) ignores;
    in
    pkgs.stdenv.mkDerivation {
      name = "nix-selinux";
      src = filterSource (f: t: t == "regular" && checkIgnore f) ./selinux;

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
        mkdir "$out"
        cp nix.pp "$out"/
        runHook postInstall
      '';
    };

  buildNixTarball =
    {
      nix ? pkgs.nix,
      cacert ? pkgs.cacert,
      drvs ? [ ],
      systemDrvs ? [ ],
      channel ? channel',
    }:
    let

      defaultProfileContents = [ cacert ] ++ drvs;
      systemProfileContents = [ nix ] ++ systemDrvs;

      # Packages used during build
      # These are not necessarily the same as the ones used in the output
      # for cases such as cross compilation
      buildPackages = {
        inherit (pkgs.buildPackages) nix sqlite;
      };

      mkProfile =
        { contents, name }:
        let
          env = pkgs.buildEnv {
            name = "${name}-profile-env";
            paths = contents;
          };
        in
        pkgs.runCommand "${name}-profile-environment" { } ''
          mkdir "$out"
          for file in "${env}"/*; do
            cp -a "$file" "$out"/
          done
          cat > "$out"/manifest.nix <<EOF
          [
          ${concatStringsSep "\n" (
            map (
              drv:
              let
                outputs = drv.outputsToInstall or [ "out" ];
              in
              ''
                {
                  ${concatStringsSep "\n" (
                    map (output: ''
                      ${escapeNixIdentifier output}.outPath = ${escapeNixString (lib.getOutput output drv)};
                    '') outputs
                  )}
                  outputs = [ ${concatStringsSep " " (map escapeNixString outputs)} ];
                  name = ${escapeNixString drv.name};
                  outPath = ${escapeNixString drv};
                  system = ${escapeNixString drv.system};
                  type = "derivation";
                  meta = { };
                }
              ''
            ) contents
          )}
          ]
          EOF
        '';

      defaultProfile = mkProfile {
        contents = defaultProfileContents;
        name = "default";
      };
      systemProfile = mkProfile {
        contents = systemProfileContents;
        name = "system";
      };

      closure = pkgs.closureInfo {
        rootPaths = [
          systemProfile
          defaultProfile
        ]
        ++ optional (channel != null) channel;
      };

    in
    pkgs.runCommand "nix-root.tar.xz"
      {
        passthru = {
          inherit nix;
        };
      }
      ''
        export NIX_REMOTE=local?root="$PWD"

        # A user is required by nix
        # https://github.com/NixOS/nix/blob/9348f9291e5d9e4ba3c4347ea1b235640f54fd79/src/libutil/util.cc#L478
        export USER=nobody
        "${buildPackages.nix}"/bin/nix-store --load-db < "${closure}"/registration

        ln -s "${defaultProfile}" nix/var/nix/profiles/default
        ln -s "${systemProfile}" nix/var/nix/profiles/system
        chmod -R 755 nix/var/nix/profiles/per-user

        # Reset registration times to make the output reproducible
        ${buildPackages.sqlite}/bin/sqlite3 nix/var/nix/db/db.sqlite "UPDATE ValidPaths SET registrationTime = ''${SOURCE_DATE_EPOCH}"

        while IFS= read -r path; do
          cp -a "$path" nix/store/
        done < "${closure}"/store-paths

        # Create a tarball with the Nix store for bootstraping
        XZ_OPT="-T1" tar --owner=0 --group=0 --hard-dereference --sort=name --mtime="@''${SOURCE_DATE_EPOCH}" --lzma -c -p -f "$out" nix
      '';

  buildLegacyPkg = makeOverridable (
    {
      type,
      nix ? pkgs.nix,
      nixTarball ? buildNixTarball { inherit channel nix; },
      pname ? "nix-multi-user",
      ext ?
        {
          "pacman" = "pkg.tar.zst";
        }
        .${type} or type,
      selinux ? selinux',
      channel ? channel',
      channelName ? "nixpkgs",
      channelURL ? "https://nixos.org/channels/nixpkgs-unstable",
    }:
    pkgs.runCommand "${pname}-${nix.version}.${ext}"
      {
        nativeBuildInputs =
          let
            inherit (pkgs.buildPackages)
              fakeroot
              fpm
              rpm
              libarchive
              zstd
              ;
            inherit (pkgs.buildPackages.buildPackages) binutils-unwrapped;
          in
          [
            fakeroot
            fpm
          ]
          ++ optional (type == "deb") binutils-unwrapped
          ++ optional (type == "rpm") rpm
          ++ optionals (type == "pacman") [
            libarchive
            zstd
          ];

        inherit pname;
        inherit (nix) version;
        __structuredAttrs = true;

        env = {
          inherit
            channelName
            channelURL
            nixTarball
            selinux
            ;
          channel = toString channel;
          packageAfterInstall = pkgs.replaceVars ./hooks/after-install.sh {
            inherit channelName channelURL;
          };
          packageArch = pkgs.stdenv.targetPlatform.linuxArch;
          packageExt = ext;
          packageType = type;
          rootfs = "${./rootfs}";
        };

        passthru = {
          rootfs = ./rootfs;
        };
      }
      ''
        export HOME="$(mktemp -d)"

        # Setup root fs
        cp -a "$rootfs" rootfs
        find rootfs -type f -exec chmod 644 '{}' '+'
        find rootfs -type d -exec chmod 755 '{}' '+'

        mkdir -p rootfs/usr/share/nix
        cp "$nixTarball" rootfs/usr/share/nix/nix.tar.xz

        chmod +x rootfs/etc/profile.d/nix-env.sh

        mkdir -p rootfs/usr/share/selinux/packages
        cp "$selinux"/nix.pp rootfs/usr/share/selinux/packages/

        mkdir -p rootfs/nix/var/nix/daemon-socket

        case "$channel" in ''') ;; *)
          mkdir -p rootfs/nix/var/nix/profiles/per-user/root
          ln -s "$channel" rootfs/nix/var/nix/profiles/per-user/root/channels-1-link
          ln -s /nix/var/nix/profiles/per-user/root/channels-1-link rootfs/nix/var/nix/profiles/per-user/root/channels
        esac

        # Create package
        fakeroot fpm \
          -a "$packageArch" \
          -s dir \
          -t "$packageType" \
          --name "$pname" \
          --version "$version" \
          --after-install "$packageAfterInstall" \
          -C rootfs \
          .

        mv *."$packageExt" "$out"
      ''
  );

in
{

  nix =
    let
      pkg = pkgs.nix;
    in
    {
      deb = buildLegacyPkg {
        type = "deb";
        nix = pkg;
      };
      pacman = buildLegacyPkg {
        type = "pacman";
        nix = pkg;
      };
      rpm = buildLegacyPkg {
        type = "rpm";
        nix = pkg;
      };
    };

  lix =
    let
      args = {
        nix = pkgs.lixVersions.latest;
        pname = "lix-multi-user";
      };
    in
    {
      deb = buildLegacyPkg ({ type = "deb"; } // args);
      pacman = buildLegacyPkg ({ type = "pacman"; } // args);
      rpm = buildLegacyPkg ({ type = "rpm"; } // args);
    };

}
