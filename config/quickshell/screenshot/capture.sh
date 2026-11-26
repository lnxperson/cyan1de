#!/usr/bin/env bash
set -uo pipefail

# Screenshot helper used by the PRINT keybindings. Options come from Settings
# → Screen Capturing; the utility itself stays the Programs page setting.

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../capture/common.sh
source "$script_dir/../capture/common.sh"

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

mode="${1:-region}"
shot_args=()
read -r -a shot_cmd <<< "$(capture_screenshot_command)"
(( ${#shot_cmd[@]} > 0 )) || shot_cmd=(hyprshot)

run_shot() {
    "${shot_cmd[@]}" "$@"
}

copy_to_clipboard() {
    local file="$1" mime="image/png"
    command -v wl-copy >/dev/null 2>&1 || return 0
    [[ "$file" == *.jpg ]] && mime="image/jpeg"
    wl-copy -t "$mime" < "$file" >/dev/null 2>&1 || true
}

case "$mode" in
    clipboard)
        # Region selection goes straight to the clipboard, as before.
        run_shot -m region --clipboard-only -s >/dev/null 2>&1
        status=$?
        # hyprshot's silent watchdog exits 1 even after a successful copy.
        if (( status <= 1 )); then
            capture_notify "Screenshot copied" "Region selection is on the clipboard."
            exit 0
        fi
        capture_notify "Screenshot failed" "The screenshot utility exited with status $status." "critical"
        exit "$status"
        ;;

    region|output|window|active)
        mkdir -p "$shot_dir" || {
            capture_notify "Screenshot failed" "Cannot create screenshot directory: $shot_dir" "critical"
            exit 1
        }

        stage="$(capture_unique_file "$shot_dir" cyan1de png)"
        shot_args=(-m "$mode")
        # hyprshot's plain output/window modes wait for a click; -m active
        # captures the focused output or window immediately.
        [[ "$mode" == "output" || "$mode" == "window" ]] && shot_args+=(-m active)
        run_shot "${shot_args[@]}" -o "$shot_dir" -f "$(basename "$stage")" -s >/dev/null 2>&1
        status=$?
        if [[ ! -s "$stage" ]] || (( status > 1 )); then
            rm -f "$stage"
            capture_notify "Screenshot failed" "The screenshot utility exited with status $status." "critical"
            exit 1
        fi

        final="$stage"
        if [[ "$shot_format" == "jpg" ]]; then
            final="${stage%.png}.jpg"
            if command -v ffmpeg >/dev/null 2>&1 \
                && ffmpeg -hide_banner -loglevel error -y -i "$stage" \
                    -q:v 3 "$final" >/dev/null 2>&1; then
                rm -f "$stage"
            else
                final="$stage"
            fi
        fi

        [[ "$shot_copy" == "1" ]] && copy_to_clipboard "$final"
        capture_notify "Screenshot saved" "$final"
        ;;

    *)
        printf 'Usage: %s {clipboard|region|output|window|active}\n' "$0" >&2
        exit 2
        ;;
esac
