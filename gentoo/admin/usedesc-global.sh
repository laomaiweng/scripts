#!/bin/bash

if [[ -z "$1" ]]
then
    echo "Usage: `basename $0` <global USE flag>"
    exit
fi

grep "^$1" /usr/portage/profiles/use.desc

