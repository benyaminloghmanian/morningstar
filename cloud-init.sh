#!/bin/bash
cftoken=""
cfzoneid=""

while [ $# -gt 0 ]; do
    case "$1" in
        --cftoken)   cftoken="$2";   shift 2 ;;
        --cfzoneid) cfzoneid="$2"; shift 2 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

# enforce mandatory
if [ -z "$cftoken" ] || [ -z "$cfzoneid" ]; then
    echo "Usage: $0 --cftoken <value> --cfzoneid <value>" >&2
    exit 1
fi

echo "cftoken=${cftoken} cfzoneid=${cfzoneid}"