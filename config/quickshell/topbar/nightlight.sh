#!/bin/sh
# Night light helper for the Quickshell top bar.
# Uses hyprsunset's hyprctl IPC when available and keeps the user's enabled
# state and intensity in ~/.config/quickshell/nightlight.json.

set -u

store_path() {
    printf '%s/.config/quickshell/nightlight.json\n' "$HOME"
}

read_state() {
    python3 - "$(store_path)" <<'PY'
import json, sys

try:
    with open(sys.argv[1], encoding="utf-8") as f:
        data = json.load(f)
    if not isinstance(data, dict):
        data = {}
    enabled = 1 if data.get("enabled", False) else 0
    intensity = int(data.get("intensity", 60))
except Exception:
    enabled, intensity = 0, 60

print(enabled, max(0, min(100, intensity)))
PY
}

write_state() {
    enabled=$1
    intensity=$2

    python3 - "$(store_path)" "$enabled" "$intensity" <<'PY'
import json, os, sys

path, enabled, intensity = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
try:
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    if not isinstance(data, dict):
        data = {}
except Exception:
    data = {}

data["enabled"] = enabled == 1
data["intensity"] = max(0, min(100, intensity))
os.makedirs(os.path.dirname(path), exist_ok=True)
tmp = path + ".tmp"
with open(tmp, "w", encoding="utf-8") as f:
    json.dump(data, f, sort_keys=True, indent=2)
    f.write("\n")
os.replace(tmp, path)
PY
}

daemon_running() {
    pgrep -x hyprsunset >/dev/null 2>&1
}

ensure_daemon() {
    command -v hyprsunset >/dev/null 2>&1 || return 1
    if ! daemon_running; then
        setsid hyprsunset >/dev/null 2>&1 < /dev/null &
    fi

    attempts=0
    while [ "$attempts" -lt 30 ]; do
        hyprctl hyprsunset temperature >/dev/null 2>&1 && return 0
        attempts=$((attempts + 1))
        sleep 0.05
    done
    return 1
}

case "${1:-status}" in
    status)
        state=$(read_state)
        set -- $state
        enabled=${1:-0}
        intensity=${2:-60}
        if command -v hyprsunset >/dev/null 2>&1 && daemon_running; then
            available=1
        else
            available=0
        fi
        printf '%s %s %s\n' "$enabled" "$intensity" "$available"
        ;;

    intensity)
        state=$(read_state)
        set -- $state
        printf '%s\n' "${2:-60}"
        ;;

    enable)
        intensity=${2:-}
        if [ -z "$intensity" ]; then
            state=$(read_state)
            set -- $state
            intensity=${2:-60}
        fi
        intensity=$((intensity < 0 ? 0 : (intensity > 100 ? 100 : intensity)))
        kelvin=$((6500 - intensity * 40))

        if ! ensure_daemon; then
            echo "hyprsunset is unavailable" >&2
            exit 1
        fi
        if ! hyprctl hyprsunset temperature "$kelvin" >/dev/null 2>&1; then
            echo "could not set hyprsunset temperature" >&2
            exit 1
        fi
        write_state 1 "$intensity"
        ;;

    disable)
        if daemon_running; then
            hyprctl hyprsunset identity >/dev/null 2>&1 || true
        fi
        state=$(read_state)
        set -- $state
        write_state 0 "${2:-60}"
        ;;

    set)
        intensity=${2:-60}
        intensity=$((intensity < 0 ? 0 : (intensity > 100 ? 100 : intensity)))
        write_state "${3:-0}" "$intensity"
        ;;

    *)
        echo "usage: $0 {status|intensity|enable [0-100]|disable|set <0-100> <0|1>}" >&2
        exit 2
        ;;
esac
