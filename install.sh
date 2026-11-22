#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SRC="$SCRIPT_DIR/config"
CONFIG_HOME="${HOME}/.config"

# Packages actually referenced by the shipped Hyprland/Quickshell config.
PACKAGES=(
    hyprland
    quickshell
    alacritty
    nautilus
    firefox
    gnome-text-editor
    loupe
    papers
    xdg-desktop-portal-hyprland
    brightnessctl
    ddcutil
    hyprshot
    hyprsunset
    hypridle
    playerctl
    power-profiles-daemon
    fprintd
    bluez
    bluez-utils
    networkmanager
    pipewire
    wireplumber
    qt6ct
    adw-gtk-theme
    ttf-jetbrains-mono-nerd
    noto-fonts-emoji
    python
    xdg-utils
    ripgrep
    wl-clipboard
)

privileged() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    elif command -v sudo >/dev/null 2>&1; then
        sudo "$@"
    else
        echo "Cannot run privileged command: sudo is not available." >&2
        return 1
    fi
}

install_packages() {
    echo "Installing required packages with pacman..."
    privileged pacman -S --needed --noconfirm "${PACKAGES[@]}"
}

# Set the recommended default applications. Each entry is only applied when
# its desktop file is present, so skipping packages never leaves broken defaults.
set_mime_defaults() {
    if ! command -v xdg-mime >/dev/null 2>&1; then
        echo "xdg-mime not found; skipping MIME defaults."
        return 0
    fi

    mime_default() {
        local desktop="$1"
        shift
        local dir found=""
        for dir in "${XDG_DATA_HOME:-$HOME/.local/share}/applications" \
                   /usr/local/share/applications \
                   /usr/share/applications; do
            if [ -f "$dir/$desktop" ]; then
                found="$dir/$desktop"
                break
            fi
        done
        if [ -z "$found" ]; then
            echo "  skip $desktop (not installed)"
            return 0
        fi
        xdg-mime default "$desktop" "$@"
        echo "  default: $desktop -> $*"
    }

    echo "Setting default applications..."
    (
        export XDG_CURRENT_DESKTOP="${XDG_CURRENT_DESKTOP:-Hyprland}"
        mime_default org.gnome.Nautilus.desktop inode/directory
        mime_default org.gnome.TextEditor.desktop text/plain
        mime_default org.gnome.Loupe.desktop image/png image/jpeg image/webp image/gif
        mime_default org.gnome.Papers.desktop application/pdf
        mime_default firefox.desktop text/html x-scheme-handler/http x-scheme-handler/https
    )
}

enable_services() {
    command -v systemctl >/dev/null 2>&1 || return 0
    echo "Enabling fingerprint, Bluetooth and power-profiles services (best effort)..."
    for service in fprintd.service bluetooth.service power-profiles-daemon.service; do
        if privileged systemctl enable --now "$service" >/dev/null 2>&1; then
            echo "  enabled $service"
        else
            echo "  skip $service (not available or already enabled)"
        fi
    done
}

backup_dir() {
    local target="$1"
    [ -e "$target" ] || return 0
    local saved="${target}.bak.$(date +%Y%m%d%H%M%S)"
    mv -- "$target" "$saved"
    echo "Backed up: $target -> $saved"
}

make_scripts_executable() {
    local dir="$1" count=0
    [ -d "$dir" ] || return 0
    while IFS= read -r -d '' script; do
        chmod +x -- "$script"
        count=$((count + 1))
    done < <(find "$dir" -type f -name '*.sh' -print0)
    echo "Made $count shell script(s) executable in $dir"
}

install_config() {
    [ -d "$SRC/hypr" ] || { echo "Missing: $SRC/hypr" >&2; return 1; }
    [ -d "$SRC/quickshell" ] || { echo "Missing: $SRC/quickshell" >&2; return 1; }

    if ! read -r -p "Install cyan1de into ~/.config/hypr and ~/.config/quickshell? Existing dirs will be backed up. [y/N] " answer; then
        exit 0
    fi
    case "$answer" in
        y|Y|yes|YES) ;;
        *) echo "Cancelled."; return 0 ;;
    esac

    if ! read -r -p "Install required packages with pacman? [Y/n] " pkg_answer; then
        exit 0
    fi
    case "${pkg_answer:-y}" in
        n|N|no|NO)
            echo "Skipping package installation."
            ;;
        *)
            if ! install_packages; then
                echo "Package installation failed; config was not installed." >&2
                return 1
            fi
            set_mime_defaults
            enable_services
            ;;
    esac

    mkdir -p "$CONFIG_HOME"
    backup_dir "$CONFIG_HOME/hypr"
    backup_dir "$CONFIG_HOME/quickshell"
    cp -a -- "$SRC/hypr" "$CONFIG_HOME/hypr"
    cp -a -- "$SRC/quickshell" "$CONFIG_HOME/quickshell"

    # cp -a preserves the shipped mode bits, but enforce executability here so
    # every Quickshell helper works even if an archive/transfer dropped +x.
    make_scripts_executable "$CONFIG_HOME/quickshell"

    echo "Installed cyan1de."
    echo "Reload Hyprland or log out and back in."
}

remove_config() {
    if ! read -r -p "Remove ~/.config/hypr and ~/.config/quickshell? [y/N] " answer; then
        exit 0
    fi
    case "$answer" in
        y|Y|yes|YES) ;;
        *) echo "Cancelled."; return 0 ;;
    esac

    rm -rf -- "$CONFIG_HOME/hypr" "$CONFIG_HOME/quickshell"
    echo "Removed cyan1de config directories."
}

printf '%s\n' "------------------------------------" \
             "          cyan1de installer          " \
             "------------------------------------"

while true; do
    echo
    echo "1) Install"
    echo "2) Remove"
    echo "3) Quit"
    if ! read -r -p "Choose [1-3]: " choice; then
        exit 0
    fi

    case "$choice" in
        1|install)  install_config ;;
        2|remove)   remove_config ;;
        3|quit|q)   echo "Bye."; exit 0 ;;
        *)          echo "Invalid choice." ;;
    esac
done
