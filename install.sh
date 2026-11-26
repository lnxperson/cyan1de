#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SRC="$SCRIPT_DIR/config"
CONFIG_HOME="${HOME}/.config"

# ---- Output styling ----------------------------------------------------
# Colour is optional: pipes, NO_COLOR and dumb terminals get plain text.
if [[ -t 1 && -z ${NO_COLOR:-} && ${TERM:-dumb} != dumb ]]; then
    BOLD=$'\033[1m'
    DIM=$'\033[2m'
    RESET=$'\033[0m'
    CYAN=$'\033[36m'
    BLUE=$'\033[34m'
    GREEN=$'\033[32m'
    YELLOW=$'\033[33m'
    RED=$'\033[31m'
    MAGENTA=$'\033[35m'
else
    BOLD=''; DIM=''; RESET=''
    CYAN=''; BLUE=''; GREEN=''; YELLOW=''; RED=''; MAGENTA=''
fi

banner_line() {
    local text="$1" color="$2"
    local len=${#text} left right padded
    left=$(( (50 - 2 - len) / 2 ))
    right=$(( 50 - 2 - len - left ))
    printf -v padded '%*s%s%*s' "$left" '' "$text" "$right" ''
    printf '  %s│%s %s%s%s %s│%s\n' "$CYAN" "$RESET" "$color" "$padded" "$RESET" "$CYAN" "$RESET"
}

show_banner() {
    local bar rule_bar
    printf -v bar '%*s' 50 ''
    rule_bar="${bar// /─}"
    printf '\n  %s╭%s╮%s\n' "$CYAN" "$rule_bar" "$RESET"
    banner_line "cyan1de" "$BOLD$MAGENTA"
    banner_line "portable Hyprland + Quickshell desktop" "$DIM"
    printf '  %s╰%s╯%s\n' "$CYAN" "$rule_bar" "$RESET"
}

section() {
    local bar
    printf -v bar '%*s' 50 ''
    printf '\n  %s%s%s\n' "$BOLD$BLUE" "$1" "$RESET"
    printf '  %s%s%s\n' "$DIM" "${bar// /─}" "$RESET"
}

ok()   { printf '  %s✓%s %s\n' "$GREEN"  "$RESET" "$1"; }
note() { printf '  %s·%s %s\n' "$DIM"    "$RESET" "$1"; }
warn() { printf '  %s!%s %s\n' "$YELLOW" "$RESET" "$1"; }
err()  { printf '  %sx%s %s\n' "$RED"    "$RESET" "$1" >&2; }

ask() {
    local prompt="$1" hint="$2"
    local answer
    if ! read -r -p "  ${YELLOW}▸${RESET} ${prompt} ${DIM}${hint}${RESET} " answer; then
        printf '\n'
        exit 0
    fi
    printf '%s' "$answer"
}

menu_item() {
    printf '  %s[%s]%s %s%s%s\n' "$CYAN" "$1" "$RESET" "$BOLD" "$2" "$RESET"
    printf '      %s%s%s\n' "$DIM" "$3" "$RESET"
}

show_menu() {
    printf '\n  %sWhat would you like to do?%s\n\n' "$BOLD" "$RESET"
    menu_item 1 "Install"  "Copy the config into ~/.config and set up defaults"
    menu_item 2 "Remove"   "Delete the installed hypr and quickshell configs"
    menu_item 3 "Quit"     "Leave the installer"
    printf '\n'
}

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
    xdg-desktop-portal-gtk
    hyprpolkitagent
    pavucontrol
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
    wf-recorder
    hyprpicker
    caffeine-ng
)

privileged() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    elif command -v sudo >/dev/null 2>&1; then
        sudo "$@"
    else
        err "Cannot run privileged command: sudo is not available."
        return 1
    fi
}

install_packages() {
    section "Packages"
    note "Installing ${#PACKAGES[@]} packages with pacman..."
    privileged pacman -S --needed --noconfirm "${PACKAGES[@]}"
    ok "Packages are up to date"
}

