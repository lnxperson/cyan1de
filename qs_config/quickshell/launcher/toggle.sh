#!/usr/bin/env bash
# Toggle the Quickshell launcher, starting its daemon on first use.

if qs ipc -c launcher call launcher toggle >/dev/null 2>&1; then
    exit 0
fi

qs -c launcher -d >/dev/null 2>&1
sleep 0.4
qs ipc -c launcher call launcher toggle >/dev/null 2>&1
