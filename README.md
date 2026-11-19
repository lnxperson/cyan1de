# cyan1de
Very simple and straightforward dotfiles for Hyprland.

## Prerequisites

* You must be on Arch Linux or on an Arch based distribution (e.g. CachyOS, Manjaro, EndeavourOS)
* You must have git installed

## How to install

1. **Run** the following commands:

```bash
git clone https://github.com/lnxperson/cyan1de
cd cyan1de
chmod +x install.sh
./install.sh
```

2. **Follow** the instructions
3. Select **Hyprland** in your login screen

## What packages are installed?

The installer may install the following packages:

* hyprland
* quickshell
* alacritty
* nautilus
* firefox
* gnome-text-editor
* loupe
* papers
* xdg-desktop-portal-hyprland
* brightnessctl
* ddcutil
* hyprshot
* playerctl
* fprintd
* bluez
* bluez-utils
* networkmanager
* pipewire
* wireplumber
* qt6ct
* adw-gtk-theme
* ttf-jetbrains-mono-nerd
* python
* xdg-utils

## How to use

Upon starting Hyprland, you will be greeted by the welcome panel. Here you can see all of the core keybindings. By going into the settings panel you can customize a bunch of settings. These settings include top panel, wallpaper, appearance, input, keybindings, autostart, default programs, environment variables, monitors, window rules and notifications.

*Note: The lock screen is set to autostart by default. You can disable this by going to "Settings > Autostart > Remove line "~/.config/quickshell/lockscreen/lock.sh".*

## Compatibility

Hyprland works flawlessly on both NVIDIA and AMD graphics cards. NVIDIA cards may require the nvidia-open driver. You can install this by running
```bash
sudo pacman -S nvidia-open
```
AMD cards don't necessarily require any drivers as they're built in.

## Power Management

Power-profiles-daemon is supported. TLP works fine, too.
