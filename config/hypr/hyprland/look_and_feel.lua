--------------------------------------------------------------------------------
-- LOOK AND FEEL (Aesthetics, Animations, Layouts)
--------------------------------------------------------------------------------

-- -----------------------------------------------------------------------------
-- General Layout & Borders
-- -----------------------------------------------------------------------------
-- NOTE: gaps, borders and colours are owned by ui_overrides.lua (loaded last).
-- Edit them in Quickshell Settings -> Hyprland -> Appearance, or in that file.
hl.config({
    general = {
        resize_on_border = false, -- Drag window borders to resize
        allow_tearing    = false, -- Set to true for lower latency in gaming if supported
        layout           = "dwindle", -- Default tiling layout engine
    },

    -- -------------------------------------------------------------------------
    -- Visual Effects (Rounding, Opacity, Shadows, Blur)
    -- -------------------------------------------------------------------------
    decoration = {
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
-- Animation Curves & Behaviors
-- -----------------------------------------------------------------------------
-- Curves and every animation leaf are owned by hyprland/animations.lua, which
-- Settings regenerates from Appearance -> Animations on Apply. Edit the styles
-- and speed there instead of here.

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
