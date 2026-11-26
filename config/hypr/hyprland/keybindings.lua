--------------------------------------------------------------------------------
-- KEYBINDINGS
-- Shortcuts for window controls, app launching, audio, and navigation
--------------------------------------------------------------------------------

-- Import default application shortcuts
local programs    = require("hyprland.programs")
local terminal    = programs.terminal
local fileManager = programs.fileManager
local menu        = programs.menu
local browser	= programs.browser
local screenshot = programs.screenshot

local mainMod = "SUPER" -- Super/Windows Key

-- Set both Hyprland's state and the client's state explicitly. Some games
-- request their own fullscreen state, which can make a plain toggle need two
-- presses before the window actually fills the screen.
local function toggleFullscreen()
    local window = hl.get_active_window()
    if not window then return end
    if (window.fullscreen or 0) == 2 then
        hl.dispatch(hl.dsp.window.fullscreen_state({ internal = 0, client = 0, action = "set", layout_aware = false }))
    else
        hl.dispatch(hl.dsp.window.fullscreen_state({ internal = 2, client = 2, action = "set", layout_aware = false }))
    end
end

-- -----------------------------------------------------------------------------
-- Core Application & Window Bindings
-- -----------------------------------------------------------------------------
hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(terminal), { description = "Open terminal" })
local closeWindowBind = hl.bind(mainMod .. " + Q", hl.dsp.window.close(), { description = "Close window" })

-- System power menu / session exit


hl.bind(mainMod .. " + E",     hl.dsp.exec_cmd(fileManager), { description = "Open file manager" })
hl.bind(mainMod .. " + V",     hl.dsp.window.float({ action = "toggle" }), { description = "Toggle Floating state" }) -- Toggle Floating state
hl.bind(mainMod .. " + F",     toggleFullscreen, { description = "Toggle fullscreen" })
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd(menu), { description = "Open app launcher" })                     -- Open app launcher
hl.bind(mainMod .. " + P",     hl.dsp.window.pseudo(), { description = "Pseudo-tiling window" })                    -- Pseudo-tiling window
hl.bind(mainMod .. " + J",     hl.dsp.layout("togglesplit"), { description = "Toggle window split direction" })              -- Toggle window split direction
hl.bind(mainMod .. " + W",     hl.dsp.exec_cmd(browser), { description = "Open browser" })
hl.bind(mainMod .. " + L",     hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/quickshell/lockscreen/lock.sh"), { description = "Lock screen" })     -- Lock screen
hl.bind(mainMod .. " + comma", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/quickshell/settings/toggle.sh"), { description = "Desktop settings" })       -- Desktop settings
hl.bind(mainMod .. " + period", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/quickshell/emoji/toggle.sh"), { description = "Emoji picker" })             -- Emoji picker
hl.bind(mainMod .. " + CTRL + P", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/quickshell/performance/toggle.sh"), { locked = true, description = "Toggle performance mode" }) -- Performance mode

-- Screenshot annotation and auxiliary actions
hl.bind("SUPER + SHIFT + PRINT", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/quickshell/screenshot/annotate.sh"), { description = "Region screenshot with annotation" })
hl.bind("SUPER + ALT + C", hl.dsp.exec_cmd("hyprpicker -a"), { description = "Pick a color and copy its hex value" })
hl.bind("SUPER + ALT + K", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/quickshell/input/layout.sh"), { description = "Cycle keyboard layout" })
hl.bind("SUPER + ALT + I", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/quickshell/power/inhibit.sh"), { description = "Toggle idle inhibitor" })
hl.bind("SUPER + ALT + T", hl.dsp.exec_cmd("qs ipc -c settings call settings toggleTheme"), { description = "Toggle light/dark theme" })

-- Keyboard-only topbar popups
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("qs ipc -c topbar call topbar cycleAction"), { description = "Cycle action popups" })
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("qs ipc -c topbar call topbar calendar"), { description = "Toggle calendar popup" })
hl.bind("SUPER + M", hl.dsp.exec_cmd("qs ipc -c topbar call topbar power"), { description = "Toggle power/session menu" })


-- -----------------------------------------------------------------------------
-- Screenshots (Hyprshot)
-- -----------------------------------------------------------------------------
hl.bind("PRINT",            hl.dsp.exec_cmd(screenshot .. " -m region --clipboard-only"), { description = "Area selection to clipboard" })
hl.bind("CTRL + PRINT", hl.dsp.exec_cmd(screenshot .. " -m output"), { description = "Full active display" })
hl.bind("SHIFT + PRINT",    hl.dsp.exec_cmd(screenshot .. " -m region"), { description = "Area selection save to disk" })

-- -----------------------------------------------------------------------------
-- Navigation & Focus Controls
-- -----------------------------------------------------------------------------
-- Move window focus using Super + Arrow keys
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }), { description = "Focus left" })
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }), { description = "Focus right" })
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }), { description = "Focus up" })
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }), { description = "Focus down" })

-- Switch workspaces (Super + 1..0) & Move focused window to workspace (Super + Shift + 1..0)
for i = 1, 10 do
    local key = i % 10 -- Maps workspace 10 to key '0'
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }), { description = "Workspace i" })
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }), { description = "Move to workspace i" })
end

-- Special Workspace (Scratchpad)
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"), { description = "Toggle scratchpad view" })            -- Toggle scratchpad view
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }), { description = "Move active window to scratchpad" }) -- Move active window to scratchpad

-- Scroll through existing workspaces with Super + Mouse Scroll Wheel
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), { description = "Workspace e+1" })
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }), { description = "Workspace e-1" })

-- Move and Resize floating windows by dragging with Super + Left/Right click
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true, description = "Drag floating window" })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Resize floating window" })

-- -----------------------------------------------------------------------------
-- Hardware & Multimedia Function Keys
-- -----------------------------------------------------------------------------
local repeat_locked = { locked = true, repeating = true }
local locked_only   = { locked = true }

-- Volume & Brightness Controls (via wpctl & Brightnessctl)
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true, description = "Run: wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+" })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),         { locked = true, repeating = true, description = "Run: wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-" })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),        { locked = true, description = "Run: wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle" })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),      { locked = true, description = "Run: wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle" })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -c backlight set 5%+"),                { locked = true, repeating = true, description = "Run: brightnessctl -c backlight set 5%+" })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -c backlight set 5%-"),                { locked = true, repeating = true, description = "Run: brightnessctl -c backlight set 5%-" })
hl.bind("XF86KbdBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -d *::kbd_backlight set +33%"), { locked = true, repeating = true, description = "Run: brightnessctl -d *::kbd_backlight set +33%" })
hl.bind("XF86KbdBrightnessDown", hl.dsp.exec_cmd("brightnessctl -d *::kbd_backlight set 33%-"), { locked = true, repeating = true, description = "Run: brightnessctl -d *::kbd_backlight set 33%-" })

-- Media Player Controls (via Playerctl)
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true, description = "Run: playerctl next" })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Run: playerctl play-pause" })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Run: playerctl play-pause" })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true, description = "Run: playerctl previous" })
