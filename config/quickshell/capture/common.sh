#!/usr/bin/env bash
# Shared helpers for cyan1de screen capture scripts.
# Sourced from recorder/ and screenshot/ helpers; no user-specific paths here.

CAPTURE_SETTINGS_PATH="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/settings.json"

capture_notify() {
    local summary="$1" body="${2:-}" urgency="${3:-normal}"
    command -v notify-send >/dev/null 2>&1 || return 0
    notify-send -u "$urgency" -a cyan1de "$summary" "$body" >/dev/null 2>&1 || true
}

capture_expand_path() {
    local value="$1"
    if [[ "$value" == "~" ]]; then
        printf '%s\n' "$HOME"
    elif [[ "$value" == ~/* ]]; then
        printf '%s/%s\n' "$HOME" "${value#~/}"
    else
        printf '%s\n' "$value"
    fi
}

# Reads the capture block from settings.json. Callers declare the variables
# below first, then call this function; unknown or partial configs fall back
# to the shipped defaults so a fresh config works without opening Settings.
capture_read_settings() {
    local output key value
    output="$(python3 - "$CAPTURE_SETTINGS_PATH" <<'PY'
import json
import os
import re
import sys

path = sys.argv[1]
try:
    with open(path, "r", encoding="utf-8") as fh:
        data = json.load(fh)
except Exception:
    data = {}

capture = data.get("capture") if isinstance(data, dict) else None
if not isinstance(capture, dict):
    capture = {}

def group(name, defaults):
    value = capture.get(name)
    return value if isinstance(value, dict) else {}

def text(group_data, key, fallback):
    value = group_data.get(key)
    return value if isinstance(value, str) and value.strip() else fallback

def integer(group_data, key, fallback, low, high):
    try:
        value = int(group_data.get(key))
    except Exception:
        value = fallback
    return max(low, min(high, value))

def boolean(group_data, key, fallback):
    value = group_data.get(key)
    return fallback if not isinstance(value, bool) else value

def directory(group_data, key, fallback):
    return os.path.expanduser(text(group_data, key, fallback).strip())

def resolution(group_data, key, fallback):
    value = text(group_data, key, fallback).strip().lower()
    return value if value == "native" or re.fullmatch(r"\d+x\d+", value) else fallback

def choice(group_data, key, allowed, fallback):
    value = text(group_data, key, fallback)
    return value if value in allowed else fallback

rec = group("recordings", {})
clip = group("clips", {})
shot = group("screenshots", {})

print("APP_FOLDERS=" + ("1" if boolean(capture, "appFolders", False) else "0"))

print("REC_DIR=" + directory(rec, "directory", "~/Videos"))
print("REC_DISPLAY=" + text(rec, "display", "focused"))
print("REC_FPS=" + str(integer(rec, "framerate", 60, 0, 240)))
print("REC_RESOLUTION=" + resolution(rec, "resolution", "native"))
print("REC_AUDIO=" + ("1" if boolean(rec, "audio", True) else "0"))
print("REC_QUALITY=" + choice(rec, "quality", ["high", "balanced", "small"], "balanced"))

print("CLIP_ENABLED=" + ("1" if boolean(clip, "enabled", True) else "0"))
print("CLIP_DIR=" + directory(clip, "directory", "~/Videos"))
print("CLIP_SECONDS=" + str(integer(clip, "seconds", 60, 10, 600)))
print("CLIP_DISPLAY=" + text(clip, "display", "focused"))
print("CLIP_FPS=" + str(integer(clip, "framerate", 30, 1, 240)))
print("CLIP_RESOLUTION=" + resolution(clip, "resolution", "1280x720"))
print("CLIP_AUDIO=" + ("1" if boolean(clip, "audio", False) else "0"))
print("CLIP_QUALITY=" + choice(clip, "quality", ["high", "balanced", "small"], "small"))

print("SHOT_DIR=" + directory(shot, "directory", "~/Pictures"))
print("SHOT_FORMAT=" + choice(shot, "format", ["png", "jpg"], "png"))
print("SHOT_COPY=" + ("1" if boolean(shot, "copy", True) else "0"))
PY
)" || return 1

    while IFS='=' read -r key value; do
        case "$key" in
            APP_FOLDERS) app_folders="$value" ;;
            REC_DIR) rec_dir="$value" ;;
            REC_DISPLAY) rec_display="$value" ;;
            REC_FPS) rec_fps="$value" ;;
            REC_RESOLUTION) rec_resolution="$value" ;;
            REC_AUDIO) rec_audio="$value" ;;
            REC_QUALITY) rec_quality="$value" ;;
            CLIP_ENABLED) clip_enabled="$value" ;;
            CLIP_DIR) clip_dir="$value" ;;
            CLIP_SECONDS) clip_seconds="$value" ;;
            CLIP_DISPLAY) clip_display="$value" ;;
            CLIP_FPS) clip_fps="$value" ;;
            CLIP_RESOLUTION) clip_resolution="$value" ;;
            CLIP_AUDIO) clip_audio="$value" ;;
            CLIP_QUALITY) clip_quality="$value" ;;
            SHOT_DIR) shot_dir="$value" ;;
            SHOT_FORMAT) shot_format="$value" ;;
            SHOT_COPY) shot_copy="$value" ;;
        esac
    done <<< "$output"
}

capture_quality_crf() {
    case "$1" in
        high) printf '18\n' ;;
        small) printf '28\n' ;;
        *) printf '23\n' ;;
    esac
}

capture_quality_preset() {
    case "$1" in
        high) printf 'medium\n' ;;
        small) printf 'veryfast\n' ;;
        *) printf 'veryfast\n' ;;
    esac
}

# Resolve "focused" or a named output. Falls back to any available wf-recorder
# output, then to the focused monitor, so a disconnected saved display never
# silently disables capture.
capture_resolve_display() {
    local wanted="$1" current listing first
    current=""
    if command -v hyprctl >/dev/null 2>&1; then
        current="$(hyprctl activeworkspace 2>/dev/null \
            | sed -n 's/.* on monitor \([^:]*\):.*/\1/p' | head -n 1)"
    fi

    listing="$(timeout 2 wf-recorder -L 2>/dev/null || true)"
    first="$(printf '%s\n' "$listing" \
        | sed -n 's/^[[:space:]]*[0-9][0-9]*\. Name: \([^ ]*\).*/\1/p' | head -n 1)"

    if [[ "$wanted" != "focused" && -n "$wanted" ]]; then
        if [[ -z "$listing" ]] || printf '%s\n' "$listing" | grep -q "Name: $wanted "; then
            printf '%s\n' "$wanted"
            return 0
        fi
    fi
    if [[ -n "$current" ]]; then
        if [[ -z "$listing" ]] || printf '%s\n' "$listing" | grep -q "Name: $current "; then
            printf '%s\n' "$current"
            return 0
        fi
    fi
    printf '%s\n' "$first"
}

# Resolve a folder-safe app name from Hyprland. For a named display, use the
# most recently focused client on that monitor; otherwise use the global active
# window. Classes like GeometryDash are split into "Geometry Dash", while a
# lowercase class such as firefox falls back to the app suffix of its title.
capture_app_name() {
    local wanted="${1:-}" name
    command -v python3 >/dev/null 2>&1 || return 1
    command -v hyprctl >/dev/null 2>&1 || return 1

    name="$(python3 - "$wanted" <<'PY'
import json
import re
import subprocess
import sys

wanted = sys.argv[1] if len(sys.argv) > 1 else "focused"

def run_json(args):
    try:
        result = subprocess.run(args, stdout=subprocess.PIPE,
                                stderr=subprocess.DEVNULL, text=True, timeout=5)
        if result.returncode != 0:
            return None
        return json.loads(result.stdout)
    except Exception:
        return None

def camel(value):
    value = re.sub(r"[_-]+", " ", value or "")
    value = re.sub(r"(?<=[a-z0-9])(?=[A-Z])", " ", value)
    return re.sub(r"\s+", " ", value).strip()

def clean(value):
    value = re.sub(r'[<>:"/\\|?*\x00-\x1f]', "", value or "")
    value = re.sub(r"\s+", " ", value).strip()
    value = value[:80].strip(" .")
    return "" if value.lower() in ("", ".", "..") else value

def name_for(client):
    if not isinstance(client, dict):
        return ""
    cls = clean(camel(client.get("class") or client.get("initialClass") or ""))
    title = clean(client.get("title") or "")
    initial = clean(client.get("initialTitle") or "")
    if cls and (any(char.isupper() for char in cls) or " " in cls):
        return cls
    for source in (title, initial):
        if not source:
            continue
        parts = [part.strip() for part in re.split(r"\s+[-—–]\s+", source) if part.strip()]
        candidate = clean(parts[-1] if parts else source)
        if candidate and candidate.lower() != cls.lower():
            return candidate
    return (cls[:1].upper() + cls[1:]) if cls else ""

client = None
if wanted and wanted != "focused":
    monitors = run_json(["hyprctl", "monitors", "-j"]) or []
    clients = run_json(["hyprctl", "clients", "-j"]) or []
    index = next((i for i, mon in enumerate(monitors)
                  if isinstance(mon, dict) and mon.get("name") == wanted), None)
    if index is not None:
        candidates = [c for c in clients if isinstance(c, dict)
                      and c.get("monitor") == index and c.get("mapped")
                      and not c.get("hidden")]
        if candidates:
            try:
                client = min(candidates,
                             key=lambda c: int(c.get("focusHistoryID", 999)))
            except Exception:
                client = candidates[0]

if client is None:
    client = run_json(["hyprctl", "activewindow", "-j"])
if isinstance(client, dict) and client.get("address") in (None, "0x0"):
    client = None

name = name_for(client) if client else ""
if name:
    print(name)
PY
)" || return 1
    [[ -n "$name" ]] || return 1
    printf '%s\n' "$name"
}

# Returns the configured capture folder, or an app subfolder below it when the
# Settings toggle is on and an active app could be resolved.
capture_target_dir() {
    local base="${1:-}" display="${2:-}" app
    base="${base%/}"
    [[ -n "$base" ]] || base="/"
    if [[ "${app_folders:-0}" == "1" ]] \
        && app="$(capture_app_name "$display")" && [[ -n "$app" ]]; then
        if [[ "$base" == "/" ]]; then
            printf '/%s\n' "$app"
        else
            printf '%s/%s\n' "$base" "$app"
        fi
        return 0
    fi
    printf '%s\n' "$base"
}

# wf-recorder cannot scale via a simple flag, so use its ffmpeg filter option.
# Pad preserves aspect ratio instead of stretching a 16:10 display to 16:9.
capture_scale_filter() {
    local value="$1" width height
    if [[ "$value" == "native" || ! "$value" =~ ^[0-9]+x[0-9]+$ ]]; then
        return 0
    fi
    width="${value%x*}"
    height="${value#*x}"
    printf '%s\n' "scale=$width:$height:force_original_aspect_ratio=decrease,pad=$width:$height:(ow-iw)/2:(oh-ih)/2"
}

capture_unique_file() {
    local directory="$1" prefix="$2" extension="$3"
    local stamp file suffix=0
    stamp="$(date +%Y-%m-%d_%H-%M-%S)"
    file="$directory/$prefix-$stamp.$extension"
    while [[ -e "$file" ]]; do
        suffix=$((suffix + 1))
        file="$directory/$prefix-$stamp-$suffix.$extension"
    done
    printf '%s\n' "$file"
}

# Read programs.lua so the Programs page stays the single source of truth for
# the screenshot utility. Unknown Lua expressions fall back to hyprshot.
capture_screenshot_command() {
    local lua="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland/programs.lua"
    local raw value tail
    raw="$(sed -n 's/^[[:space:]]*M\.screenshot[[:space:]]*=[[:space:]]*\(.*\)$/\1/p' "$lua" 2>/dev/null | head -n 1)"
    raw="${raw%,}"
    raw="${raw%;}"
    if [[ "$raw" =~ ^\"(.*)\"$ ]]; then
        printf '%s\n' "${BASH_REMATCH[1]}"
    elif [[ "$raw" == *'os.getenv("HOME")'* && "$raw" == *'..'* ]]; then
        tail="$(printf '%s\n' "$raw" \
            | sed -n 's/.*\.\.[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)"
        printf '%s%s\n' "$HOME" "$tail"
    else
        printf 'hyprshot\n'
    fi
}
