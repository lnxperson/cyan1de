# cyan1de

A clean and portable **Hyprland + Quickshell** desktop configuration for Arch-based systems. It ships with floating pill panels, a full graphical settings app, a launcher, emoji picker, notification history, a compact OSD, lockscreen, and sensible default applications.

The shipped defaults use JetBrainsMono Nerd Font, a dark surface palette, and a blue-to-teal window-border gradient. Quickshell surfaces are opaque for crisp text; blur is limited to Hyprland windows and Alacritty.

![cyan1de desktop with the default applications](demopics/default_apps.png)

*The default desktop with the shipped panel and applications.*

---

## Highlights

- Floating **pills**, continuous **unified**, or edge-reveal **island** panel modes
- Panel on **top / bottom / left / right**, on **all displays** or one selected monitor
- Ten workspaces, scratchpad, floating-window controls, and per-monitor fullscreen bar hiding
- Centered clock, system tray, Bluetooth, network, volume, brightness, battery, and power controls
- On left/right bars, the clock stacks the date and time and the unread notification badge floats just above the calendar element
- Software-brightness monitors dim the panel, topbar popups, other popups and cursor without affecting DDC-controlled displays
- Calendar popup with media controls and notification history
- Notification banners with hover pause, history, low-battery warnings, and configurable placement
- Single-line OSD for volume, brightness, keyboard brightness, and night light
- App launcher with application, file, calculator, and web-search actions
- Emoji picker with search, clipboard history, and paste
- Lockscreen with a crash watchdog
- Graphical settings app that rewrites the managed Hyprland Lua files
- No Quickshell blur layers; Hyprland blur and Alacritty blur remain configurable

---

## Requirements

This is designed for **Arch Linux** or a derivative because `install.sh` installs packages with `pacman`.

The installer handles packages such as:

- `hyprland`, `quickshell`, `alacritty`
- `nautilus`, `firefox`, `gnome-text-editor`, `loupe`, `papers`
- `xdg-desktop-portal-hyprland`, `xdg-desktop-portal-gtk`
- `hyprpolkitagent`, `pavucontrol`
- `brightnessctl`, `ddcutil`, `hyprshot`, `hyprsunset`, `hypridle`
- `playerctl`, `power-profiles-daemon`, `fprintd`
- `bluez`, `bluez-utils`, `networkmanager`
- `pipewire`, `wireplumber`
- `qt6ct`, `adw-gtk-theme`
- `ttf-jetbrains-mono-nerd`, `noto-fonts-emoji`
- `python`, `xdg-utils`, `ripgrep`, `wl-clipboard`
- `wf-recorder`, `swappy`, `hyprpicker`

You can decline package installation and install them yourself.

---

## Installation

Simply run these commands in your terminal:

```bash
git clone https://github.com/lnxperson/cyan1de
cd cyan1de
chmod +x install.sh
./install.sh
```

The installer:

1. Backs up existing `~/.config/hypr` and `~/.config/quickshell` directories with a timestamp.
2. Optionally installs the required packages with `pacman`.
3. Sets default apps only when their desktop files are present.
4. Best-effort enables `fprintd.service`, `bluetooth.service`, `power-profiles-daemon.service`, and `NetworkManager.service`, plus the PipeWire user units.

### New features

- Screen recording: `Super + Alt + R` toggles `wf-recorder` into `~/Videos`.
- Screenshot annotation: `Super + Shift + Print` captures a region, opens `swappy`, and copies the annotated result to the clipboard.
- Color picker: `Super + Alt + C` picks a color and copies its hex value (`hyprpicker -a`).
- Keyboard layout switching: `Super + Alt + K` cycles layouts through `us` and `fr`.
- Idle inhibitor: `Super + Alt + I` toggles the idle inhibitor.
- Theme toggle: `Super + Alt + T` toggles light/dark; the wallpaper-driven schedule applies automatically.
5. Copies `config/hypr` and `config/quickshell` into `~/.config`.
6. Makes all shipped Quickshell helper scripts executable.

After installation, reload Hyprland or log out and back in.

To remove the installed config directories later, run `./install.sh` and choose **Remove**. This does not uninstall packages.

---

## Default applications

The installer sets these defaults when available:

| Type | Application |
| --- | --- |
| File manager | Nautilus |
| Text editor | GNOME Text Editor |
| Image viewer | Loupe |
| PDF viewer | Papers |
| Browser | Firefox |

The default applications and desktop layout are selected to work together out of the box; the result is shown at the top of this README.

---

## Top bar

