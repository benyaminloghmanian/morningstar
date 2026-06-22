#!/bin/bash
cft=""
cfzid=""

while [ $# -gt 0 ]; do
    case "$1" in
        --cft)   cft="$2";   shift 2 ;;
        --cfzid) cfzid="$2"; shift 2 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

# enforce mandatory
if [ -z "$cft" ] || [ -z "$cfzid" ]; then
    echo "Usage: $0 --cft <value> --cfzid <value>" >&2
    exit 1
fi

echo "cft=$cft cfzid=$cfzid"