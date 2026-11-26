#!/usr/bin/env bash
set -uo pipefail

# Rolling screen-replay buffer. A low-bitrate wf-recorder feeds ffmpeg, which
# keeps a wrapped set of Matroska segments in XDG_RUNTIME_DIR. `clip` stitches
# the newest segments into an mp4 containing roughly the last N seconds.

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../capture/common.sh
source "$script_dir/../capture/common.sh"

state_dir="${XDG_RUNTIME_DIR:-${HOME:-/tmp}/.cache}/cyan1de"
mkdir -p "$state_dir" || exit 0
buffer_dir="$state_dir/replay-buffer"
pid_file="$state_dir/replay.pid"
sig_file="$state_dir/replay.sig"
list_file="$state_dir/replay.list"
log_file="$state_dir/replay.log"
lock_file="$state_dir/replay.lock"
clip_lock="$state_dir/replay.clip.lock"

# Defaults mirror Settings → Screen Capturing before the first save.
app_folders=0
clip_enabled=1
clip_dir="$HOME/Videos"
clip_seconds=60
clip_display="focused"
clip_fps=30
clip_resolution="1280x720"
clip_audio=0
clip_quality="small"
rec_dir="$HOME/Videos"
rec_display="focused"
rec_fps=60
rec_resolution="native"
rec_audio=1
rec_quality="balanced"
shot_dir="$HOME/Pictures"
shot_format="png"
shot_copy=1
capture_read_settings || true

running_pid() {
    local pid cmdline
    [[ -s "$pid_file" ]] || return 1
    IFS= read -r pid < "$pid_file" || return 1
    [[ "$pid" =~ ^[0-9]+$ ]] || return 1
    kill -0 "$pid" 2>/dev/null || return 1
    cmdline="$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null)" || return 1
    [[ "$cmdline" == *replay.sh* ]] || return 1
    printf '%s\n' "$pid"
}

stop_replay() {
    local pid pgid i target
    pid="$(running_pid 2>/dev/null || true)"
    if [[ -n "$pid" ]]; then
        target="$pid"
        pgid="$(ps -o pgid= -p "$pid" 2>/dev/null | tr -d ' ')"
        # run_replay is started with setsid, so its pid is also its process
        # group id. Signal the whole group so ffmpeg cannot be orphaned.
        if [[ "$pgid" =~ ^[0-9]+$ && "$pgid" == "$pid" ]]; then
            target="-$pgid"
        fi
        kill -TERM "$target" 2>/dev/null || true
        for ((i = 0; i < 30; i++)); do
            kill -0 "$pid" 2>/dev/null || break
            sleep 0.1
        done
        if kill -0 "$pid" 2>/dev/null; then
            kill -KILL "$target" 2>/dev/null || true
            kill -KILL "$pid" 2>/dev/null || true
        fi
    fi
    rm -f "$pid_file" "$sig_file"
}

config_signature() {
    printf '%s\n' "v1" "$clip_enabled" "$clip_seconds" "$clip_display" \
        "$clip_fps" "$clip_resolution" "$clip_audio" "$clip_quality" \
        | sha256sum 2>/dev/null | cut -d' ' -f1
}

ensure_replay() {
    local signature current fifo pid
    exec 9>"$lock_file" || exit 0
    if command -v flock >/dev/null 2>&1; then
        flock -n 9 || exit 0
    fi

    if [[ "$clip_enabled" != "1" ]]; then
        stop_replay
        exit 0
    fi
    if ! command -v ffmpeg >/dev/null 2>&1 \
        || ! command -v wf-recorder >/dev/null 2>&1; then
        exit 0
    fi

    signature="$(config_signature)"
    current=""
    [[ -s "$sig_file" ]] && IFS= read -r current < "$sig_file"
    if running_pid >/dev/null 2>&1 && [[ "$current" == "$signature" ]]; then
        exit 0
    fi

    stop_replay
    rm -rf "$buffer_dir"
    mkdir -p "$buffer_dir" || exit 0
    fifo="$buffer_dir/stream.mkv"
    mkfifo "$fifo" || exit 0
    printf '%s\n' "$signature" > "$sig_file"
    : > "$log_file"

    if command -v setsid >/dev/null 2>&1; then
        setsid "$0" run >/dev/null 2>&1 9>&- &
    else
        "$0" run >/dev/null 2>&1 9>&- &
    fi
    pid="$!"
    printf '%s\n' "$pid" > "$pid_file"
}

