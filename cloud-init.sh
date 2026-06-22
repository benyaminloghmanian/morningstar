#!/bin/bash
cf-api-token=""
cf-zone-id=""

while [ $# -gt 0 ]; do
    case "$1" in
        --cf-api-token)   cf-api-token="$2";   shift 2 ;;
        --cf-zone-id) cf-zone-id="$2"; shift 2 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

# enforce mandatory
if [ -z "$cf-api-token" ] || [ -z "$cf-zone-id" ]; then
    echo "Usage: $0 --cf-api-token <value> --cf-zone-id <value>" >&2
    exit 1
fi

echo "cf-api-token=${cf-api-token} cf-zone-id=${cf-zone-id}"