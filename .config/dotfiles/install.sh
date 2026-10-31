#!/usr/bin/env bash
# archibald: one-command install of these dotfiles on Arch Linux.
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/segmentationf4u1t/archibald/main/.config/dotfiles/install.sh)
#
# Installs the packages, checks the dotfiles out into $HOME (files it would overwrite go to
# ~/.dotfiles-backup/<time>/), then does what files alone cannot: fzf-tab, the magma icon theme,
# bat and font caches, GNOME/Nemo settings, zsh as login shell, the greetd login screen.
# Safe to re-run: an existing checkout is fast-forwarded and everything is re-applied, so the
# same command updates an installed machine. GPU passthrough (gpu-setup/etap*.sh) is hardware
# specific and stays manual.
#
# Options: --no-greetd (keep the current display manager), --no-packages, -h
set -euo pipefail

REPO_URL=${ARCHIBALD_REPO:-https://github.com/segmentationf4u1t/archibald.git}
GIT_DIR=$HOME/.dotfiles
BACKUP=$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)
WITH_GREETD=1
WITH_PACKAGES=1

PACKAGES=(
    # desktop
    hyprland hyprpaper hyprlock hypridle hyprpolkitagent xdg-desktop-portal-hyprland quickshell
    kitty rofi dunst libnotify nemo pavucontrol
    # services the bar talks to
    networkmanager bluez bluez-utils blueman pipewire pipewire-pulse wireplumber playerctl brightnessctl
    # screenshots and clipboard history
    grim slurp wl-clipboard cliphist
    # fonts, icons, GTK theme
    ttf-jetbrains-mono-nerd noto-fonts papirus-icon-theme adw-gtk-theme
    # shell
    zsh zsh-autosuggestions zsh-syntax-highlighting eza bat fd fzf zoxide
    # this script, papirus-volcanic, the bar's native module
    git python gtk3 cmake gcc
)

# ---- output in the dark-volcanic palette ----
c() { printf '\e[38;2;%sm' "$1"; }
MAGMA=$(c "255;122;61"); SULFUR=$(c "243;194;79"); ASH=$(c "143;125;116"); FIRE=$(c "255;92;92"); TEXT=$(c "235;223;216"); R=$'\e[0m'
step() { printf '\n%s▸%s %s%s%s\n' "$MAGMA" "$R" "$TEXT" "$*" "$R"; }
info() { printf '  %s%s%s\n' "$ASH" "$*" "$R"; }
warn() { printf '  %s! %s%s\n' "$SULFUR" "$*" "$R"; }
die()  { printf '\n%s✗ %s%s\n' "$FIRE" "$*" "$R" >&2; exit 1; }

banner() {
    local hex
    printf '\n%s  archibald%s  %sArch · Hyprland · Quickshell · dark-volcanic%s\n  ' "$MAGMA" "$R" "$ASH" "$R"
    for hex in 100908 1A100E 261513 3A201C FF7A3D F3C24F FFA36B 8F7D74 4FC48A FF5C5C ebdfd8; do
        printf '\e[48;2;%d;%d;%dm   %s' "0x${hex:0:2}" "0x${hex:2:2}" "0x${hex:4:2}" "$R"
    done
    printf '\n'
}

usage() { sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0; }

for arg in "$@"; do
    case $arg in
        --no-greetd) WITH_GREETD=0 ;;
        --no-packages) WITH_PACKAGES=0 ;;
        -h|--help) usage ;;
        *) die "unknown option: $arg (see -h)" ;;
    esac
done

dot() { git --git-dir="$GIT_DIR" --work-tree="$HOME" -c core.excludesFile="$HOME/.config/dotfiles/ignore" "$@"; }

GSETTINGS=(
    "org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark'"
    "org.gnome.desktop.interface color-scheme 'prefer-dark'"
    "org.gnome.desktop.interface icon-theme 'Papirus-Dark-Volcanic'"
    "org.nemo.preferences default-folder-viewer 'list-view'"
    "org.nemo.preferences show-image-thumbnails 'always'"
    "org.nemo.preferences thumbnail-limit 'uint64 2147483648'"
    "org.nemo.preferences date-format 'iso'"
    "org.nemo.preferences show-full-path-titles true"
    "org.nemo.window-state start-with-menu-bar false"
    "org.cinnamon.desktop.default-applications.terminal exec 'kitty'"
)

# gsettings needs a session bus; outside a graphical session (TTY, ssh) all of them run in one
# private bus, with GIO_USE_VFS=local so gvfs is not started for nothing
apply_gsettings() {
    local script="" line
    for line in "${GSETTINGS[@]}"; do script+="gsettings set $line"$'\n'; done
    if [[ -n ${DBUS_SESSION_BUS_ADDRESS:-} ]]; then
        bash -ec "$script"
    else
        GIO_USE_VFS=local dbus-run-session -- bash -ec "$script" 2> >(grep -v '^dbus-daemon\[' >&2)
    fi
}

banner

# ---- checks ----
[[ -f /etc/arch-release ]] || die "this installer is for Arch Linux"
[[ $EUID -ne 0 ]] || die "run it as your user, not root (it uses sudo where needed)"
command -v sudo >/dev/null || die "sudo is required"
step "sudo"
sudo -v
while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done 2>/dev/null &

