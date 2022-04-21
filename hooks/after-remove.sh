#!/usr/bin/env bash

grep '^nixbld' /etc/passwd | cut -d : -f 1 | while read user; do
    userdel "$user"
done
groupdel nixbld
rm -rf /var/nix
