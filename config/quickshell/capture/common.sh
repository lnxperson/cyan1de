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
print("DESKTOP_LEVEL=" + str(integer(capture, "desktopLevel", 100, 0, 200)))
print("DESKTOP_MUTED=" + ("1" if boolean(capture, "desktopMuted", False) else "0"))
print("MIC_LEVEL=" + str(integer(capture, "micLevel", 100, 0, 200)))
print("MIC_MUTED=" + ("1" if boolean(capture, "micMuted", False) else "0"))

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
            DESKTOP_LEVEL) desktop_level="$value" ;;
            DESKTOP_MUTED) desktop_muted="$value" ;;
            MIC_LEVEL) mic_level="$value" ;;
            MIC_MUTED) mic_muted="$value" ;;
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

# Prefer a real hardware H.264 encoder. NVENC is used on NVIDIA systems, VAAPI
# is the portable GPU fallback, and libx264 remains a last resort.
capture_video_encoder() {
    local encoders
    command -v ffmpeg >/dev/null 2>&1 || { printf 'libx264\n'; return 0; }
    encoders="$(ffmpeg -hide_banner -encoders 2>/dev/null)"
    if printf '%s\n' "$encoders" | grep -q ' h264_nvenc ' \
        && { ls /dev/nvidia* >/dev/null 2>&1 \
            || command -v nvidia-smi >/dev/null 2>&1; }; then
        printf 'h264_nvenc\n'
    elif printf '%s\n' "$encoders" | grep -q ' h264_vaapi ' \
        && [[ -e /dev/dri/renderD128 ]]; then
        printf 'h264_vaapi\n'
    else
        printf 'libx264\n'
    fi
}

capture_nvenc_preset() {
    case "$1" in
        high) printf 'p7\n' ;;
        small) printf 'p2\n' ;;
        *) printf 'p4\n' ;;
    esac
}

# wf-recorder arguments, one token per line so callers can mapfile them.
capture_wf_video_args() {
    local quality="$1" encoder
    encoder="$(capture_video_encoder)"
    case "$encoder" in
        h264_nvenc)
            printf -- '-c\nh264_nvenc\n-p\npreset=%s\n-p\nrc=vbr\n-p\ncq=%s\n' \
                "$(capture_nvenc_preset "$quality")" \
                "$(capture_quality_crf "$quality")"
            ;;
        h264_vaapi)
            printf -- '-c\nh264_vaapi\n-p\nqp=%s\n' \
                "$(capture_quality_crf "$quality")"
            ;;
        *)
            printf -- '-c\nlibx264\n-p\npreset=%s\n-p\ncrf=%s\n' \
                "$(capture_quality_preset "$quality")" \
                "$(capture_quality_crf "$quality")"
            ;;
    esac
}

# Return the monitor of the default sink, or any monitor as a fallback.
capture_desktop_source() {
    local sink monitor
    command -v pactl >/dev/null 2>&1 || return 1
    sink="$(pactl get-default-sink 2>/dev/null)"
    monitor="${sink}.monitor"
    if [[ -n "$sink" ]] \
        && pactl list short sources 2>/dev/null \
            | awk -v want="$monitor" '$2 == want { found = 1 } END { exit !found }'; then
        printf '%s\n' "$monitor"
        return 0
    fi
    pactl list short sources 2>/dev/null \
        | awk '$2 ~ /\.monitor$/ { print $2; exit }'
}

