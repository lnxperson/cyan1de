#!/usr/bin/env bash
set -uo pipefail

# Toggle a wf-recorder session. Capture options come from the Settings →
# Screen Capturing page; runtime state lives in XDG_RUNTIME_DIR so a stale PID
# can never stop an unrelated process. The state file drives the topbar chip.

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../capture/common.sh
source "$script_dir/../capture/common.sh"

state_dir="${XDG_RUNTIME_DIR:-${HOME:-/tmp}/.cache}/cyan1de"
mkdir -p "$state_dir" || exit 0
lock_file="$state_dir/recorder.lock"
pid_file="$state_dir/recorder.pid"
path_file="$state_dir/recorder.path"
state_file="$state_dir/recorder.state"
log_file="$state_dir/recorder.log"

exec 9>"$lock_file" || exit 0
if command -v flock >/dev/null 2>&1; then
    flock -n 9 || exit 0
fi

live_pid() {
    local pid cmdline saved=""
    [[ -s "$pid_file" ]] || return 1
    IFS= read -r pid < "$pid_file" || return 1
    [[ "$pid" =~ ^[0-9]+$ ]] || return 1
    kill -0 "$pid" 2>/dev/null || return 1
    cmdline="$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null)" || return 1
    [[ "$cmdline" == *wf-recorder* ]] || return 1
    # A stale pid must never stop the separate replay-buffer recorder.
    [[ -s "$path_file" ]] && IFS= read -r saved < "$path_file"
    [[ -z "$saved" || "$cmdline" == *"$saved"* ]] || return 1
    printf '%s\n' "$pid"
}

write_state() {
    local pid="$1" started="$2" file="$3"
    printf 'v1\n%s\n%s\n%s\n' "$pid" "$started" "$file" > "$state_file"
}

launch_recorder() {
    # Uses the caller's `args` and `audio_args` arrays.
    if command -v setsid >/dev/null 2>&1; then
        setsid wf-recorder "${audio_args[@]}" "${args[@]}" > "$log_file" 2>&1 9>&- &
    else
        wf-recorder "${audio_args[@]}" "${args[@]}" > "$log_file" 2>&1 9>&- &
    fi
    printf '%s\n' "$!" > "$pid_file"
}

start_recorder() {
    local file="$1" output="$2" pid log started filter
    local args=() audio_args=() encoder_args=()

    mapfile -t encoder_args < <(capture_wf_video_args "$rec_quality")
    [[ "$rec_audio" == "1" ]] && audio_args=(--audio)
    [[ -n "$output" ]] && args+=(-o "$output")
    [[ "$rec_fps" -gt 0 ]] && args+=(-r "$rec_fps")
    filter="$(capture_scale_filter "$rec_resolution")"
    [[ -n "$filter" ]] && args+=(-F "$filter")
    args+=("${encoder_args[@]}")
    [[ "$rec_fps" -gt 0 ]] && args+=(-p "g=$rec_fps")
    args+=(-y -f "$file")

    : > "$log_file"
    launch_recorder
    pid="$(< "$pid_file")"
    sleep 0.8

    if ! kill -0 "$pid" 2>/dev/null && [[ "$rec_audio" == "1" ]]; then
        log="$(tail -n 6 "$log_file" 2>/dev/null | tr '\n' ' ')"
        if [[ "$log" =~ [Aa]udio|[Pp]ulse|[Ss]ource|[Pp]a_ ]]; then
            capture_notify "Recording audio unavailable" "Retrying video only." "low"
            audio_args=()
            : > "$log_file"
            launch_recorder
            pid="$(< "$pid_file")"
            sleep 0.8
        fi
    fi

    if ! kill -0 "$pid" 2>/dev/null; then
        log="$(tail -n 6 "$log_file" 2>/dev/null | tr '\n' ' ' | cut -c1-220)"
        rm -f "$pid_file" "$path_file" "$state_file"
        capture_notify "Recording failed" "$log" "critical"
        return 1
    fi

    [[ "$rec_audio" == "1" ]] && capture_apply_mic_level "$mic_level" "$pid"

    started="$(date +%s)"
    write_state "$pid" "$started" "$file"
    if [[ -n "$output" ]]; then
        capture_notify "Recording Started" "Saving to $file on $output"
    else
        capture_notify "Recording Started" "Saving to $file"
    fi
}

stop_recorder() {
    local pid="$1" saved="" i
    [[ -s "$path_file" ]] && IFS= read -r saved < "$path_file"

    kill -INT "$pid" 2>/dev/null || true
    for ((i = 0; i < 50; i++)); do
        kill -0 "$pid" 2>/dev/null || break
        sleep 0.1
    done

    if kill -0 "$pid" 2>/dev/null; then
        kill -TERM "$pid" 2>/dev/null || true
        for ((i = 0; i < 10; i++)); do
            kill -0 "$pid" 2>/dev/null || break
            sleep 0.1
        done
        kill -KILL "$pid" 2>/dev/null || true
    fi

    rm -f "$pid_file" "$path_file" "$state_file"
    capture_notify "Recording stopped" "Saved to ${saved:-unknown location}"
}

# Defaults keep the script usable before Settings has written a capture block.
app_folders=0
mic_level=100
rec_dir="$HOME/Videos"
rec_display="focused"
rec_fps=60
rec_resolution="native"
rec_audio=1
rec_quality="balanced"
clip_enabled=1
clip_dir="$HOME/Videos"
clip_seconds=60
clip_display="focused"
clip_fps=30
clip_resolution="1280x720"
clip_audio=0
clip_quality="small"
shot_dir="$HOME/Pictures"
shot_format="png"
shot_copy=1
capture_read_settings || true

if pid="$(live_pid)"; then
    stop_recorder "$pid"
    exit 0
fi

# A dead PID is not a recording: clear it instead of signalling a reused PID.
rm -f "$pid_file" "$path_file" "$state_file"

if ! command -v wf-recorder >/dev/null 2>&1; then
    capture_notify "Recording failed" "wf-recorder is not installed." "critical"
    exit 1
fi

output="$(capture_resolve_display "$rec_display")"
target_dir="$(capture_target_dir "$rec_dir" "$output")"
mkdir -p "$target_dir" || {
    capture_notify "Recording failed" "Cannot create recording directory: $target_dir" "critical"
    exit 1
}

file="$(capture_unique_file "$target_dir" cyan1de mp4)"
printf '%s\n' "$file" > "$path_file"

start_recorder "$file" "$output"
