#!/usr/bin/env bash
# Toggle the Quickshell emoji picker, starting its daemon on first use.

if qs ipc -c emoji call emoji toggle >/dev/null 2>&1; then
    exit 0
fi

qs -c emoji -d >/dev/null 2>&1
sleep 0.4
qs ipc -c emoji call emoji toggle >/dev/null 2>&1
