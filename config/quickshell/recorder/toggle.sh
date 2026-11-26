#!/usr/bin/env bash
set -uo pipefail

# Toggle a wf-recorder session on the focused monitor. State lives in
# XDG_RUNTIME_DIR so a stale PID from a previous boot can never stop an
# unrelated process.

state_dir="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}/cyan1de-recorder-$UID}"
mkdir -p "$state_dir" || exit 0
lock_file="$state_dir/recorder.lock"
pid_file="$state_dir/recorder.pid"
path_file="$state_dir/recorder.path"
log_file="$state_dir/recorder.log"

exec 9>"$lock_file" || exit 0
if command -v flock >/dev/null 2>&1; then
    flock -n 9 || exit 0
fi

notify() {
    local icon="$1" message="$2"
    if command -v hyprctl >/dev/null 2>&1; then
        hyprctl notify "$icon" 4000 0 "$message" >/dev/null 2>&1
    elif command -v notify-send >/dev/null 2>&1; then
        notify-send "Screen recorder" "$message" >/dev/null 2>&1
    fi
}

live_pid() {
    local pid cmdline
    [[ -s "$pid_file" ]] || return 1
    IFS= read -r pid < "$pid_file" || return 1
    [[ "$pid" =~ ^[0-9]+$ ]] || return 1
    kill -0 "$pid" 2>/dev/null || return 1
    cmdline="$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null)" || return 1
    [[ "$cmdline" == *wf-recorder* ]] || return 1
    printf '%s\n' "$pid"
}

select_output() {
    local current listing first
    current=""
    if command -v hyprctl >/dev/null 2>&1; then
        current="$(hyprctl activeworkspace 2>/dev/null \
            | sed -n 's/.* on monitor \([^:]*\):.*/\1/p' | head -n 1)"
    fi

    listing="$(timeout 2 wf-recorder -L 2>/dev/null || true)"
    first="$(printf '%s\n' "$listing" \
        | sed -n 's/^[[:space:]]*[0-9][0-9]*\. Name: \([^ ]*\).*/\1/p' | head -n 1)"

    if [[ -n "$current" ]]; then
        if [[ -z "$listing" ]] || printf '%s\n' "$listing" | grep -q "Name: $current "; then
            printf '%s\n' "$current"
            return 0
        fi
    fi
    if [[ -n "$first" ]]; then
        printf '%s\n' "$first"
    elif [[ -n "$current" ]]; then
        printf '%s\n' "$current"
    fi
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
    local file="$1" output="$2" pid log
    local args=() audio_args=(--audio)

    [[ -n "$output" ]] && args+=(-o "$output")
    args+=(-c libx264 -p preset=veryfast -p crf=23 -y -f "$file")

    : > "$log_file"
    launch_recorder
    pid="$(< "$pid_file")"
    sleep 0.8

    if ! kill -0 "$pid" 2>/dev/null; then
        log="$(tail -n 6 "$log_file" 2>/dev/null | tr '\n' ' ')"
        if [[ "$log" =~ [Aa]udio|[Pp]ulse|[Ss]ource|[Pp]a_ ]]; then
            notify 1 "Audio unavailable; retrying video only"
            audio_args=()
            : > "$log_file"
            launch_recorder
            pid="$(< "$pid_file")"
            sleep 0.8
        fi
    fi

    if ! kill -0 "$pid" 2>/dev/null; then
        log="$(tail -n 6 "$log_file" 2>/dev/null | tr '\n' ' ' | cut -c1-220)"
        rm -f "$pid_file" "$path_file"
        notify 3 "Could not start recording${log:+: $log}"
        return 1
    fi

    if [[ -n "$output" ]]; then
        notify 5 "Recording started on $output: $file"
    else
        notify 5 "Recording started: $file"
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

    rm -f "$pid_file" "$path_file"
    notify 5 "Recording stopped${saved:+: $saved}"
}

if pid="$(live_pid)"; then
    stop_recorder "$pid"
    exit 0
fi

# A dead PID is not a recording: clear it instead of signalling a reused PID.
rm -f "$pid_file" "$path_file"

if ! command -v wf-recorder >/dev/null 2>&1; then
    notify 3 "wf-recorder is not installed"
    exit 1
fi

video_dir="${XDG_VIDEOS_DIR:-$HOME/Videos}"
if ! mkdir -p "$video_dir"; then
    notify 3 "Cannot create recording directory: $video_dir"
    exit 1
fi

stamp="$(date +%Y-%m-%d_%H-%M-%S)"
file="$video_dir/cyan1de-$stamp.mp4"
suffix=0
while [[ -e "$file" ]]; do
    suffix=$((suffix + 1))
    file="$video_dir/cyan1de-$stamp-$suffix.mp4"
done
printf '%s\n' "$file" > "$path_file"

output="$(select_output)"
start_recorder "$file" "$output"
