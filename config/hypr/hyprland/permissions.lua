--------------------------------------------------------------------------------
-- ECOSYSTEM & PERMISSIONS
-- Security and capability permissions for plugins and desktop utilities
--------------------------------------------------------------------------------

-- Uncomment to restrict app access to screen capture, plugins, etc.
-- hl.config({
--   ecosystem = {
--     enforce_permissions = true,
--   },
-- })

-- Allow screenshot utilities and display portal access to capture the screen
-- hl.permission("/usr/(bin|local/bin)/grim", "screencopy", "allow")
-- hl.permission("/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland", "screencopy", "allow")
-- hl.permission("/usr/(bin|local/bin)/hyprpm", "plugin", "allow")
