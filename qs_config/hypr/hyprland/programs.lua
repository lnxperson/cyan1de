--------------------------------------------------------------------------------
-- DEFAULT APPLICATIONS
-- Defines default system applications exportable to other Lua modules
--------------------------------------------------------------------------------

local M = {}

M.terminal    = "alacritty"  -- Primary terminal emulator
M.fileManager = "G_MESSAGES_DEBUG=all nautilus --no-default-window"   -- GUI file manager
M.menu        = "/home/fish/.config/quickshell/launcher/toggle.sh"     -- Application launcher (Quickshell)
M.browser     = "zen-browser" -- Default web browser

return M
