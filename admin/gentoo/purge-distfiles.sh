#!/bin/bash

# Source Portage config
. /etc/portage/make.conf

# Delete everything (except dotfiles) in the distfiles directory
echo "  In $DISTIR:"
rm -RI ${DISTDIR:-/usr/portage/distfiles}/*

