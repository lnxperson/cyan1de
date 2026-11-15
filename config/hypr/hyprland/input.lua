--------------------------------------------------------------------------------
-- INPUT DEVICES & GESTURES
-- Keyboard layouts, mouse sensitivity, trackpad settings, and gestures
--------------------------------------------------------------------------------

hl.config({
    input = {
        kb_layout  = "en", -- Keyboard layout
        kb_variant = "",
        kb_model   = "",
        kb_options = "",
        kb_rules   = "",

        follow_mouse = 1,  -- Focus follows cursor movement (1 = fully enabled)
        sensitivity  = 0,  -- Pointer sensitivity adjustment (-1.0 to 1.0; 0 = no change)

        touchpad = {
            natural_scroll = true, -- Inverted/Natural scrolling (iOS/macOS style)
        },
    },
})

-- 3-Finger swipe horizontal gesture to switch active workspace
hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace"
})

-- Per-device overrides (e.g., custom DPI/sensitivity for specific hardware)
hl.device({
    name        = "epic-mouse-v1",
    sensitivity = -0.5,
})
