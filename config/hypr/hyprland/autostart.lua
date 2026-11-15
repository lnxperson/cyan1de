--------------------------------------------------------------------------------
-- AUTOSTART & SYSTEM INITIALIZATION
-- Commands and background daemons executed upon Hyprland startup
--------------------------------------------------------------------------------

hl.on("hyprland.start", function () 
    -- Launch status bar (waybar) and desktop background daemon (hyprpaper)
    hl.exec_cmd("waybar & hyprpaper")

    -- Set QT application theme to match system style via Qt6ct configuration
    hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")

    -- Set GTK system dark theme and color scheme preference
    hl.exec_cmd("gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark'")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'")

    -- Screen lock daemon initialization
    hl.exec_cmd("hyprlock")

    -- Restore saved wallpaper using Waypaper
    hl.exec_cmd("waypaper --restore")

    -- Start SwayOSD server for volume and brightness visual feedback popups
    hl.exec_cmd("swayosd-server")
end)
