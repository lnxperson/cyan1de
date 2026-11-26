#!/usr/bin/env bash
# Toggle the idle inhibitor by starting/stopping hypridle.
set -u

pidfile="$HOME/.config/quickshell/power/idle.pid"

stop() {
    if [ -f "$pidfile" ]; then
        pid=$(cat "$pidfile")
        kill "$pid" 2>/dev/null
        rm -f "$pidfile"
    fi
    exit 0
}

if [ -f "$pidfile" ]; then
    pid=$(cat "$pidfile")
    if kill -0 "$pid" 2>/dev/null; then
        stop
    fi
    rm -f "$pidfile"
fi

hypridle -c "$HOME/.config/hypr/hypridle.conf" >/dev/null 2>&1 &
echo $! > "$pidfile"
