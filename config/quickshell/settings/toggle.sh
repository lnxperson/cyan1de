#!/usr/bin/env bash
# Toggle Quickshell Settings, starting the daemon on first use.
if qs ipc -c settings call settings toggle >/dev/null 2>&1; then
    exit 0
fi

qs -c settings -d >/dev/null 2>&1
sleep 0.5
qs ipc -c settings call settings toggle >/dev/null 2>&1
