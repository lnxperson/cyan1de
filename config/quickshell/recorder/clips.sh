#!/usr/bin/env bash
# Toggle the rolling replay-clip buffer and apply the change immediately.
set -uo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../capture/common.sh
source "$script_dir/../capture/common.sh"

next="$(python3 - "$CAPTURE_SETTINGS_PATH" <<'PY'
import json
import os
import sys
import tempfile

path = sys.argv[1]
try:
    with open(path, "r", encoding="utf-8") as fh:
        data = json.load(fh)
except Exception:
    data = {}

if not isinstance(data, dict):
    data = {}
capture = data.get("capture")
if not isinstance(capture, dict):
    capture = {}
    data["capture"] = capture
clips = capture.get("clips")
if not isinstance(clips, dict):
    clips = {}
    capture["clips"] = clips

# Shipped default is enabled, so a missing flag toggles off first.
current = clips.get("enabled", True) is True
enabled = not current
clips["enabled"] = enabled

directory = os.path.dirname(path) or "."
mode = 0o644
try:
    mode = os.stat(path).st_mode & 0o777
except OSError:
    pass
fd, tmp = tempfile.mkstemp(prefix=".settings-", dir=directory)
with os.fdopen(fd, "w", encoding="utf-8") as fh:
    json.dump(data, fh, indent=2, ensure_ascii=False)
    fh.write("\n")
os.chmod(tmp, mode)
os.replace(tmp, path)
print("1" if enabled else "0")
PY
)" || exit 0

if [[ "$next" == "1" ]]; then
    capture_notify "Replay clips enabled" "The rolling clip buffer is running."
else
    capture_notify "Replay clips disabled" "The rolling clip buffer was stopped."
fi

"$script_dir/replay.sh" ensure
