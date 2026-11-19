#!/usr/bin/env bash
# Small adapter for power-profiles-daemon. Prints JSON so QML never has to
# parse powerprofilesctl's human-oriented list output.
set -uo pipefail

unavailable='{"available":false,"profile":"","profiles":[]}'

if ! command -v powerprofilesctl >/dev/null 2>&1; then
    printf '%s\n' "$unavailable"
    exit 0
fi
if ! systemctl --user is-active --quiet power-profiles-daemon.service 2>/dev/null; then
    printf '%s\n' "$unavailable"
    exit 0
fi

case "${1:-status}" in
    status)
        profile="$(powerprofilesctl get 2>/dev/null | head -1)"
        profile="$(printf '%s' "$profile" | sed 's/^[[:space:]]*\*\?[[:space:]]*//; s/[[:space:]]*$//')"

        profiles="$(powerprofilesctl list 2>/dev/null | awk '
            /^[[:space:]]*\*?[[:space:]]*[A-Za-z0-9_-]+:[[:space:]]*$/ {
                name = $0
                sub(/^[[:space:]]*/, "", name)
                sub(/^\*/, "", name)
                sub(/^[[:space:]]*/, "", name)
                sub(/:[[:space:]]*$/, "", name)
                gsub(/"/, "", name)
                printf "%s\"%s\"", (n++ ? "," : ""), name
            }
        ')"

        printf '{"available":true,"profile":"%s","profiles":[%s]}\n' "$profile" "$profiles"
        ;;
    set)
        target="${2:-}"
        if [ -n "$target" ]; then
            powerprofilesctl set "$target" >/dev/null 2>&1 || true
        fi
        ;;
    *)
        printf '%s\n' "$unavailable"
        ;;
esac
