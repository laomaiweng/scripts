#!/bin/bash

# Source Portage config
. /etc/portage/make.conf

# Delete everything (except dotfiles) in the distfiles directory
rm -RI ${DISTDIR:-/usr/portage/distfiles}/*

