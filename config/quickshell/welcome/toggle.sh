#!/usr/bin/env bash
# Toggle the cyan1de welcome guide, starting the daemon on first use.
if qs ipc -c welcome call welcome toggle >/dev/null 2>&1; then
    exit 0
fi

qs -c welcome -d >/dev/null 2>&1
sleep 0.5
qs ipc -c welcome call welcome toggle >/dev/null 2>&1
