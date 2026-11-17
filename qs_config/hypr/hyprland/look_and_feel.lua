--------------------------------------------------------------------------------
-- LOOK AND FEEL (Aesthetics, Animations, Layouts)
--------------------------------------------------------------------------------

-- -----------------------------------------------------------------------------
-- General Layout & Borders
-- -----------------------------------------------------------------------------
hl.config({
    general = {
        gaps_in  = 5,  -- Inner gap between adjacent windows (px)
        gaps_out = 5,  -- Outer gap between window and screen edge (px)

        border_size = 1,

        col = {
            -- Active border gradient (Blue to Teal) at a 45-degree angle
            active_border   = { colors = { "rgb(0292e3)", "rgb(01d6be)" }, angle = 45 },
            -- Inactive window border color (Dark Navy)
            inactive_border = "rgb(0f3246)",
        },

        resize_on_border = false, -- Drag window borders to resize
        allow_tearing    = false, -- Set to true for lower latency in gaming if supported
        layout           = "dwindle", -- Default tiling layout engine
    },

    -- -------------------------------------------------------------------------
    -- Visual Effects (Rounding, Opacity, Shadows, Blur)
    -- -------------------------------------------------------------------------
    decoration = {
        rounding       = 5,    -- Corner rounding radius (px)
        rounding_power = 10,   -- Corner curve sharpness
        active_opacity   = 1.0, -- Opacity of currently focused window
        inactive_opacity = 1.0, -- Opacity of background/unfocused windows

        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = 0xee1a1a1a,
        },

        blur = {
            enabled  = true,
            size     = 5,       -- Blur effect radius
            passes   = 2,       -- Higher passes = smoother blur, more GPU usage
            vibrancy = 0.1696,  -- Color saturation boost behind transparent windows
        },
    },

    animations = {
        enabled = true,
    },
})

-- -----------------------------------------------------------------------------
-- Animation Curves & Beziers
-- -----------------------------------------------------------------------------
-- Bezier curves defining speed curves for window movements and fades
hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1}    } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1}    } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}       } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1}    } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}     } })

-- Physics-based spring curve for organic window open/close movements
hl.curve("easy",           { type = "spring", mass = 1, stiffness = 238.1191, damping = 24.21279333 })

-- Assign animation behaviors to UI events
hl.animation({ leaf = "global",        enabled = true,  speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true,  speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true,  speed = 4.79, spring = "easy" })
hl.animation({ leaf = "windowsIn",     enabled = true,  speed = 4.1,  spring = "easy",         style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true,  speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true,  speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true,  speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true,  speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true,  speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true,  speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true,  speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true,  speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true,  speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true,  speed = 6,    bezier = "easeOutQuint", style = "slide" })
hl.animation({ leaf = "workspacesIn",  enabled = true,  speed = 6,    bezier = "easeOutQuint", style = "slide" })
hl.animation({ leaf = "workspacesOut", enabled = true,  speed = 6,    bezier = "easeOutQuint", style = "slide" })
hl.animation({ leaf = "zoomFactor",    enabled = true,  speed = 7,    bezier = "quick" })

-- -----------------------------------------------------------------------------
-- Layout Engine Configurations & Misc Options
-- -----------------------------------------------------------------------------
hl.config({
    dwindle = {
        preserve_split = true, -- Retains split directions when opening new windows
    },
})

hl.config({
    master = {
        new_status = "master", -- New windows open as the master window
    },
})

hl.config({
    scrolling = {
        fullscreen_on_one_column = true,
    },
})

hl.config({
    misc = {
        force_default_wallpaper = -1,    -- Set to 0 or 1 to disable default wallpapers
        disable_hyprland_logo   = false, -- Set true to disable default Hyprland wallpaper/logo
        allow_session_lock_restore = true, -- Allow a lockscreen to restart after a crash
    },
})

hl.config({
    layers = {
        -- Prevents popups/overlays from hiding behind fullscreen applications
        allow_new_top_layers_over_existing_fullscreen = true,
    },
})
