#!/usr/bin/env bash

echo -------------------------------------
echo         s1mpledots installer
echo   Make sure you have yay installed
echo -------------------------------------
while true; do
    echo "1) Install"
    echo "2) Quit"
    read -p "Choose an option [1-2]: " choice

    if [[ "$choice" == "1" || "${choice,,}" == "install" ]]; then
        echo "Starting installation..."
        sudo pacman -S hyprland alacritty nemo xdg-desktop-portal-hyprland fuzzel swayosd hyprlock hypridle pavucontrol inotify-tools ttf-jetbrains-mono-nerd hyprshot --noconfirm;
        yay -S wlogout waypaper;
	 	cp -r ./config/hypr ~/.config;
		cp -r ./config/waybar ~/.config;
		cp -r ./config/alacritty ~/.config;
		cp -r ./config/fuzzel ~/.config;
        break
    elif [[ "$choice" == "2" || "${choice,,}" == "quit" ]]; then
        echo "Exiting."
        break
    else
        echo "Invalid option. Please enter 1 or 2."
    fi
done