# Build a private PulseAudio mix with desktop audio and microphone as separate
# inputs. Prints the monitor source to pass to wf-recorder and records module
# IDs plus source names in $1 for level changes and teardown.
capture_audio_mix_setup() {
    local mods_file="$1" name="$2" desktop mic null_mod desktop_mod mic_mod
    command -v pactl >/dev/null 2>&1 || return 1

    desktop="$(capture_desktop_source)"
    [[ -n "$desktop" ]] || return 1
    mic="$(pactl get-default-source 2>/dev/null)"
    if [[ -z "$mic" || "$mic" == "$desktop" ]]; then
        mic="$(pactl list short sources 2>/dev/null \
            | awk '$2 !~ /\.monitor$/ { print $2; exit }')"
    fi
    [[ -n "$mic" ]] || return 1

    null_mod="$(pactl load-module module-null-sink "sink_name=$name" \
        "sink_properties=device.description=$name")" || return 1
    desktop_mod="$(pactl load-module module-loopback "source=$desktop" \
        "sink=$name")" || {
        pactl unload-module "$null_mod" >/dev/null 2>&1 || true
        return 1
    }
    mic_mod="$(pactl load-module module-loopback "source=$mic" \
        "sink=$name")" || {
        pactl unload-module "$desktop_mod" >/dev/null 2>&1 || true
        pactl unload-module "$null_mod" >/dev/null 2>&1 || true
        return 1
    }

    printf '%s\n%s\n%s\n%s\n%s\n' \
        "$desktop_mod" "$mic_mod" "$null_mod" "$desktop" "$mic" > "$mods_file"
    printf '%s.monitor\n' "$name"
}

capture_source_index() {
    pactl list short sources 2>/dev/null \
        | awk -v want="$1" '$2 == want { print $1; exit }'
}

# Set the level and mute state of one loopback source-output in the private mix.
capture_set_loopback_level() {
    local source="$1" level="$2" mute="$3" attempts="${4:-1}"
    local source_idx output i
    source_idx="$(capture_source_index "$source")"
    [[ -n "$source_idx" ]] || return 0

    for ((i = 0; i < attempts; i++)); do
        output="$(python3 - "$source_idx" <<'PY'
import re
import subprocess
import sys

source = sys.argv[1]
try:
    text = subprocess.check_output(
        ["pactl", "list", "source-outputs"],
        text=True, stderr=subprocess.DEVNULL, timeout=3)
except Exception:
    sys.exit(0)

for block in re.split(r"(?m)^Source Output #", text)[1:]:
    header = re.match(r"\s*(\d+)", block)
    if not header:
        continue
    if not re.search(r"^\s*Source:\s*%s\s*$" % re.escape(source), block, re.M):
        continue
    if "loopback-" not in block:
        continue
    print(header.group(1))
    break
PY
)"
        [[ -n "$output" ]] && break
        sleep 0.1
    done
    [[ -n "$output" ]] || return 0
    pactl set-source-output-volume "$output" "${level}%" >/dev/null 2>&1 || true
    pactl set-source-output-mute "$output" "$mute" >/dev/null 2>&1 || true
}

capture_audio_mix_levels() {
    local mods_file="$1" desktop_level="$2" mic_level="$3"
    local desktop_mute="$4" mic_mute="$5" attempts="${6:-1}"
    local -a lines=()
    [[ -f "$mods_file" ]] || return 0
    mapfile -t lines < "$mods_file"
    [[ -n "${lines[3]:-}" && -n "${lines[4]:-}" ]] || return 0
    capture_set_loopback_level "${lines[3]}" "$desktop_level" "$desktop_mute" "$attempts"
    capture_set_loopback_level "${lines[4]}" "$mic_level" "$mic_mute" "$attempts"
}

