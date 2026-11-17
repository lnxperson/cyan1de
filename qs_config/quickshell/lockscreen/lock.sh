#!/usr/bin/env bash
# Launch the Quickshell lockscreen with a crash watchdog.
#
# If the lockscreen process exits without unlocking (crash, protocol error,
# killed), Hyprland is left on its "lockscreen app died" failsafe page. Ask
# Hyprland to clear that crashed lock so the session is usable again.

if pgrep -f "qs -c lockscreen" >/dev/null 2>&1; then
    exit 0
fi

qs -c lockscreen -n
status=$?

if [ "$status" -ne 0 ]; then
    hyprctl eval 'hl.clear_crashed_lockscreen()' >/dev/null 2>&1
fi

exit "$status"
