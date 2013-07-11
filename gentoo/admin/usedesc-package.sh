#!/bin/bash

if [[ -z "$1" ]]
then
    echo "Usage: `basename $0` <package>"
    exit
fi

grep "$1:" /usr/portage/profiles/use.local.desc

