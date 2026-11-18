-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
--                         HYPRLAND MAIN ENTRYPOINT                           --
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

-- Configuration is split into one file per domain in ~/.config/hypr/hyprland/.
--
-- Machine-managed (edited in Quickshell Settings -> Hyprland, then Apply):
--   input.lua, programs.lua, monitors.lua, autostart.lua, env.lua,
--   ui_overrides.lua, keybindings.lua
-- Hand-edited (advanced/raw options, not rewritten by Settings):
--   look_and_feel.lua, permissions.lua, rules.lua
--
-- Each managed file owns every parameter it defines - no value is defined in
-- two places. ui_overrides.lua loads last so it is the single source of truth
-- for look & feel values exposed in the Appearance tab.

require("hyprland.monitors")
require("hyprland.programs")
require("hyprland.autostart")
require("hyprland.env")
require("hyprland.permissions")
require("hyprland.look_and_feel")
require("hyprland.input")
require("hyprland.keybindings")
require("hyprland.rules")

-- Managed look & feel overrides (loaded last)
require("hyprland.ui_overrides")
