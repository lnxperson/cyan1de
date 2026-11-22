--------------------------------------------------------------------------------
-- WINDOW RULES & WORKSPACE BEHAVIORS
-- Window matching, floating rules, sizing, and position overrides
--------------------------------------------------------------------------------

-- Prevent all applications from sending maximize requests to Hyprland
local suppressMaximizeRule = hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})

-- Fix drag-and-drop focus issues for unassigned XWayland utility windows
hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})

-- Custom floating rule and position for the hyprland-run app launcher
hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },

    move  = "20 monitor_h-120",
    float = true,
})

--------------------------------------------------------------------------------
-- WRAP-MODE FLOATING WINDOW CENTERING
--
-- "Unified + wrap" draws the bar's frame inside the monitor's outer gap, so the
-- visible workspace is the frame's hole. Hyprland still centres new floating
-- windows in the compositor's usable area, which ignores the far-side gap.
-- Nudge only windows that are still at that default centre into the hole's
-- centre; explicitly placed windows (for example hyprland-run) keep their spot.
--------------------------------------------------------------------------------

local quickshellSettings = (os.getenv("HOME") or "")
    .. "/.config/quickshell/settings.json"

-- Return the object literal that belongs to a top-level settings key. The
-- settings writer escapes no braces inside values, so brace counting is safe.
local function settingsObject(text, key)
    local matchStart = text:find('"' .. key .. '"%s*:%s*{')
    if not matchStart then return nil end
    local open = text:find("{", matchStart)
    if not open then return nil end
    local depth = 0
    for i = open, #text do
        local char = text:sub(i, i)
        if char == "{" then
            depth = depth + 1
        elseif char == "}" then
            depth = depth - 1
            if depth == 0 then
                return text:sub(open, i)
            end
        end
    end
    return nil
end

local function settingString(text, key)
    if not text then return nil end
    return text:match('"' .. key .. '"%s*:%s*"([^"]*)"')
end

local function settingNumber(text, key)
    if not text then return nil end
    return tonumber(text:match('"' .. key .. '"%s*:%s*(-?%d+%.?%d*)'))
end

local function wrapSettings()
    local file = io.open(quickshellSettings, "r")
    if not file then return nil end
    local text = file:read("*a")
    file:close()

    local bar = settingsObject(text, "bar")
    local hypr = settingsObject(text, "hypr")

    local layout = settingString(bar, "layout")
    if layout == "unifiedRamp" then layout = "unifiedWrap" end
    if layout ~= "unifiedWrap" then return nil end

    local edge = settingString(bar, "edge")
    if edge ~= "bottom" and edge ~= "left" and edge ~= "right" then
        edge = "top"
    end

    local gap = math.max(0, math.min(20, settingNumber(hypr, "gapsOut") or 0))
    if gap <= 0 then return nil end

    return {
        edge = edge,
        gap = gap,
        display = settingString(bar, "display") or "all",
    }
end

local function monitorShowsWrap(monitor, display)
    if display == "" or display == "all" then return true end
    if monitor.name == display then return true end

    -- Quickshell keeps the bar on every screen when the saved display is
    -- disconnected, so mirror that fallback here.
    for _, candidate in ipairs(hl.get_monitors()) do
        if candidate.name == display then return false end
    end
    return true
end

local function centreOf(window)
    local at, size = window.at, window.size
    if type(at) ~= "table" or type(size) ~= "table" then return nil end
    return at.x + size.x / 2, at.y + size.y / 2
end

hl.on("window.open", function(window)
    if not window.floating or (window.fullscreen or 0) ~= 0 then return end
    if window.workspace and window.workspace.has_fullscreen then return end

    local settings = wrapSettings()
    if not settings then return end

    local monitor = window.monitor
    if not monitor or not monitorShowsWrap(monitor, settings.display) then
        return
    end

    -- Hyprland reports the physical mode size; placement uses logical pixels,
    -- and 90/270 degree outputs swap the width and height.
    local scale = monitor.scale or 1
    local width, height = monitor.width / scale, monitor.height / scale
    if monitor.transform == 1 or monitor.transform == 3 then
        width, height = height, width
    end

    local reserved = monitor.reserved
    local top = type(reserved) == "table" and (reserved.top or 0) or 0
    local bottom = type(reserved) == "table" and (reserved.bottom or 0) or 0
    local left = type(reserved) == "table" and (reserved.left or 0) or 0
    local right = type(reserved) == "table" and (reserved.right or 0) or 0

    local usableW = width - left - right
    local usableH = height - top - bottom
    local usableCX = monitor.x + left + usableW / 2
    local usableCY = monitor.y + top + usableH / 2

    local cx, cy = centreOf(window)
    if not cx then return end

    -- Only touch windows that are still at Hyprland's default centre.
    if math.abs(cx - usableCX) > 2 or math.abs(cy - usableCY) > 2 then
        return
    end

    -- The wrap adds the outer gap on the far side of the bar, so the hole's
    -- centre sits half a gap closer to the bar than the usable area's centre.
    local shift = settings.gap / 2
    local targetCX, targetCY = usableCX, usableCY
    if settings.edge == "top" then
        targetCY = targetCY - shift
    elseif settings.edge == "bottom" then
        targetCY = targetCY + shift
    elseif settings.edge == "left" then
        targetCX = targetCX - shift
    else
        targetCX = targetCX + shift
    end

    local x = math.floor(targetCX - window.size.x / 2 + 0.5)
    local y = math.floor(targetCY - window.size.y / 2 + 0.5)
    hl.dispatch(hl.dsp.window.move({ x = x, y = y, window = window }))
end)
