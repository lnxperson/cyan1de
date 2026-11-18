#!/bin/sh
# Brightness helper for the Quickshell top bar.
# Hardware backlights and DDC/CI monitors are controlled through their real
# interfaces. Monitors without DDC/CI use a persisted software dimming value;
# this script never touches monitor hardware for those outputs.

set -u

store_path() {
    printf '%s/.config/quickshell/soft-brightness.json\n' "$HOME"
}

soft_get() {
    key=$1
    path=$(store_path)
    [ -f "$path" ] || { printf '100\n'; return 0; }

    python3 - "$path" "$key" <<'PY'
import json, sys

try:
    with open(sys.argv[1], encoding="utf-8") as f:
        data = json.load(f)
    if not isinstance(data, dict):
        data = {}
    value = int(data.get(sys.argv[2], 100))
except Exception:
    value = 100

print(max(0, min(100, value)))
PY
}

soft_set() {
    key=$1
    percent=$2
    path=$(store_path)

    python3 - "$path" "$key" "$percent" <<'PY'
import json, os, sys

path, key, value = sys.argv[1], sys.argv[2], int(sys.argv[3])
try:
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    if not isinstance(data, dict):
        data = {}
except Exception:
    data = {}

data[key] = value
os.makedirs(os.path.dirname(path), exist_ok=True)
tmp = path + ".tmp"
with open(tmp, "w", encoding="utf-8") as f:
    json.dump(data, f, sort_keys=True, indent=2)
    f.write("\n")
os.replace(tmp, path)
PY
}

list_backlights() {
    command -v brightnessctl >/dev/null 2>&1 || return 0
    for dir in /sys/class/backlight/*; do
        [ -e "$dir" ] || continue
        name=$(basename "$dir")
        cur=$(brightnessctl -d "$name" get 2>/dev/null) || continue
        max=$(brightnessctl -d "$name" max 2>/dev/null) || continue
        [ -n "$cur" ] && [ -n "$max" ] || continue
        printf 'backlight:%s\tInternal display (%s)\t%s\tbacklight\n' "$name" "$name" "$name"
    done
}

clean_monitor_label() {
    # VENDOR:MODEL:serial -> VENDOR MODEL
    sed -e 's/:[^:]*$//' -e 's/:/ /g'
}

connector_from_line() {
    printf '%s\n' "$1" | sed -e 's/^.*DRM connector:[[:space:]]*//' -e 's/^card[0-9]*-//'
}

bus_from_line() {
    printf '%s\n' "$1" | sed -e 's#^.*/i2c-##'
}

list_ddc() {
    command -v ddcutil >/dev/null 2>&1 || return 0

    id=""
    valid=0
    connector=""
    bus=""
    monitor=""

    ddcutil detect --brief 2>/dev/null | while IFS= read -r line; do
        case "$line" in
            "Display "*)
                id=$(printf '%s\n' "$line" | awk '{print $2}')
                valid=1
                connector=""
                monitor=""
                ;;
            "Invalid display"*)
                id=""
                valid=0
                connector=""
                bus=""
                monitor=""
                ;;
        esac

        case "$line" in
            *"I2C bus:"*)
                bus=$(bus_from_line "$line")
                ;;
            *"DRM connector:"*)
                connector=$(connector_from_line "$line")
                ;;
            *"Monitor:"*)
                monitor=$(printf '%s\n' "$line" | sed -e 's/^.*Monitor:[[:space:]]*//' | clean_monitor_label)
                [ -n "$monitor" ] || continue

                label="$monitor"
                [ -n "$connector" ] && label="$label ($connector)"

                if [ "$valid" -eq 1 ] && [ -n "$id" ]; then
                    printf 'ddc:%s\t%s\t%s\tddc\n' "$id" "$label" "$connector"
                else
                    # No DDC/CI: fall back to a software dimming overlay. The
                    # connector is the stable per-output key when available.
                    key=${connector:-bus$bus}
                    [ -n "$key" ] || continue
                    printf 'software:%s\t%s\t%s\tsoftware\n' "$key" "$label" "$connector"
                fi
                ;;
        esac
    done
}

case "${1:-}" in
    list)
        list_backlights
        list_ddc
        ;;

    get)
        id=${2:-}
        case "$id" in
            backlight:*)
                name=${id#backlight:}
                cur=$(brightnessctl -d "$name" get 2>/dev/null) || exit 1
                max=$(brightnessctl -d "$name" max 2>/dev/null) || exit 1
                awk -v c="$cur" -v m="$max" 'BEGIN {
                    if (m > 0) { printf "%d\n", int(c * 100 / m + 0.5); exit 0 }
                    exit 1
                }'
                ;;
            ddc:*)
                display=${id#ddc:}
                out=$(ddcutil --display "$display" getvcp 10 --brief 2>/dev/null) || exit 1
                printf '%s\n' "$out" | awk 'NF >= 5 && $5 > 0 {
                    printf "%d\n", int($4 * 100 / $5 + 0.5);
                    found = 1;
                    exit
                }
                END { if (!found) exit 1 }'
                ;;
            software:*)
                soft_get "${id#software:}"
                ;;
            *)
                exit 1
                ;;
        esac
        ;;

    set)
        id=${2:-}
        percent=${3:-}
        case "$percent" in
            ''|*[!0-9]*) exit 1 ;;
        esac
        [ "$percent" -ge 0 ] && [ "$percent" -le 100 ] || exit 1

        case "$id" in
            backlight:*)
                name=${id#backlight:}
                brightnessctl -d "$name" set "$percent%" >/dev/null 2>&1
                ;;
            ddc:*)
                display=${id#ddc:}
                ddcutil --display "$display" setvcp 10 "$percent" --noverify >/dev/null 2>&1
                ;;
            software:*)
                soft_set "${id#software:}" "$percent"
                ;;
            *)
                exit 1
                ;;
        esac
        ;;

    *)
        echo "usage: $0 list|get ID|set ID PERCENT" >&2
        exit 2
        ;;
esac
