-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
--                         HYPRLAND MAIN ENTRYPOINT                           --
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

-- Load modular configuration components from ~/.config/hypr/hyprland/
require("hyprland.monitors")
require("hyprland.programs")
require("hyprland.autostart")
require("hyprland.env")
require("hyprland.permissions")
require("hyprland.look_and_feel")
require("hyprland.input")
require("hyprland.keybindings")
require("hyprland.rules")

-- Settings-managed look & feel overrides (loaded last)
require("hyprland.ui_overrides")
