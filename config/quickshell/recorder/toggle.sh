#!/usr/bin/env bash
# Toggle a screen recording with wf-recorder. Records to ~/Videos as an mp4.
set -u

pidfile="$HOME/.config/quickshell/recorder/recording.pid"
outdir="$HOME/Videos"

mkdir -p "$outdir"

if [ -f "$pidfile" ]; then
    pid=$(cat "$pidfile")
    if kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null
        rm -f "$pidfile"
        exit 0
    fi
    rm -f "$pidfile"
fi

wf-recorder -f "$outdir/recording-$(date +%Y%m%d-%H%M%S).mp4" >/dev/null 2>&1 &
echo $! > "$pidfile"
hyprctl notify -u normal -i camera-photo -d "Recording" "Screen recording started"