The default panel is a floating pill layout with the app menu and workspaces on the left, the clock centered, and system controls on the right. Open a control to reveal its popup; the active control gets a sliding highlight.

![Top bar action section](demopics/action_section.png)

*The action section with quick system controls and popups.*

### Panel modes

Change this in **Settings → Appearance → Panel → Layout**:

| Mode | Behavior |
| --- | --- |
| `pills` | Separate floating pills for each group — default |
| `unified` | One continuous rounded panel with side margins |
| `unifiedCorners` | Unified bar attached flush to the screen corners |
| `unifiedWrap` | Unified bar plus a same-color frame around the other three screen edges, with every inner corner curved into the bar using Hyprland's window rounding radius |
| `island` | Compact panel that reveals near the selected screen edge |

The corners and wrap options are layout choices, not separate toggles. Existing configs that used the old **Unified bar + Corners on** combination are migrated to `unifiedCorners`, and configs saved with the earlier side-ramp option are migrated to `unifiedWrap` automatically.

The panel can sit on any edge and can follow all monitors or a single display. On left/right edges the clock shows a stacked date and time instead of a horizontal label. The unread notification badge sits just above that clock element rather than being buried inside it.

The reserved bar area follows **Outer gaps**. Detached layouts keep one outer gap between the screen edge and the bar; attached layouts sit flush. In both cases the gap between the bar and window space matches the normal window outer gap.

With `unifiedWrap`, the frame genuinely acts as the display border: **Outer gaps** is applied between the wrap and the window space, so tiled windows sit one gap away from the bar on its edge and one gap away from the frame on the other three edges. The frame stays a fixed 7px wide, so the frame edges use `7 + Outer gaps` while the bar edge uses `Outer gaps` directly. New floating windows that Hyprland would centre in the usable area are centred in that window space instead. Layout, edge, display and **Outer gaps** changes refresh the window gaps immediately from Settings; **Apply** is still needed for other Hyprland settings. Per-side wrap gaps apply only in `unifiedWrap` when the panel follows all displays; a single-display filter keeps gaps uniform on the other monitors. Every other layout leaves `gaps_out` uniform, so the outer gap is measured from the real screen edge and no wrap frame is involved.

The bar hides automatically on a monitor when that monitor’s active workspace has a fullscreen window, so fullscreen video is not covered. Other monitors keep their bars.

---

## App launcher

Press **Super + Space** to open the launcher. It supports application search, file search, calculator results, and web queries. Results can be launched directly or opened with the configured terminal and helper apps.

![Application launcher](demopics/launcher.png)

*Application search and quick actions.*

![Launcher calculator](demopics/launcher_calculation.png)

*Calculator results appear inline.*

![Launcher file search](demopics/launcher_file_search.png)

*File search opens results with the configured apps.*

![Launcher web search](demopics/launcher_web_search.png)

*Web queries can be sent straight to the browser.*

---

## Calendar and notifications

Click the clock to open the calendar. The popup can include media controls and notification history, and its layout and width are configurable in **Settings → Notifications → Calendar**.

![Calendar element and notification badge](demopics/calendar_element.png)

*The clock, calendar popup, and unread notification badge.*

Notifications support:

- top or bottom and left or right placement
- bubble duration and maximum visible count
- pause on hover
- optional persistent popups
- app icon and app name
- low-battery warnings
- notification history inside the calendar

---

## Settings app

Press **Super + comma** to open the settings app. It includes pages for:

- Appearance — wallpaper, panel, colors, and cursor
- Windows — borders, corner rounding, and gaps
- Effects — animations and blur
- Input — keyboard, pointer, touchpad, and gestures
- Keybindings — shortcuts and window actions
- Monitors — arrangement, scale, rotation, and refresh rate
- Session — idle dimming and screen lock
- Notifications — banners, history, calendar layout, and low-battery behavior
- Autostart — commands launched with Hyprland
- Programs — terminal, browser, file manager, and other defaults
- Environment — variables exported to applications
- Rules — window rules and per-app overrides

Hover any setting name for a short explanation of what it does. Ambiguous names such as **Layout** and **Sensitivity** have page-specific help text.

![Easy-to-configure settings](demopics/easy_to_configure_settings.png)

*Grouped controls make appearance and behavior changes straightforward.*

### How settings are written

Settings live in `~/.config/quickshell/settings.json` for Quickshell and in Hyprland Lua files for compositor behavior.

Files managed by the settings app are rewritten when you press **Apply**:

- `input.lua`
- `programs.lua`
- `monitors.lua`
- `autostart.lua`
- `env.lua`
- `ui_overrides.lua`
- `animations.lua`
- `keybindings.lua`

