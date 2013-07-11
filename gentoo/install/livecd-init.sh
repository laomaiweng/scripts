#!/bin/bash

mount -t proc none /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev

alias chroot-gentoo='chroot /mnt/gentoo /bin/bash'
