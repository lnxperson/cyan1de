--------------------------------------------------------------------------------
-- AUTOSTART & SYSTEM INITIALIZATION
-- Managed by Quickshell Settings - regenerated when you press Apply.
--------------------------------------------------------------------------------

hl.on("hyprland.start", function ()
    hl.exec_cmd("qs -c topbar -d")
    hl.exec_cmd("qs -c osd -d")
    hl.exec_cmd("qs -c launcher -d")
    hl.exec_cmd("qs -c emoji -d")
    hl.exec_cmd("qs -c background -d")
    hl.exec_cmd("qs -c settings -d")
    hl.exec_cmd("qs -c notifications -d")
    hl.exec_cmd("qs -c welcome -d")
    hl.exec_cmd("~/.config/quickshell/lockscreen/lock.sh")
    hl.exec_cmd("command -v hyprsunset >/dev/null 2>&1 && hyprsunset")
    hl.exec_cmd("~/.config/quickshell/settings/apply-gtk-accent.sh '#7cc7f5' 'dark'")
    hl.exec_cmd("command -v hyprpolkitagent >/dev/null 2>&1 && hyprpolkitagent")
    hl.exec_cmd("command -v hypridle >/dev/null 2>&1 && hypridle -c \"$HOME/.config/hypr/hypridle.conf\"")
end)
