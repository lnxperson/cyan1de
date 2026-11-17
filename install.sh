#!/usr/bin/env bash

echo -------------------------------------
echo         s1mpledots installer
echo -------------------------------------
while true; do
    echo "1) Install (Standard config)"
    echo "2) Install (Quickshell config)"
    echo "3) Remove"
    echo "4) Quit"
    read -p "Choose an option [1-4]: " choice

    if [[ "$choice" == "1" || "${choice,,}" == "install" ]]; then
        echo "Starting installation..."
        sudo pacman -S hyprland alacritty nautilus loupe gnome-text-editor xdg-desktop-portal-hyprland fuzzel swayosd hyprlock hypridle pavucontrol inotify-tools ttf-jetbrains-mono-nerd hyprshot waybar nwg-displays --noconfirm;
        yay -S wlogout waypaper;
	 	cp -r ./config/hypr ~/.config;
		cp -r ./config/waybar ~/.config;
		cp -r ./config/alacritty ~/.config;
		cp -r ./config/fuzzel ~/.config;
        break
    elif [[ "$choice" == "2" || "${choice,,}" == "quickshell" ]]; then
        echo "Starting installation..."
        sudo pacman -S hyprland alacritty gnome-text-editor loupe nautilus pavucontrol ttf-jetbrains-mono-nerd-font hyprshot nwg-displays quickshell --noconfirm
        	cp -r ./qs_config/hypr ~/.config
        	cp -r ./qs_config/quickshell ~/.config
        break
    elif [[ "$choice" == "3" || "${choice,,}" == "remove" ]]; then
        echo "Removing dotfiles (You must remove Hyprland and Alacritty yourself)"
        sudo pacman -Rns nemo xdg-desktop-portal-hyprland fuzzel swayosd hyprlock hypridle pavucontrol inotify-tools ttf-jetbrains-mono-nerd hyprshot waybar wlogout waypaper nwg-displays --noconfirm;
        rm -rf ~/.config/hypr
        rm -rf ~/.config/waybar
        rm -rf ~/.config/alacritty
        rm -rf ~/.config/fuzzel
        rm -rf ~/.config/quickshell
        break
    elif [[ "$choice" == "4" || "${choice,,}" == "quit" ]]; then
        echo "Quitting..."
        exit
    else
        echo "Invalid option. Please enter 1, 2, 3, or 4."
    fi
done
