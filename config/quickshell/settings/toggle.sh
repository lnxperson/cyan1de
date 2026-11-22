#!/usr/bin/env bash
# Toggle Quickshell Settings, starting the daemon on first use.
# The daemon stays resident after closing, so later toggles are IPC-only.
if qs ipc -c settings call settings toggle >/dev/null 2>&1; then
    exit 0
fi

qs -c settings -d >/dev/null 2>&1

# Wait for the IPC socket instead of sleeping a fixed half second.
for _ in 1 2 3 4 5 6 7 8 9 10; do
    sleep 0.05
    if qs ipc -c settings call settings toggle >/dev/null 2>&1; then
        exit 0
    fi
done

exit 1
