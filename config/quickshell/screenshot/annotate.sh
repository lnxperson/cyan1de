#!/usr/bin/env bash
# Take a region screenshot, annotate it with swappy, and copy to the clipboard.
set -u

src="/tmp/cyan1de-shot.png"
annot="/tmp/cyan1de-shot-annotated.png"

if ! hyprshot -m region -f "$src" >/dev/null 2>&1; then
    exit 0
fi

if command -v swappy >/dev/null 2>&1; then
    swappy -f "$src" -o "$annot" >/dev/null 2>&1
fi

if [ -f "$annot" ]; then
    wl-copy < "$annot" 2>/dev/null
elif [ -f "$src" ]; then
    wl-copy < "$src" 2>/dev/null
fi
