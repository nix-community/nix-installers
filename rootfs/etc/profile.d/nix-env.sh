#!/bin/sh
# Prevent being sourced from child shells.
if [ -z "$__NIX_SET_ENVIRONMENT_DONE" ]; then
	# Avoid duplication of `PATH` entries.
	while :; do case "${PATH-}:" in
		${HOME:+"$HOME/.nix-profile/bin":*})
			PATH="${PATH}:"
			PATH="${PATH#$HOME/.nix-profile/bin:}"
			PATH="${PATH%:}"
			;;
		"/nix/var/nix/profiles/system/bin":*)
			PATH="${PATH}:"
			PATH="${PATH#/nix/var/nix/profiles/system/bin:}"
			PATH="${PATH%:}"
			;;
		"/nix/var/nix/profiles/default/bin":*)
			PATH="${PATH}:"
			PATH="${PATH#/nix/var/nix/profiles/default/bin:}"
			PATH="${PATH%:}"
			;;
		*) break ;;
	esac; done
	# Avoid duplication of `XDG_DATA_DIRS` entries.
	while :; do case "${XDG_DATA_DIRS-}:" in
		${HOME:+"$HOME/.nix-profile/share/":*})
			XDG_DATA_DIRS="${XDG_DATA_DIRS}:"
			XDG_DATA_DIRS="${XDG_DATA_DIRS#$HOME/.nix-profile/share/:}"
			XDG_DATA_DIRS="${XDG_DATA_DIRS%:}"
			;;
		"/nix/var/nix/profiles/system/share/":*)
			XDG_DATA_DIRS="${XDG_DATA_DIRS}:"
			XDG_DATA_DIRS="${XDG_DATA_DIRS#/nix/var/nix/profiles/system/share/:}"
			XDG_DATA_DIRS="${XDG_DATA_DIRS%:}"
			;;
		"/nix/var/nix/profiles/default/share/":*)
			XDG_DATA_DIRS="${XDG_DATA_DIRS}:"
			XDG_DATA_DIRS="${XDG_DATA_DIRS#/nix/var/nix/profiles/default/share/:}"
			XDG_DATA_DIRS="${XDG_DATA_DIRS%:}"
			;;
		*) break ;;
	esac; done
	# Ensure environment variables are exported.
	if [ "$-" != "${-%%a*}" ]; then
		. /usr/lib/environment.d/nix.conf
	else
		set -a
		. /usr/lib/environment.d/nix.conf
		set +a
	fi
fi
