--------------------------------------------------------------------------------
-- MONITORS CONFIGURATION
-- Define output resolution, position, scaling, and rotation for display monitors
--------------------------------------------------------------------------------

-- Configures monitor settings automatically for all connected displays
hl.monitor({
    output   = "",          -- Empty string applies rule as a default to all monitors
    mode     = "preferred", -- Automatically pick the highest supported resolution/refresh rate
    position = "auto",      -- Automatically place monitors next to each other
    scale    = "1",         -- Display scaling factor (1 = 100%, 1.25 = 125%, etc.)
})
