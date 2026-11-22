#!/usr/bin/env bash
# Toggle a lightweight desktop by stopping every Quickshell config except the
# lockscreen. Pressing the shortcut again restores exactly what was stopped.
set -u

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"
STATE_DIR="$CONFIG_HOME/performance"
ACTIVE_FILE="$STATE_DIR/active"

DEFAULT_CONFIGS=(topbar osd launcher emoji background settings notifications welcome)

mkdir -p "$STATE_DIR"

notify() {
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -u low "Performance mode" "$1" >/dev/null 2>&1 || true
    fi
}

running_configs() {
    ps -eo comm=,args= | awk '
        $1 == "qs" {
            for (i = 2; i <= NF; i++) {
                if ($i == "-c" && (i + 1) <= NF) {
                    print $(i + 1)
                    break
                }
            }
        }
    ' | sort -u
}

non_lockshell_pids() {
    ps -eo pid=,comm=,args= | awk '
        $2 == "qs" {
            name = ""
            for (i = 3; i <= NF; i++) {
                if ($i == "-c" && (i + 1) <= NF) {
                    name = $(i + 1)
                    break
                }
            }
            if (name != "" && name != "lockscreen")
                print $1
        }
    '
}

start_config() {
    local name="$1"
    case "$name" in
        ""|lockscreen) return 0 ;;
    esac
    qs -c "$name" -d >/dev/null 2>&1
}

disable() {
    local name
    : > "$ACTIVE_FILE"

    while IFS= read -r name; do
        case "$name" in
            ""|lockscreen) continue ;;
        esac
        printf '%s\n' "$name" >> "$ACTIVE_FILE"
    done <<< "$(running_configs)"

    while IFS= read -r pid; do
        [ -n "$pid" ] && kill "$pid" 2>/dev/null || true
    done < <(non_lockshell_pids)

    notify "on — Quickshell stopped, lockscreen kept"
}

restore() {
    local name started=" "

    for name in "${DEFAULT_CONFIGS[@]}"; do
        if grep -qxF "$name" "$ACTIVE_FILE"; then
            start_config "$name"
            started="$started$name "
        fi
    done

    while IFS= read -r name; do
        case "$started" in
            *" $name "*) continue ;;
        esac
        start_config "$name"
    done < "$ACTIVE_FILE"

    rm -f "$ACTIVE_FILE"
    notify "off — Quickshell restored"
}

if [ -f "$ACTIVE_FILE" ]; then
    restore
else
    disable
fi
