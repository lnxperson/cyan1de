#!/usr/bin/env bash
# Adapter for power-profiles-daemon (PPD).
#
# PPD runs on the SYSTEM bus, not the session bus. The old helper checked
# `systemctl --user is-active power-profiles-daemon.service`, which is always
# inactive (wrong bus), so the UI was never shown. Detection here is based on
# actually reading the daemon's ActiveProfile through a working backend:
#   1. powerprofilesctl  (talks to PPD on the system bus itself)
#   2. gdbus  --system   org.freedesktop.UPower.PowerProfiles
#   3. busctl --system   org.freedesktop.UPower.PowerProfiles
#   4. same two, with the older net.hadess.PowerProfiles bus name
# No systemctl gate, no session bus, no vendor-specific fallbacks.
set -uo pipefail

FDO_NAME="org.freedesktop.UPower.PowerProfiles"
FDO_PATH="/org/freedesktop/UPower/PowerProfiles"
FDO_IFACE="org.freedesktop.UPower.PowerProfiles"
OLD_NAME="net.hadess.PowerProfiles"
OLD_PATH="/net/hadess/PowerProfiles"
OLD_IFACE="net.hadess.PowerProfiles"

normalize() {
    case "$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]' | tr -d '\r')" in
        *power-saver*|*powersave*|*low-power*) printf 'power-saver' ;;
        *balanced*|*normal*)                  printf 'balanced' ;;
        *performance*|*high-performance*|*turbo*) printf 'performance' ;;
        *)                                    printf '' ;;
    esac
}

json_escape() {
    printf '%s' "${1:-}" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

emit() {
    local available="$1" profile="$2" backend="${3:-none}"
    printf '{"available":%s,"profile":"%s","backend":"%s","profiles":["power-saver","balanced","performance"]}\n' \
        "$available" "$(json_escape "$profile")" "$(json_escape "$backend")"
}

# --- status readers: print a canonical profile name, or fail -----------------

status_cli() {
    command -v powerprofilesctl >/dev/null 2>&1 || return 1
    local raw
    raw="$(powerprofilesctl get 2>/dev/null | head -1)"
    raw="$(printf '%s' "$raw" | sed 's/^[[:space:]]*\*\?[[:space:]]*//; s/[[:space:]]*$//')"
    raw="$(normalize "$raw")"
    [ -n "$raw" ] || return 1
    printf '%s' "$raw"
}

# gdbus/busctl readers take name, path and interface so both PPD bus names
# can be probed with the same code.
gdbus_profile() {
    local name="$1" path="$2" iface="$3"
    command -v gdbus >/dev/null 2>&1 || return 1
    local raw
    raw="$(gdbus call --system --dest "$name" --object-path "$path" \
        --method org.freedesktop.DBus.Properties.Get \
        "$iface" ActiveProfile 2>/dev/null)" || return 1
    raw="$(printf '%s' "$raw" | sed -n "s/.*<'\([^']*\)'>.*/\1/p")"
    raw="$(normalize "$raw")"
    [ -n "$raw" ] || return 1
    printf '%s' "$raw"
}

busctl_profile() {
    local name="$1" path="$2" iface="$3"
    command -v busctl >/dev/null 2>&1 || return 1
    local raw
    raw="$(busctl --system get-property "$name" "$path" "$iface" ActiveProfile 2>/dev/null)" || return 1
    raw="$(printf '%s' "$raw" | awk '{print $NF}' | tr -d '"')"
    raw="$(normalize "$raw")"
    [ -n "$raw" ] || return 1
    printf '%s' "$raw"
}

# First reader that returns a valid profile proves PPD is present and usable.
read_status() {
    local value
    if value="$(status_cli)"; then
        emit true "$value" cli; return 0
    fi
    if value="$(gdbus_profile "$FDO_NAME" "$FDO_PATH" "$FDO_IFACE")"; then
        emit true "$value" fdo; return 0
    fi
    if value="$(busctl_profile "$FDO_NAME" "$FDO_PATH" "$FDO_IFACE")"; then
        emit true "$value" fdo; return 0
    fi
    if value="$(gdbus_profile "$OLD_NAME" "$OLD_PATH" "$OLD_IFACE")"; then
        emit true "$value" legacy; return 0
    fi
    if value="$(busctl_profile "$OLD_NAME" "$OLD_PATH" "$OLD_IFACE")"; then
        emit true "$value" legacy; return 0
    fi
    emit false "" none
    return 1
}

# --- setter: try every available writer; harmless if more than one works ----

set_profile() {
    local wanted="$1"
    if command -v powerprofilesctl >/dev/null 2>&1; then
        powerprofilesctl set "$wanted" >/dev/null 2>&1 && return 0
    fi
    if command -v gdbus >/dev/null 2>&1; then
        gdbus call --system --dest "$FDO_NAME" --object-path "$FDO_PATH" \
            --method org.freedesktop.DBus.Properties.Set \
            "$FDO_IFACE" ActiveProfile "<'$wanted'>" >/dev/null 2>&1 && return 0
        gdbus call --system --dest "$OLD_NAME" --object-path "$OLD_PATH" \
            --method org.freedesktop.DBus.Properties.Set \
            "$OLD_IFACE" ActiveProfile "<'$wanted'>" >/dev/null 2>&1 && return 0
    fi
    if command -v busctl >/dev/null 2>&1; then
        busctl --system set-property "$FDO_NAME" "$FDO_PATH" "$FDO_IFACE" \
            ActiveProfile s "$wanted" >/dev/null 2>&1 && return 0
        busctl --system set-property "$OLD_NAME" "$OLD_PATH" "$OLD_IFACE" \
            ActiveProfile s "$wanted" >/dev/null 2>&1 && return 0
    fi
    return 1
}

case "${1:-status}" in
    status)
        read_status
        ;;
    set)
        target="$(normalize "${2:-}")"
        if [ -z "$target" ]; then
            emit false "" none
            exit 1
        fi
        set_profile "$target" || true
        read_status
        ;;
    *)
        emit false "" none
        ;;
esac
