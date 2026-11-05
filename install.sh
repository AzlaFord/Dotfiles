#!/usr/bin/env bash
# Dotfiles installer for Fedora + Hyprland.
# Usage: ./install.sh [--check] [--no-packages] [--no-link]
#   --check         only report what is missing, change nothing
#   --no-packages   skip package installation and service setup
#   --no-link       skip symlinking configs and scripts
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
BIN="$HOME/.local/bin"

CHECK_ONLY=0
DO_PACKAGES=1
DO_LINKS=1
for arg in "$@"; do
  case "$arg" in
    --check)        CHECK_ONLY=1 ;;
    --no-packages)  DO_PACKAGES=0 ;;
    --no-link)      DO_LINKS=0 ;;
    -h|--help)      sed -n '2,6p' "$0"; exit 0 ;;
    *)              echo "Unknown option: $arg"; exit 1 ;;
  esac
done

ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }
err()  { printf '  \033[31m✗\033[0m %s\n' "$*"; }
step() { printf '\n\033[1m%s\033[0m\n' "$*"; }

# ---------------------------------------------------------------- packages
PACKAGES=(
  # desktop
  waybar kitty swaybg
  # screenshots, clipboard, brightness
  grim slurp wl-clipboard brightnessctl
  # waybar modules: power mode, volume, network, bluetooth
  pulseaudio-utils
  NetworkManager nm-connection-editor blueman
  # calendar popup and corner image (python + gtk-layer-shell)
  gtk3 gtk-layer-shell python3-gobject python3-cairo
  # fonts
  jetbrains-mono-fonts
)
# nice to have, a failure here is not fatal
OPTIONAL_PACKAGES=( cascadia-mono-nf-fonts cascadia-code-nf-fonts )

SERVICES=( power-profiles-daemon NetworkManager bluetooth )

step "Checking system"
. /etc/os-release
if [ "${ID:-}" != "fedora" ]; then
  err "This script targets Fedora (found: ${PRETTY_NAME:-unknown})."
  err "Install the packages from the README manually, then run: ./install.sh --no-packages"
  exit 1
fi
ok "${PRETTY_NAME}"

if [ "$DO_PACKAGES" = 1 ]; then
  step "Checking packages"
  missing=()
  for p in "${PACKAGES[@]}"; do
    if rpm -q "$p" &>/dev/null; then
      ok "$p"
    else
      warn "$p is missing"
      missing+=("$p")
    fi
  done

  if [ "$CHECK_ONLY" = 0 ] && [ ${#missing[@]} -gt 0 ]; then
    step "Installing ${#missing[@]} missing package(s)"
    # hyprland is not in every Fedora release, fall back to the COPR
    if [[ " ${missing[*]} " == *" hyprland "* ]] && ! dnf -q list --available hyprland &>/dev/null; then
      warn "hyprland not found in enabled repos, enabling COPR solopasha/hyprland"
      sudo dnf install -y dnf-plugins-core
      sudo dnf copr enable -y solopasha/hyprland
    fi
    sudo dnf install -y "${missing[@]}"
  fi

  step "Optional packages"
  for p in "${OPTIONAL_PACKAGES[@]}"; do
    if rpm -q "$p" &>/dev/null; then
      ok "$p"
    elif [ "$CHECK_ONLY" = 1 ]; then
      warn "$p is not installed (optional)"
    else
      sudo dnf install -y "$p" &>/dev/null && ok "$p installed" \
        || warn "$p not available, falling back to JetBrainsMono"
    fi
  done

  step "Services"
  for svc in "${SERVICES[@]}"; do
    if ! systemctl cat "$svc.service" &>/dev/null; then
      warn "$svc.service not found"
    elif systemctl is-enabled --quiet "$svc" && systemctl is-active --quiet "$svc"; then
      ok "$svc is enabled and running"
    elif [ "$CHECK_ONLY" = 1 ]; then
      warn "$svc is not enabled/running"
    else
      sudo systemctl enable --now "$svc" && ok "$svc enabled"
    fi
  done
fi

# ---------------------------------------------------------------- symlinks
link() {
  local src="$1" dst="$2"
  if [ -L "$dst" ] && [ "$(readlink -f "$dst")" = "$(readlink -f "$src")" ]; then
    ok "$dst (already linked)"
    return
  fi
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    local bak="$dst.bak.$(date +%Y%m%d-%H%M%S)"
    mv "$dst" "$bak"
    warn "backed up existing $dst -> $bak"
  fi
  mkdir -p "$(dirname "$dst")"
  ln -s "$src" "$dst"
  ok "$dst -> $src"
}

if [ "$DO_LINKS" = 1 ] && [ "$CHECK_ONLY" = 0 ]; then
  step "Linking config folders"
  for dir in hypr waybar kitty; do
    if [ -d "$DOTFILES/$dir" ]; then
      link "$DOTFILES/$dir" "$CONFIG/$dir"
    else
      warn "$DOTFILES/$dir not found, skipped"
    fi
  done

  step "Linking scripts to ~/.local/bin"
  mkdir -p "$BIN"
  for f in "$DOTFILES"/bin/*; do
    [ -f "$f" ] || continue
    chmod +x "$f"
    link "$f" "$BIN/$(basename "$f")"
  done
  chmod +x "$DOTFILES"/waybar/scripts/*.sh 2>/dev/null || true

  case ":$PATH:" in
    *":$BIN:"*) ok "~/.local/bin is in PATH" ;;
    *) warn "~/.local/bin is not in PATH. Add this to ~/.bashrc:  export PATH=\"\$HOME/.local/bin:\$PATH\"" ;;
  esac
fi

# ---------------------------------------------------------------- checks
step "Verifying"
if LD_PRELOAD=/usr/lib64/libgtk-layer-shell.so.0 python3 -c '
import gi
gi.require_version("Gtk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
from gi.repository import Gtk, GtkLayerShell
import cairo' &>/dev/null; then
  ok "Python GTK / gtk-layer-shell bindings work"
else
  err "Python GTK / gtk-layer-shell bindings are broken (calendar popup and corner image need them)"
fi

if command -v powerprofilesctl &>/dev/null && powerprofilesctl list 2>/dev/null | grep -q performance; then
  ok "power profiles: saver / balanced / performance available"
else
  warn "no 'performance' power profile on this machine, the battery button will cycle only the available ones"
fi

if ls "$CONFIG"/hypr/corner-image.* &>/dev/null; then
  ok "corner image found"
else
  warn "no ~/.config/hypr/corner-image.(png|jpg|jpeg|webp), the corner image will not start"
fi

wall="$(grep -oP 'swaybg -i \K\S+' "$DOTFILES/hypr/hyprland.conf" 2>/dev/null | head -n1 || true)"
if [ -n "$wall" ] && [ ! -f "$wall" ]; then
  warn "wallpaper $wall does not exist, edit the swaybg line in hypr/hyprland.conf"
fi

step "Done"
echo "  Log out and pick Hyprland at the login screen, or if already inside it run:"
echo "    hyprctl reload; pkill waybar; waybar &"
