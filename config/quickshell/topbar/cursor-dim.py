#!/usr/bin/env python3
"""Dim the software cursor while it is over a software-brightness monitor.

Hyprland composites the software cursor after every layer surface, so a dim
overlay cannot cover it. This helper derives a dimmed Xcursor theme from the
current theme and switches to it with `hyprctl setcursor` only while the
cursor is on a monitor whose brightness is software-controlled and below 100.

Called from the topbar shell (periodically) and from Brightness.qml whenever
a brightness value is committed. It is safe to call repeatedly: all work is
skipped unless the desired theme actually changes.
"""

import json
import os
import pathlib
import struct
import subprocess
import sys

HOME = pathlib.Path(os.environ.get("HOME") or pathlib.Path.home())
CONFIG = HOME / ".config" / "quickshell"
BRIGHTNESS_FILE = CONFIG / "soft-brightness.json"
STATE_FILE = HOME / ".cache" / "cyan1de" / "cursor-dim.json"
ICON_ROOT = HOME / ".local" / "share" / "icons"

XCURSOR_MAGIC = 0x72756358
IMAGE_CHUNK = 0xFFFD0002
SCAN_DIRS = (
    HOME / ".local" / "share" / "icons",
    HOME / ".icons",
    pathlib.Path("/usr/share/icons"),
    pathlib.Path("/usr/share/pixmaps"),
)


def run(argv):
    try:
        return subprocess.run(
            argv, capture_output=True, text=True, timeout=5, check=False
        ).stdout
    except (OSError, subprocess.SubprocessError):
        return ""


def read_json(path):
    try:
        with path.open(encoding="utf-8") as handle:
            data = json.load(handle)
        return data if isinstance(data, dict) else {}
    except (OSError, ValueError):
        return {}


def write_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    with tmp.open("w", encoding="utf-8") as handle:
        json.dump(data, handle)
        handle.write("\n")
    os.replace(tmp, path)


def theme_dir(name):
    for base in SCAN_DIRS:
        candidate = base / name
        if (candidate / "cursors").is_dir():
            return candidate
    return None


def source_cursors(theme):
    """Resolve a theme name to a directory containing Xcursor files."""
    seen = set()
    name = theme or "default"
    while name and name not in seen:
        seen.add(name)
        found = theme_dir(name)
        if found:
            return found / "cursors"
        inherits = ""
        for base in SCAN_DIRS:
            index = base / name / "index.theme"
            try:
                for line in index.read_text(encoding="utf-8").splitlines():
                    if line.strip().startswith("Inherits"):
                        inherits = line.split("=", 1)[1].strip() if "=" in line else ""
                        break
            except OSError:
                pass
            if inherits:
                break
        name = inherits.split(",")[0].strip() if inherits else ""
    return None


def dim_xcursor(data, factor):
    """Scale the alpha byte of every Xcursor image by factor."""
    try:
        magic, _, _, entries = struct.unpack_from("<IIII", data, 0)
    except struct.error:
        return None
    if magic != XCURSOR_MAGIC:
        return None

    out = bytearray(data)
    for i in range(entries):
        try:
            chunk_type, _chunk_id, pos = struct.unpack_from("<III", data, 16 + i * 12)
        except struct.error:
            continue
        if chunk_type != IMAGE_CHUNK or pos + 36 > len(data):
            continue
        header = struct.unpack_from("<9I", data, pos)
        chunk_header, width, height = header[0], header[4], header[5]
        if chunk_header < 36:
            continue
        start = pos + chunk_header
        count = width * height
        if start + count * 4 > len(data):
            continue
        for pixel in range(start, start + count * 4, 4):
            alpha = out[pixel + 3]
            out[pixel + 3] = max(0, min(255, round(alpha * factor)))
    return bytes(out)


def generate_theme(level, source, original, size):
    theme = f"cyan1de-dim-{level}"
    target_dir = ICON_ROOT / theme
    marker = target_dir / ".cyan1de-level"
    if marker.is_file():
        try:
            if int(marker.read_text(encoding="utf-8").strip()) == level:
                return theme
        except ValueError:
            pass

    if not source or not source.is_dir():
        return None

    tmp_dir = ICON_ROOT / f".{theme}.tmp"
    cursor_dir = tmp_dir / "cursors"
    if tmp_dir.exists():
        import shutil

        shutil.rmtree(tmp_dir)
    cursor_dir.mkdir(parents=True)

    factor = level / 100.0
    cache = {}
    for entry in sorted(source.iterdir()):
        if not entry.is_file():
            continue
        real = entry.resolve()
        if real not in cache:
            try:
                cache[real] = dim_xcursor(real.read_bytes(), factor)
            except OSError:
                cache[real] = None
        dimmed = cache[real]
        if dimmed is not None:
            (cursor_dir / entry.name).write_bytes(dimmed)

    (tmp_dir / "index.theme").write_text(
        f"[Icon Theme]\nName={theme}\nComment=Dimmed cursor at {level}%\n",
        encoding="utf-8",
    )
    (tmp_dir / marker.name).write_text(f"{level}\n", encoding="utf-8")

    final_dir = ICON_ROOT / theme
    if final_dir.exists():
        import shutil

        shutil.rmtree(final_dir)
    os.replace(tmp_dir, final_dir)
    return theme


def monitor_under_cursor():
    monitors = []
    try:
        monitors = json.loads(run(["hyprctl", "monitors", "-j"]) or "[]")
    except ValueError:
        monitors = []

    focused = next((m for m in monitors if m.get("focused")), None)
    try:
        parts = run(["hyprctl", "cursorpos"]).strip().split(",")
        x, y = int(parts[0]), int(parts[1])
    except (ValueError, IndexError):
        return focused.get("name") if focused else None

    matches = []
    for monitor in monitors:
        scale = float(monitor.get("scale") or 1)
        mx, my = int(monitor.get("x") or 0), int(monitor.get("y") or 0)
        width = float(monitor.get("width") or 0) / scale
        height = float(monitor.get("height") or 0) / scale
        if mx <= x <= mx + width and my <= y <= my + height:
            matches.append(monitor)

    if focused and focused in matches:
        return focused.get("name")
    if matches:
        return matches[0].get("name")
    return focused.get("name") if focused else None


def desired_theme():
    original = (
        os.environ.get("HYPRCURSOR_THEME")
        or os.environ.get("XCURSOR_THEME")
        or "default"
    )
    size = os.environ.get("HYPRCURSOR_SIZE") or os.environ.get("XCURSOR_SIZE") or "24"

    monitor = monitor_under_cursor()
    raw = 100
    values = read_json(BRIGHTNESS_FILE)
    if monitor and isinstance(values.get(monitor), (int, float)):
        raw = max(0, min(100, int(values[monitor])))

    if raw >= 98:
        return original, int(size)

    level = max(5, min(95, 5 * round(raw / 5)))
    source = source_cursors(original)
    theme = generate_theme(level, source, original, int(size))
    return theme or original, int(size)


def main():
    theme, size = desired_theme()
    state = read_json(STATE_FILE)
    if state.get("theme") == theme and state.get("size") == size:
        return 0

    result = run(["hyprctl", "setcursor", theme, str(size)])
    if result.strip().lower() not in ("ok", ""):
        print(f"hyprctl setcursor failed: {result.strip()}", file=sys.stderr)
        return 1

    write_json(STATE_FILE, {"theme": theme, "size": size})
    return 0


if __name__ == "__main__":
    sys.exit(main())
