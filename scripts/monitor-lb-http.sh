#!/usr/bin/env bash
set -u

LB_IP="${LB_IP:-}"
COUNT="${COUNT:-60}"
INTERVAL="${INTERVAL:-2}"
TIMEOUT="${TIMEOUT:-3}"

if [[ -z "$LB_IP" ]]; then
    printf 'ERROR: LB_IP is required.\n' >&2
    exit 1
fi

for ((attempt = 1; attempt <= COUNT; attempt++)); do
    timestamp="$(date '+%H:%M:%S')"

    if response="$(curl -sS --max-time "$TIMEOUT" \
        -H 'Connection: close' "http://${LB_IP}/")"; then
        printf '%s | %s\n' "$timestamp" "$response"
    else
        printf '%s | REQUEST_FAILED\n' "$timestamp"
    fi

    if ((attempt < COUNT)); then
        sleep "$INTERVAL"
    fi
done