Hand-edited files that Settings does not rewrite:

- `look_and_feel.lua`
- `permissions.lua`
- `rules.lua`

---

## Monitor configuration

The **Monitors** page can arrange displays, set scale and rotation, enable or disable outputs, and configure resolution + refresh rate.
![Monitor settings](demopics/monitor_settings.png)

*Monitor arrangement and display settings.*

---

## Emoji picker

Press **Super + period** to open the emoji picker. Search results can be copied to the clipboard or pasted into the focused application, and copied emoji are kept in a local clipboard history.

![Emoji picker with clipboard history](demopics/emoji_picker_clipboard_history.png)

*Searchable emoji picker with clipboard history.*

---

## Window management

The default setup includes ten workspaces, a scratchpad, dwindle tiling, floating toggles, pseudo-tiling, split-direction toggling, and configurable window borders with a blue-to-teal gradient.

![Easy Window Management](demopics/eye_candy_window_management.png)

*Workspaces, borders, gaps, and window layout in use.*

![Workspace switcher](demopics/workspace_switcher.png)

*Switching between workspaces.*

---

## Developer friendly

Alacritty, the terminal-first launcher actions, and the compact OSD make this a comfortable daily driver for development. Window blur and transparency stay configurable without adding blur to Quickshell surfaces.

![Great for developers](demopics/great_for_developers.png)

*A terminal-focused desktop with the full panel and window effects available.*

---

## Default keybindings

`SUPER` is the main modifier.

| Shortcut | Action |
| --- | --- |
| `Super + Return` | Open terminal |
| `Super + Q` | Close window |
| `Super + E` | Open file manager |
| `Super + V` | Toggle floating state |
| `Super + Space` | Open app launcher |
| `Super + P` | Pseudo-tile window |
| `Super + J` | Toggle split direction |
| `Super + W` | Open browser |
| `Super + L` | Lock screen |
| `Super + comma` | Open settings |
| `Super + period` | Open emoji picker |
| `Super + Ctrl + P` | Toggle performance mode |
| `Super + 1` … `Super + 0` | Focus workspace 1–10 |
| `Super + Shift + 1` … `Shift + 0` | Move window to workspace 1–10 |
| `Super + F` | Toggle scratchpad |
| `Super + Shift + F` | Move window to scratchpad |
| `Super + Arrow keys` | Focus neighboring window |
| `Super + mouse_down` / `mouse_up` | Cycle workspaces |
| `Super + left click` / `right click` | Drag or resize floating window |
| `Print` | Region screenshot to clipboard |
| `Ctrl + Print` | Full monitor screenshot |
| `Shift + Print` | Region screenshot to file |
| `Super + Alt + R` | Toggle screen recording |
| `Super + Shift + Print` | Region screenshot with annotation |
| `Super + Alt + C` | Pick color and copy hex |
| `Super + Alt + K` | Cycle keyboard layout |
| `Super + Alt + I` | Toggle idle inhibitor |
| `Super + Alt + T` | Toggle light/dark theme |
| `Super + M` | Toggle power/session menu |
| `XF86Audio*` | Volume, mute, and media controls |
| `XF86MonBrightness*` | Display brightness |
| `XF86KbdBrightness*` | Keyboard brightness |

Screenshots use `hyprshot`.

---

## Layout

```text
cyan1de/
├── install.sh
├── README.md
├── demopics/
└── config/
    ├── hypr/
    │   ├── hypridle.conf
    │   ├── hyprland.lua
    │   └── hyprland/
    └── quickshell/
        ├── background/
        ├── emoji/
        ├── launcher/
        ├── lockscreen/
        ├── notifications/
        ├── osd/
        ├── performance/
        ├── settings/
        ├── topbar/
        ├── welcome/
        └── settings.json
```

Quickshell runs as separate named sessions: `topbar`, `osd`, `launcher`, `emoji`, `background`, `settings`, `notifications`, and `welcome`, plus the lockscreen watchdog.

---

## Notes

- Use a Wayland session with Hyprland.
- JetBrainsMono Nerd Font and Noto Emoji are expected; without them, glyphs may fall back.
- Quickshell panels are intentionally opaque. The available blur options are **Hyprland blur** and **Alacritty blur** in Settings.
- If a panel looks wrong after upgrading, remove the old `~/.config/quickshell` and `~/.config/hypr` directories and reinstall; the installer backs them up first.
- Popup content uses a shared fixed size; the calendar has its own fixed height to keep month switching stable.
- Demo screenshots live in `demopics/`.
