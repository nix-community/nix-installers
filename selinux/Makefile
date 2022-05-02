# Policies taken from https://github.com/NixOS/nix/pull/2670
all:
	checkmodule -M -m -c 5 -o nix.mod nix.te
	semodule_package -o nix.pp -m nix.mod -f nix.fc

clean:
	rm -f *.mod *.pp
