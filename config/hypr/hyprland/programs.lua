--------------------------------------------------------------------------------
-- DEFAULT APPLICATIONS
-- Defines default system applications exportable to other Lua modules
--------------------------------------------------------------------------------

local M = {}

M.terminal    = "alacritty"  -- Primary terminal emulator
M.fileManager = "nemo"       -- GUI file manager
M.menu        = "fuzzel"     -- Application launcher/dmenu replacement
M.browser     = "firefox"    -- Default web browser

return M
