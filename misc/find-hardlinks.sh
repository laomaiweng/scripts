#!/bin/bash

if [[ $# -lt 2 ]]
then
    echo "Usage: ${0##*/} <search root> <file>" >&2
    exit
fi

find "$1" -xdev -samefile "$2"

