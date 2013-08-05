#!/bin/bash

if [[ -z "$1" ]]
then
    echo "Usage: `basename $0` <atom> <keywords>"
    exit
fi

echo "$@" >> /etc/portage/package.accept_keywords

