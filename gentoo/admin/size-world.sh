#!/bin/bash

qsize -a | awk -- '{ print $6 "   " $0 ; }' - | sort -gr -

