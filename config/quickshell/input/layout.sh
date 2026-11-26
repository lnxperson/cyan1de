#!/usr/bin/env bash
# Cycle through a small XKB layout list via Hyprland's keyword interface.
set -u

state="$HOME/.config/quickshell/input/layout.state"
layouts=("us" "fr")
cur="$(cat "$state" 2>/dev/null || echo us)"
idx=0
for i in "${!layouts[@]}"; do
    if [ "$cur" = "${layouts[$i]}" ]; then idx=$i; fi
done
next="${layouts[$(( (idx + 1) % ${#layouts[@]} ))]}"
echo "$next" > "$state"
hyprctl keyword input:kb_layout "$next"