capture_audio_mix_teardown() {
    local mods_file="$1" mod
    [[ -f "$mods_file" ]] || return 0
    while IFS= read -r mod; do
        if [[ "$mod" =~ ^[0-9]+$ ]]; then
            pactl unload-module "$mod" >/dev/null 2>&1 || true
        fi
    done < "$mods_file"
    rm -f "$mods_file"
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
# window. CamelCase classes are split into words, reverse-DNS GNOME app ids are
# shortened to readable names, lowercase classes fall back to the window title,
# and steam_app_<id> classes are resolved from local Steam manifests so
# Geometry Dash is not named "steam app 322170". Generic Proton/UMU classes are
# resolved from the window title or the game executable path in the process
# tree; the install directory and Steam installdir metadata provide the name,
# so no per-game alias list is needed. A monitor name selects that display's
# most recently focused window; "address:<hex>" or "pid:<number>" selects an
# exact window for helpers such as Discord presence.
capture_app_name() {
    local wanted="${1:-}" name
    command -v python3 >/dev/null 2>&1 || return 1
    command -v hyprctl >/dev/null 2>&1 || return 1

    name="$(python3 - "$wanted" <<'PY'
import json
import os
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

def steam_roots():
    home = os.path.expanduser("~")
    roots = [
        os.path.join(home, ".steam", "steam", "steamapps"),
        os.path.join(home, ".local", "share", "Steam", "steamapps"),
        os.path.join(home, "Steam", "steamapps"),
    ]
    for base in list(roots):
        library = os.path.join(base, "libraryfolders.vdf")
        try:
            with open(library, "r", encoding="utf-8", errors="ignore") as fh:
                text = fh.read()
        except Exception:
            continue
        for path in re.findall(r'"path"\s+"([^"]+)"', text):
            roots.append(os.path.join(path, "steamapps"))
    return roots

def steam_name(appid):
    for root in steam_roots():
        manifest = os.path.join(root, "appmanifest_%s.acf" % appid)
        try:
            with open(manifest, "r", encoding="utf-8", errors="ignore") as fh:
                text = fh.read()
        except Exception:
            continue
        match = re.search(r'"name"\s+"([^"]+)"', text)
        if match:
            return clean(match.group(1))
    return ""

def steam_install_names():
    # installdir -> name from Steam's own manifests. Proton command lines use
    # these directory names in Windows paths, so this resolves games we have no
    # static alias for.
    mapping = {}
    for root in steam_roots():
        try:
            manifests = [name for name in os.listdir(root)
                         if name.startswith("appmanifest_")
                         and name.endswith(".acf")]
        except Exception:
            continue
        for name in manifests:
            try:
                with open(os.path.join(root, name), "r", encoding="utf-8",
                          errors="ignore") as fh:
                    text = fh.read()
            except Exception:
                continue
            install = re.search(r'"installdir"\s+"([^"]+)"', text)
            title = re.search(r'"name"\s+"([^"]+)"', text)
            if not install or not title:
                continue
            key = re.sub(r"[^a-z0-9]", "", install.group(1).lower())
            value = clean(title.group(1))
            if key and value:
                mapping[key] = value
    return mapping

def known_app_name(app_id):
    aliases = {
        "org.gnome.nautilus": "Nautilus",
        "org.gnome.texteditor": "Text Editor",
        "org.gnome.gedit": "Text Editor",
        "org.gnome.loupe": "Loupe",
        "org.gnome.papers": "Papers",
        "org.gnome.controlcenter": "Settings",
        "org.gnome.settings": "Settings",
        "org.gnome.terminal": "Terminal",
        "org.gnome.calculator": "Calculator",
        "org.gnome.calendar": "Calendar",
        "org.gnome.characters": "Characters",
        "org.gnome.software": "Software",
        "org.gnome.clocks": "Clocks",
        "org.gnome.screenshot": "Screenshot",
    }
    return clean(aliases.get(str(app_id or "").lower(), ""))

def reverse_dns_name(app_id):
    app_id = re.sub(r"\.desktop$", "", str(app_id or ""), flags=re.I)
    if "." not in app_id:
        return ""
    tail = app_id.rsplit(".", 1)[-1]
    name = clean(camel(tail))
    if name.lower() in ("app", "bin", "client", "desktop", "main"):
        return ""
    return name

def title_name(client):
    for source in (clean(client.get("title") or ""),
                   clean(client.get("initialTitle") or "")):
        if not source:
            continue
        parts = [part.strip() for part in re.split(r"\s+[-—–]\s+", source) if part.strip()]
        candidate = clean(parts[-1] if parts else source)
        if candidate:
            return candidate
    return ""

# Proton/UMU windows often report a generic class such as "steam proton". The
# real game is usually visible in the window title or in an ancestor process's
# command line (for example RocketLeague.exe), so use those before the class.
# Some Wine games report a bare class/title of "exe"; those are handled by the
# executable alias map and the running-process fallback below.
generic_window_classes = {
    "steam", "steamproton", "proton", "wine", "wine64", "umu", "umurun",
    "lutris", "heroic", "bottles", "dosbox", "retroarch",
}

def is_generic_window_class(raw_cls):
    normalized = re.sub(r"[^a-z0-9]", "", str(raw_cls or "").lower())
    return normalized in generic_window_classes

# Directories that describe a launcher/wine layout rather than the game itself.
generic_path_keys = {
    "bin", "binaries", "win32", "win64", "x64", "x86", "release", "retail",
    "shipping", "game", "games", "exe", "build", "builds", "drive_c",
    "windows", "programfiles", "programfilesx86", "steamapps", "common",
    "steam", "proton", "wine", "umu", "prefix", "pfx", "users", "user",
    "appdata", "local", "roaming", "temp", "tmp", "rockstargames",
    "epicgames", "ubisoft", "activision", "bethesda", "launcher", "launchers",
}

def normalize_key(value):
    return re.sub(r"[^a-z0-9]", "", str(value or "").lower())

def humanize_name(value):
    value = re.sub(r"[_-]+", " ", str(value or ""))
    value = re.sub(r"(?<=[a-z0-9])(?=[A-Z])", " ", value)
    value = re.sub(r"(?<=[A-Za-z])(?=[0-9])", " ", value)
    words = [part for part in re.sub(r"\s+", " ", value).strip().split() if part]
    result = []
    for word in words:
        lower = word.lower()
        if re.fullmatch(r"(?:i|ii|iii|iv|v|vi|vii|viii|ix|x)", lower):
            result.append(lower.upper())
        elif word.isupper() and len(word) <= 4:
            result.append(word)
        else:
            result.append(word[:1].upper() + word[1:].lower())
    return clean(" ".join(result))

def game_name_from_exe(stem, raw_path):
    # Steam's installdir is authoritative when the executable path contains it.
    installs = steam_install_names()
    for part in re.split(r"[\\/]", raw_path or ""):
        name = installs.get(normalize_key(part))
        if name:
            return name

    parts = [part for part in re.split(r"[\\/]", raw_path or "") if part]
    if parts and parts[-1].lower().endswith(".exe"):
        parts = parts[:-1]
    if parts and re.fullmatch(r"[a-zA-Z]:", parts[0]):
        parts = parts[1:]

    directory_name = ""
    structured_directory = False
    for part in reversed(parts):
        key = normalize_key(part)
        if not key or key in generic_path_keys:
            continue
        if re.fullmatch(r"[0-9._v-]+", part):
            continue
        directory_name = humanize_name(part)
        structured_directory = bool(
            re.search(r"[ _-]", part)
            or re.search(r"(?<=[a-z0-9])(?=[A-Z])", part))
        break

    stem_name = ""
    if re.search(r"[ _-]", stem or "") \
        or re.search(r"(?<=[a-z0-9])(?=[A-Z])", stem or ""):
        stem_name = humanize_name(stem)

    if directory_name and structured_directory:
        return directory_name
    if stem_name:
        return stem_name
    return directory_name or humanize_name(stem)

def generic_process_name(name):
    low = clean(name).lower()
    if not low:
        return True
    if low in {
        "steam", "steamwebhelper", "proton", "wine", "wine64",
        "wine preloader", "umu", "umu run", "launcher", "updater",
        "bootstrap", "steamworks", "steamcmd", "easyanticheat",
        "epic games launcher", "galaxy client",
    }:
        return True
    return any(token in low for token in (
        " easy anti cheat", " anti cheat", "eac", "crash", "launcher",
        "updater", "bootstrap", "steamwebhelper",
    ))

def exe_paths_from_cmdline(pid):
    try:
        with open("/proc/%s/cmdline" % pid, "rb") as fh:
            args = [part.decode("utf-8", "ignore")
                    for part in fh.read().split(b"\0") if part]
    except Exception:
        return []
    paths = []
    for arg in args:
        # Proton passes Windows-style paths such as
        # Z:\Games\SomeGame\Game.exe; POSIX basename does not split on
        # backslashes, so handle both separator styles here.
        base = re.split(r"[\\/]", arg)[-1]
        if base.lower().endswith(".exe") and base[:-4]:
            paths.append((base[:-4], arg))
    return paths

def process_game_paths(pid):
    try:
        pid = int(pid)
    except Exception:
        return []
    paths = []
    seen = set()
    for _ in range(16):
        if not pid or pid in seen:
            break
        seen.add(pid)
        paths.extend(exe_paths_from_cmdline(pid))
        try:
            with open("/proc/%d/status" % pid, "r", encoding="utf-8",
                      errors="ignore") as fh:
                match = re.search(r"^PPid:\s*(\d+)", fh.read(), re.M)
            pid = int(match.group(1)) if match else 0
        except Exception:
            pid = 0
    return paths

def process_app_name(client, title):
    candidates = []
    for stem, path in process_game_paths(client.get("pid")):
        if generic_process_name(stem):
            continue
        name = game_name_from_exe(stem, path)
        if name and not generic_process_name(name):
            candidates.append(name)
    if not candidates:
        return ""
    compact_title = re.sub(r"\s+", "", (title or "").lower())
    for name in candidates:
        if re.sub(r"\s+", "", name.lower()) == compact_title:
            return name
    for name in candidates:
        if compact_title and re.sub(r"\s+", "", name.lower()) in compact_title:
            return name
    return max(candidates, key=len)

def name_from_window(client):
    if not isinstance(client, dict):
        return ""
    raw_cls = str(client.get("class") or client.get("initialClass") or "")
    cls = clean(camel(raw_cls))
    title = title_name(client)
    steam = re.search(r"steam[ _-]*app[ _-]*(\d+)", raw_cls, re.I)
    if steam:
        appid = steam.group(1)
        name = steam_name(appid)
        if name:
            return name
        if title and appid not in title:
            return title
        return "Steam App " + appid
    if is_generic_window_class(raw_cls):
        name = process_app_name(client, title)
        if name:
            return name
        if title:
            return title
    app_id = re.sub(r"\.desktop$", "", raw_cls, flags=re.I)
    known = known_app_name(app_id)
    if known:
        return known
    reverse = reverse_dns_name(app_id)
    if reverse:
        return reverse
    if cls and (any(char.isupper() for char in cls) or " " in cls):
        return cls
    if title and title.lower() != cls.lower():
        return title
    return (cls[:1].upper() + cls[1:]) if cls else ""

def generic_app_name(name):
    value = re.sub(r"[^a-z0-9]", "", clean(name).lower())
    return value in ("", "exe", "wine", "wine64", "proton", "steamproton",
                     "umu", "umurun", "game", "launcher", "loading")

def running_game_name():
    # Last resort for Wine/Proton windows whose title and class are both bare:
    # derive a name from the game executable path in the process table.
    try:
        entries = os.listdir("/proc")
    except Exception:
        return ""
    for entry in entries:
        if not entry.isdigit():
            continue
        for stem, path in exe_paths_from_cmdline(entry):
            if generic_process_name(stem):
                continue
            name = game_name_from_exe(stem, path)
            if name and not generic_process_name(name):
                return name
    return ""

def name_for(client):
    name = name_from_window(client)
    if generic_app_name(name):
        game = running_game_name()
        if game:
            return game
    return name

client = None
if wanted and wanted.startswith("address:"):
    address = wanted.split(":", 1)[1].strip().lower()
    clients = run_json(["hyprctl", "clients", "-j"]) or []
    client = next((c for c in clients if isinstance(c, dict)
                   and str(c.get("address") or "").lower() == address), None)
elif wanted and wanted.startswith("pid:"):
    try:
        pid = int(wanted.split(":", 1)[1].strip())
    except Exception:
        pid = 0
    clients = run_json(["hyprctl", "clients", "-j"]) or []
    matches = [c for c in clients if isinstance(c, dict)
               and int(c.get("pid") or 0) == pid]
    if matches:
        try:
            client = min(matches,
                         key=lambda c: int(c.get("focusHistoryID", 999)))
        except Exception:
            client = matches[0]
elif wanted and wanted != "focused":
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
# Settings toggle is on. An unresolved app falls back to "Base Profile" so
# captures stay organized instead of landing loose in the configured folder.
capture_target_dir() {
    local base="${1:-}" display="${2:-}" app
    base="${base%/}"
    [[ -n "$base" ]] || base="/"
    if [[ "${app_folders:-0}" == "1" ]]; then
        app="$(capture_app_name "$display")" || app=""
        [[ -n "$app" ]] || app="Base Profile"
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
