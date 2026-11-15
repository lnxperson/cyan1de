--------------------------------------------------------------------------------
-- KEYBINDINGS
-- Shortcuts for window controls, app launching, audio, and navigation
--------------------------------------------------------------------------------

-- Import default application shortcuts
local programs    = require("hyprland.programs")
local terminal    = programs.terminal
local fileManager = programs.fileManager
local menu        = programs.menu

local mainMod = "SUPER" -- Super/Windows Key

-- -----------------------------------------------------------------------------
-- Core Application & Window Bindings
-- -----------------------------------------------------------------------------
hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(terminal))
local closeWindowBind = hl.bind(mainMod .. " + Q", hl.dsp.window.close())

-- System power menu
hl.bind(mainMod .. " + E",     hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + V",     hl.dsp.window.float({ action = "toggle" })) -- Toggle Floating state
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd(menu))                     -- Open app launcher
hl.bind(mainMod .. " + P",     hl.dsp.window.pseudo())                    -- Pseudo-tiling window
hl.bind(mainMod .. " + J",     hl.dsp.layout("togglesplit"))              -- Toggle window split direction
hl.bind(mainMod .. " + W",     hl.dsp.exec_cmd("firefox"))
hl.bind(mainMod .. " + L",     hl.dsp.exec_cmd("hyprlock"))               -- Lock screen
hl.bind(mainMod .. " + C",     hl.dsp.exec_cmd("alacritty --command nano ~/.config/hypr/hyprland.lua"))

-- -----------------------------------------------------------------------------
-- Screenshots (Hyprshot)
-- -----------------------------------------------------------------------------
hl.bind("PRINT",            hl.dsp.exec_cmd("hyprshot -m region --clipboard-only")) -- Area selection to clipboard
hl.bind(mainMod .. " + PRINT", hl.dsp.exec_cmd("hyprshot -m output"))                 -- Full active display
hl.bind("SHIFT + PRINT",    hl.dsp.exec_cmd("hyprshot -m region"))                 -- Area selection save to disk

-- -----------------------------------------------------------------------------
-- Navigation & Focus Controls
-- -----------------------------------------------------------------------------
-- Move window focus using Super + Arrow keys
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Switch workspaces (Super + 1..0) & Move focused window to workspace (Super + Shift + 1..0)
for i = 1, 10 do
    local key = i % 10 -- Maps workspace 10 to key '0'
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Special Workspace (Scratchpad)
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))            -- Toggle scratchpad view
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" })) -- Move active window to scratchpad

-- Scroll through existing workspaces with Super + Mouse Scroll Wheel
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Move and Resize floating windows by dragging with Super + Left/Right click
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- -----------------------------------------------------------------------------
-- Hardware & Multimedia Function Keys
-- -----------------------------------------------------------------------------
local repeat_locked = { locked = true, repeating = true }
local locked_only   = { locked = true }

-- Volume & Brightness Controls (via SwayOSD & Brightnessctl)
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("swayosd-client --output-volume raise"),      repeat_locked)
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("swayosd-client --output-volume lower"),      repeat_locked)
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("swayosd-client --output-volume mute-toggle"), locked_only)
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("swayosd-client --input-volume mute-toggle"),  locked_only)
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("swayosd-client --brightness raise"),          repeat_locked)
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("swayosd-client --brightness lower"),          repeat_locked)
hl.bind("XF86KbdBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -d *::kbd_backlight set +33%"), repeat_locked)
hl.bind("XF86KbdBrightnessDown", hl.dsp.exec_cmd("brightnessctl -d *::kbd_backlight set 33%-"), repeat_locked)

-- Media Player Controls (via Playerctl)
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
