#!/usr/bin/env bash

echo -------------------------------------
echo         s1mpledots installer
echo -------------------------------------
while true; do
    echo "1) Install"
    echo "2) Remove (Only run in tty or different DE/WM)"
    echo "3) Quit"
    read -p "Choose an option [1-3]: " choice

    if [[ "$choice" == "1" || "${choice,,}" == "install" ]]; then
        echo "Starting installation..."
        sudo pacman -S hyprland alacritty quickshell xdg-desktop-portal-hyprland nautilus loupe gnome-text-editor pavucontrol ttf-jetbrains-mono-nerd hyprshot --noconfirm;
        	cp -r ./qs_config/hypr ~/.config;
			cp -r ./qs_config/quickshell ~/.config;
        break
    elif [[ "$choice" == "2" || "${choice,,}" == "remove" ]]; then
        echo "Removing Dotfiles..."
        sudo pacman -Rns hyprland alacritty quickshell xdg-desktop-portal-hyprland nautilus loupe gnome-text-editor pavucontrol ttf-jetbrains-mono-nerd hyprshot --noconfirm;
        	rm -rf ~/.config/hypr;
			rm -rf ~/.config/quickshell;
        break
	elif [[ "$choice" == "3" || "${choice,,}" == "quit" ]]; then
		echo "Quitting..."
		exit
    else
        echo "Invalid option. Please enter 1, 2, or 3."
    fi
done
