--------------------------------------------------------------------------------
-- AUTOSTART & SYSTEM INITIALIZATION
-- Managed by Quickshell Settings — regenerated when you press Apply.
--------------------------------------------------------------------------------

hl.on("hyprland.start", function ()
    hl.exec_cmd("qs -c topbar -d")
    hl.exec_cmd("qs -c osd -d")
    hl.exec_cmd("qs -c launcher -d")
    hl.exec_cmd("qs -c background -d")
    hl.exec_cmd("qs -c settings -d")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark'")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'")
end)
