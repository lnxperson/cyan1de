#!/usr/bin/env bash

echo -------------------------------------
echo         s1mpledots installer
echo   Make sure you have yay installed
echo -------------------------------------
while true; do
    echo "1) Install"
    echo "2) Remove"
    echo "3) Quit"
    read -p "Choose an option [1-3]: " choice

    if [[ "$choice" == "1" || "${choice,,}" == "install" ]]; then
        echo "Starting installation..."
        sudo pacman -S hyprland alacritty nemo xdg-desktop-portal-hyprland fuzzel swayosd hyprlock hypridle pavucontrol inotify-tools ttf-jetbrains-mono-nerd hyprshot waybar --noconfirm;
        yay -S wlogout waypaper;
	 	cp -r ./config/hypr ~/.config;
		cp -r ./config/waybar ~/.config;
		cp -r ./config/alacritty ~/.config;
		cp -r ./config/fuzzel ~/.config;
        break
    elif [[ "$choice" == "2" || "${choice,,}" == "remove" ]]; then
        echo "Removing dotfiles (You must remove Hyprland and alacritty yourself)"
        sudo pacman -Rns nemo xdg-desktop-portal-hyprland fuzzel swayosd hyprlock hypridle pavucontrol inotify-tools ttf-jetbrains-mono-nerd hyprshot waybar --noconfirm;
        rm -rf ~/.config/hypr
        rm -rf ~/.config/waybar
        rm -rf ~/.config/alacritty
        rm -rf ~/.config/fuzzel
        break
    elif [[ "$choice" == "3" || "${choice,,}" == "quit" ]]; then
        echo "Quitting..."
        exit
    else
        echo "Invalid option. Please enter 1 or 2."
    fi
done