# Set the recommended default applications. Each entry is only applied when
# its desktop file is present, so skipping packages never leaves broken defaults.
set_mime_defaults() {
    if ! command -v xdg-mime >/dev/null 2>&1; then
        warn "xdg-mime not found; skipping MIME defaults."
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
            note "skip $desktop (not installed)"
            return 0
        fi
        xdg-mime default "$desktop" "$@"
        ok "default: $desktop -> $*"
    }

    section "Default applications"
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
    section "Services"
    note "Enabling session, fingerprint, Bluetooth and power-profiles (best effort)..."
    for service in fprintd.service bluetooth.service power-profiles-daemon.service NetworkManager.service; do
        if privileged systemctl enable --now "$service" >/dev/null 2>&1; then
            ok "enabled $service"
        else
            note "skip $service (not available or already enabled)"
        fi
    done

    # PipeWire user units and WirePlumber manage audio in the user session.
    if command -v systemctl >/dev/null 2>&1 && systemctl --user list-units --type socket --quiet >/dev/null 2>&1; then
        for unit in pipewire.socket pipewire-pulse.socket wireplumber.service; do
            if systemctl --user enable --now "$unit" >/dev/null 2>&1; then
                ok "enabled user $unit"
            else
                note "skip user $unit (not available)"
            fi
        done
    fi
}

backup_dir() {
    local target="$1"
    [ -e "$target" ] || return 0
    local saved="${target}.bak.$(date +%Y%m%d%H%M%S)"
    mv -- "$target" "$saved"
    ok "Backed up: $target -> $saved"
}

make_scripts_executable() {
    local dir="$1" count=0
    [ -d "$dir" ] || return 0
    while IFS= read -r -d '' script; do
        chmod +x -- "$script"
        count=$((count + 1))
    done < <(find "$dir" -type f \( -name '*.sh' -o -name '*.py' \) -print0)
    ok "Made $count helper script(s) executable in $dir"
}

install_config() {
    section "Install cyan1de"
    if [ ! -d "$SRC/hypr" ] || [ ! -d "$SRC/quickshell" ]; then
        err "Missing config source: $SRC"
        return 1
    fi

    local answer
    answer=$(ask "Install into ~/.config/hypr and ~/.config/quickshell?" "[y/N]")
    case "$answer" in
        y|Y|yes|YES) ;;
        *) note "Cancelled."; return 0 ;;
    esac

    note "Existing directories will be backed up before copying."
    answer=$(ask "Install required packages with pacman?" "[Y/n]")
    case "${answer:-y}" in
        n|N|no|NO)
            note "Skipping package installation."
            ;;
        *)
            if ! install_packages; then
                err "Package installation failed; config was not installed."
                return 1
            fi
            set_mime_defaults
            enable_services
            ;;
    esac

    section "Configuration"
    mkdir -p "$CONFIG_HOME"
    backup_dir "$CONFIG_HOME/hypr"
    backup_dir "$CONFIG_HOME/quickshell"
    cp -a -- "$SRC/hypr" "$CONFIG_HOME/hypr"
    cp -a -- "$SRC/quickshell" "$CONFIG_HOME/quickshell"

    # cp -a preserves the shipped mode bits, but enforce executability here so
    # every Quickshell helper works even if an archive/transfer dropped +x.
    make_scripts_executable "$CONFIG_HOME/quickshell"

    section "Done"
    ok "cyan1de is installed"
    note "Reload Hyprland or log out and back in."
}

remove_config() {
    section "Remove cyan1de"
    local answer
    answer=$(ask "Remove ~/.config/hypr and ~/.config/quickshell?" "[y/N]")
    case "$answer" in
        y|Y|yes|YES) ;;
        *) note "Cancelled."; return 0 ;;
    esac

    warn "This permanently deletes both config directories."
    rm -rf -- "$CONFIG_HOME/hypr" "$CONFIG_HOME/quickshell"
    ok "Removed cyan1de config directories."
}

show_banner

while true; do
    show_menu
    choice=$(ask "Choose an option" "[1-3]")
    case "$choice" in
        1|install)  install_config ;;
        2|remove)   remove_config ;;
        3|quit|q)   printf '\n  %sBye.%s\n\n' "$DIM" "$RESET"; exit 0 ;;
        *)          warn "Invalid choice. Please enter 1, 2 or 3." ;;
    esac
done
