#!/usr/bin/env bash
set -euo pipefail

# Generate small Adwaita-derived GTK themes with the cyan1de accent applied,
# then point GTK/GTK4/libadwaita at the right theme and accent. Qt apps use the
# gtk3 platform theme in this desktop, so they pick up the same palette.

exec python3 - "${1:-#7cc7f5}" "${2:-dark}" <<'PY'
import os
import re
import subprocess
import sys

DEFAULT = (124, 199, 245)
ACCENTS = {
    "blue": (0x35, 0x84, 0xE4),
    "teal": (0x21, 0x90, 0xA4),
    "green": (0x3A, 0x94, 0x4A),
    "yellow": (0xC8, 0x88, 0x00),
    "orange": (0xED, 0x5B, 0x00),
    "red": (0xE6, 0x2D, 0x42),
    "pink": (0xD5, 0x61, 0x99),
    "purple": (0x91, 0x41, 0xAC),
    "slate": (0x6F, 0x83, 0x96),
}


def clamp(value):
    return max(0, min(255, int(round(value))))


def parse_hex(value):
    text = str(value or "").strip().lstrip("#")
    if re.fullmatch(r"[0-9a-fA-F]{3}", text):
        text = "".join(ch * 2 for ch in text)
    if not re.fullmatch(r"[0-9a-fA-F]{6}", text):
        return DEFAULT
    return tuple(int(text[i:i + 2], 16) for i in (0, 2, 4))


def to_hex(rgb):
    return "#{:02x}{:02x}{:02x}".format(*(clamp(v) for v in rgb))


def mix(a, b, amount):
    t = max(0.0, min(1.0, amount))
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def luma(rgb):
    return (0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2]) / 255.0


def accent_name(rgb):
    weights = (0.30, 0.59, 0.11)
    return min(ACCENTS, key=lambda name: sum(
        weights[i] * (rgb[i] - ACCENTS[name][i]) ** 2 for i in range(3)))


def write_if_changed(path, text):
    try:
        with open(path, "r", encoding="utf-8") as handle:
            if handle.read() == text:
                return
    except OSError:
        pass
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(text)


accent = parse_hex(sys.argv[1])
mode = sys.argv[2].strip().lower() if len(sys.argv) > 2 else "dark"
if mode not in ("dark", "light"):
    mode = "dark"

fg = (17, 20, 27) if luma(accent) > 0.62 else (255, 255, 255)
home = os.environ.get("HOME", os.path.expanduser("~"))
themes_dir = os.path.join(home, ".themes")

for name, sheet, base, visited_base in [
    ("cyan1de-dark", "gtk-contained-dark.css", (48, 48, 48), (145, 65, 172)),
    ("cyan1de-light", "gtk-contained.css", (246, 245, 244), (105, 55, 140)),
]:
    muted = mix(accent, base, 0.48)
    muted_fg = (17, 20, 27) if luma(muted) > 0.62 else (255, 255, 255)
    visited = mix(accent, visited_base, 0.45)
    css = (
        '@import url("resource:///org/gtk/libgtk/theme/Adwaita/{}");\n'
        '@define-color theme_selected_bg_color {};\n'
        '@define-color theme_selected_fg_color {};\n'
        '@define-color theme_unfocused_selected_bg_color {};\n'
        '@define-color theme_unfocused_selected_fg_color {};\n'
        '@define-color link_color {};\n'
        '@define-color link_visited_color {};\n'
        '@define-color visited_link_color {};\n'
        '@define-color accent_color {};\n'
        '@define-color accent_bg_color {};\n'
        '@define-color accent_fg_color {};\n'
    ).format(
        sheet,
        to_hex(accent),
        to_hex(fg),
        to_hex(muted),
        to_hex(muted_fg),
        to_hex(accent),
        to_hex(visited),
        to_hex(visited),
        to_hex(accent),
        to_hex(accent),
        to_hex(fg),
    )

    theme_root = os.path.join(themes_dir, name)
    write_if_changed(
        os.path.join(theme_root, "index.theme"),
        "[X-GTK-Theme]\nName=cyan1de {}\nGtkVersion=3.0\n".format(
            "dark" if "dark" in name else "light"),
    )
    write_if_changed(
        os.path.join(theme_root, "gtk-3.0", "gtk.css"),
        css,
    )

theme = "cyan1de-" + mode
subprocess.check_call([
    "gsettings", "set", "org.gnome.desktop.interface", "gtk-theme", theme])
subprocess.check_call([
    "gsettings", "set", "org.gnome.desktop.interface", "color-scheme",
    "prefer-" + mode])
subprocess.check_call([
    "gsettings", "set", "org.gnome.desktop.interface", "accent-color",
    accent_name(accent)])
PY
