#!/bin/bash

if [ "$1" == "stdout" ]; then
    IN=${2:-"fodase.out"}
    rg -No 'cid:  \| (\d+) \|' -r '$1' $IN \
        | sort -n | awk 'NR==1{prev=$1; next} {for(i=prev+1;i<$1;i++) print i; prev=$1}';
        # tee $IN.out
elif [ "$1" == "jsonout" ]; then
    IN=${2:-"medicina.out"}
    jq 'keys | map(tonumber) | sort' $IN | rg -N '\s+(\d+),' -r '$1' \
        | sort -n | awk 'NR==1{prev=$1; next} {for(i=prev+1;i<$1;i++) print i; prev=$1}';
else
    echo "${0##*/} <stdout|jsonout>"
fi