run_replay() {
    local fifo segment_seconds segment_count output filter preset
    local ffpid="" wfpid="" cleaned=0
    local audio_args=() args=()

    fifo="$buffer_dir/stream.mkv"
    [[ -p "$fifo" ]] || { rm -f "$fifo"; mkfifo "$fifo" || exit 1; }

    segment_seconds=$((clip_seconds / 12))
    (( segment_seconds < 2 )) && segment_seconds=2
    (( segment_seconds > 10 )) && segment_seconds=10
    segment_count=$(( (clip_seconds + segment_seconds - 1) / segment_seconds + 2 ))

    preset="$(capture_quality_preset "$clip_quality")"
    [[ "$clip_audio" == "1" ]] && audio_args=(--audio)
    output="$(capture_resolve_display "$clip_display")"
    [[ -n "$output" ]] && args+=(-o "$output")
    args+=(-r "$clip_fps")
    filter="$(capture_scale_filter "$clip_resolution")"
    [[ -n "$filter" ]] && args+=(-F "$filter")
    args+=(-c libx264 -p "preset=$preset" -p "crf=$(capture_quality_crf "$clip_quality")")
    args+=(-p "g=$((clip_fps * segment_seconds))" -y -f "$fifo")

    cleanup() {
        (( cleaned )) && return
        cleaned=1
        trap - EXIT INT TERM
        [[ -n "$ffpid" ]] && kill "$ffpid" 2>/dev/null || true
        [[ -n "$wfpid" ]] && kill "$wfpid" 2>/dev/null || true
        [[ -n "$ffpid" ]] && wait "$ffpid" 2>/dev/null || true
        [[ -n "$wfpid" ]] && wait "$wfpid" 2>/dev/null || true
        rm -f "$fifo" "$pid_file" "$sig_file"
    }
    trap cleanup EXIT INT TERM

    ffmpeg -hide_banner -loglevel warning -f matroska -i "$fifo" -map 0 \
        -c copy -f segment -segment_time "$segment_seconds" \
        -segment_wrap "$segment_count" -reset_timestamps 1 -y \
        "$buffer_dir/seg%03d.mkv" >> "$log_file" 2>&1 &
    ffpid="$!"

    if command -v setsid >/dev/null 2>&1; then
        setsid wf-recorder "${audio_args[@]}" "${args[@]}" >> "$log_file" 2>&1 &
    else
        wf-recorder "${audio_args[@]}" "${args[@]}" >> "$log_file" 2>&1 &
    fi
    wfpid="$!"

    # Exit if either half dies; otherwise a broken fifo can leave wf-recorder
    # blocked forever with no consumer attached.
    wait -n "$ffpid" "$wfpid" 2>/dev/null || true
    cleanup
}

save_clip() {
    local segments=() valid=() segment duration total start file preset escaped suffix=0
    local audio_output=() target_dir
    exec 9>"$clip_lock" || exit 0
    if command -v flock >/dev/null 2>&1; then
        flock -n 9 || exit 0
    fi

    if ! running_pid >/dev/null 2>&1; then
        capture_notify "Clip not saved" "The replay buffer is not running." "low"
        return 1
    fi

    while IFS= read -r segment; do
        [[ -n "$segment" ]] && segments+=("$segment")
    done < <(find "$buffer_dir" -maxdepth 1 -type f -name 'seg*.mkv' \
        -printf '%T@ %p\n' 2>/dev/null | sort -n | cut -d' ' -f2-)

    if (( ${#segments[@]} == 0 )); then
        capture_notify "Clip not saved" "No replay frames are available yet." "low"
        return 1
    fi

    # The newest segment is still being written; only stitch closed segments.
    # The ring keeps one spare segment so the full requested length remains.
    if (( ${#segments[@]} > 1 )); then
        unset 'segments[${#segments[@]}-1]'
    fi

    # A segment can be mid-rotation or partially written. Only feed readable
    # segments to the concat demuxer, and use their probed durations for trim.
    total=0
    for segment in "${segments[@]}"; do
        duration="$(ffprobe -v error -show_entries format=duration \
            -of csv=p=0 "$segment" 2>/dev/null)"
        [[ "$duration" =~ ^[0-9]+([.][0-9]+)?$ ]] || continue
        if awk -v d="$duration" 'BEGIN { exit !(d > 0) }'; then
            valid+=("$segment")
            total="$(awk -v t="$total" -v d="$duration" \
                'BEGIN { printf "%.3f", t + d }')"
        fi
    done

    if (( ${#valid[@]} == 0 )); then
        capture_notify "Clip not saved" "No complete replay frames are available yet." "low"
        return 1
    fi

    : > "$list_file"
    for segment in "${valid[@]}"; do
        escaped="${segment//\'/\'\\\'\'}"
        printf "file '%s'\n" "$escaped" >> "$list_file"
    done
    start="$(awk -v total="$total" -v wanted="$clip_seconds" \
        'BEGIN { value = total - wanted; if (value < 0) value = 0; printf "%.3f", value }')"

    target_dir="$(capture_target_dir "$clip_dir" "$clip_display")"
    mkdir -p "$target_dir" || {
        capture_notify "Clip not saved" "Cannot create clip directory: $target_dir" "critical"
        return 1
    }
    file="$(capture_unique_file "$target_dir" cyan1de-clip mp4)"
    preset="$(capture_quality_preset "$clip_quality")"
    if [[ "$clip_audio" == "1" ]]; then
        audio_output=(-c:a aac -b:a 160k)
    else
        audio_output=(-an)
    fi

    if ffmpeg -hide_banner -loglevel warning -ss "$start" \
        -f concat -safe 0 -i "$list_file" -map 0 \
        -c:v libx264 -preset "$preset" -crf "$(capture_quality_crf "$clip_quality")" \
        -pix_fmt yuv420p "${audio_output[@]}" -movflags +faststart \
        -y "$file" >> "$log_file" 2>&1; then
        capture_notify "Clip saved" "Last ${clip_seconds}s → $file"
    else
        rm -f "$file"
        capture_notify "Clip not saved" "ffmpeg could not assemble the replay buffer." "critical"
        return 1
    fi
}

case "${1:-ensure}" in
    ensure) ensure_replay ;;
    run) run_replay ;;
    clip) save_clip ;;
    restart)
        stop_replay
        ensure_replay
        ;;
    stop)
        stop_replay
        capture_notify "Replay buffer stopped" "Rolling clips are disabled."
        ;;
    *)
        printf 'Usage: %s {ensure|run|clip|stop}\n' "$0" >&2
        exit 2
        ;;
esac
