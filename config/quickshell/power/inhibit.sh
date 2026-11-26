#!/usr/bin/env bash
# Toggle the idle inhibitor by starting/stopping hypridle.
set -u

pidfile="$HOME/.config/quickshell/power/idle.pid"
state_dir="${XDG_RUNTIME_DIR:-$HOME/.cache}/cyan1de"
state_file="$state_dir/idle.state"

mkdir -p "$(dirname "$pidfile")" "$state_dir"

write_state() {
    if [ "$1" = "1" ]; then
        printf '1\n' > "$state_file"
    else
        printf '0\n' > "$state_file"
    fi
}

pid_alive() {
    [ -f "$pidfile" ] || return 1
    local pid
    pid=$(cat "$pidfile" 2>/dev/null || true)
    [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
}

stop() {
    if [ -f "$pidfile" ]; then
        local pid
        pid=$(cat "$pidfile" 2>/dev/null || true)
        if [ -n "$pid" ]; then
            kill "$pid" 2>/dev/null || true
        fi
        rm -f "$pidfile"
    fi
    write_state 0
}

if pid_alive; then
    stop
    exit 0
fi

# Clear a stale indicator before starting a fresh managed hypridle process.
rm -f "$pidfile"
write_state 0
hypridle -c "$HOME/.config/hypr/hypridle.conf" >/dev/null 2>&1 &
echo $! > "$pidfile"
write_state 1