# ---- packages ----
if (( WITH_PACKAGES )); then
    step "packages"
    pkgs=("${PACKAGES[@]}")
    (( WITH_GREETD )) && pkgs+=(greetd)
    sudo pacman -S --needed --noconfirm "${pkgs[@]}"
fi
command -v git >/dev/null || die "git is missing (run without --no-packages)"

# ---- dotfiles ----
step "dotfiles → $HOME"
if [[ ! -d $GIT_DIR ]]; then
    git clone --quiet --bare "$REPO_URL" "$GIT_DIR"
    dot config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
    dot fetch --quiet origin
    branch=$(dot symbolic-ref --short HEAD)
    dot branch --quiet --set-upstream-to="origin/$branch" "$branch"
    # files that exist with other content would block the checkout: move them aside
    moved=0
    while IFS= read -r f; do
        [[ -e $HOME/$f || -L $HOME/$f ]] || continue
        [[ -f $HOME/$f && $(git hash-object "$HOME/$f") == $(dot rev-parse "HEAD:$f") ]] && continue
        mkdir -p "$BACKUP/$(dirname "$f")"
        mv "$HOME/$f" "$BACKUP/$f"
        moved=$((moved + 1))
    done < <(dot ls-tree -r --name-only HEAD)
    dot checkout --quiet
    info "checked out $(dot rev-parse --short HEAD)"
    (( moved )) && warn "$moved existing file(s) moved to $BACKUP"
else
    dot fetch --quiet origin
    if dot merge --ff-only --quiet "@{upstream}" 2>/dev/null; then
        info "up to date at $(dot rev-parse --short HEAD)"
    else
        warn "not fast-forwarded (local commits or uncommitted changes in the way): check 'dotfiles status'"
    fi
fi

# ---- what files alone cannot do ----
step "shell"
plugin=$HOME/.local/share/zsh/plugins/fzf-tab
if [[ -d $plugin/.git ]]; then
    git -C "$plugin" pull --quiet --ff-only || warn "fzf-tab not updated"
else
    git clone --quiet --depth 1 https://github.com/Aloxaf/fzf-tab "$plugin"
fi
info "fzf-tab"
if [[ $(getent passwd "$USER" | cut -d: -f7) != /usr/bin/zsh ]]; then
    sudo chsh -s /usr/bin/zsh "$USER" >/dev/null
    info "login shell → zsh"
fi

step "theme"
fc-cache -f "$HOME/.local/share/fonts" >/dev/null && info "font cache (Tabler icons for the bar)"
"$HOME/.local/bin/papirus-volcanic" >/dev/null && info "Papirus-Dark-Volcanic icons"
bat cache --build >/dev/null && info "bat theme"
apply_gsettings
info "GTK dark theme, icons, Nemo, Nemo's terminal"

step "bar"
qs=$HOME/.config/quickshell
cmake -S "$qs/native" -B "$qs/native/build" -DCMAKE_BUILD_TYPE=Release >/dev/null
cmake --build "$qs/native/build" >/dev/null
info "native module (GPU and process statistics)"

step "services"
systemctl --user daemon-reload 2>/dev/null || true
sudo systemctl enable --quiet bluetooth.service
info "bluetooth"
others=(systemd-networkd.service iwd.service connman.service dhcpcd.service)
if ! systemctl is-enabled --quiet NetworkManager.service && ! systemctl is-enabled --quiet "${others[@]}" 2>/dev/null; then
    sudo systemctl enable --quiet NetworkManager.service
    info "NetworkManager"
fi

if (( WITH_GREETD )); then
    step "login screen (greetd + Quickshell)"
    src=$HOME/gpu-setup/etc
    sudo install -d -m 755 /etc/greetd/quickshell
    sudo install -m 644 "$src/greetd/config.toml" "$src/greetd/hyprland.lua" /etc/greetd/
    sudo install -m 644 "$src/greetd/quickshell/"{Auth.qml,Greeter.qml,Theme.qml,wallpaper.png} /etc/greetd/quickshell/
    # the greeter offers the user who ran the installer
    sed "s/\(readonly property string defaultUser: \)\"[^\"]*\"/\1\"$USER\"/" "$src/greetd/quickshell/shell.qml" \
        | sudo tee /etc/greetd/quickshell/shell.qml >/dev/null
    sudo install -m 644 "$src/tmpfiles.d/greetd-greeter.conf" /etc/tmpfiles.d/
    sudo systemd-tmpfiles --create /etc/tmpfiles.d/greetd-greeter.conf
    dm=$(basename "$(readlink /etc/systemd/system/display-manager.service 2>/dev/null)" 2>/dev/null || true)
    if [[ $dm != greetd.service ]]; then
        [[ -n $dm && $dm != . ]] && sudo systemctl disable --quiet "$dm" && info "disabled $dm"
        sudo systemctl enable --quiet greetd.service
        info "greetd enabled (back: systemctl disable greetd && systemctl enable ${dm:-<your dm>})"
    else
        info "greetd already the display manager"
    fi
fi

printf '\n%s✓ done.%s %sReboot (or log out) to land on the new login screen.%s\n' "$MAGMA" "$R" "$TEXT" "$R"
printf '  %sUpdate later by running this again, or: ~/.config/dotfiles/install.sh%s\n\n' "$ASH" "$R"
