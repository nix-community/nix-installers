#!/bin/sh
# Prevent being sourced from child shells.
if [ -z "$__NIX_DAEMON_SET_ENVIRONMENT_DONE" ]; then
	# Ensure environment variables are exported.
	if [ "$-" != "${-%%a*}" ]; then
		. /usr/lib/environment.d/nix-daemon.conf
	else
		set -a
		. /usr/lib/environment.d/nix-daemon.conf
		set +a
	fi
fi
