## Install
 
```bash
git clone <your-repo-url> ~/dotfiles
cd ~/dotfiles
chmod +x install.sh
./install.sh
```
 
The script:
 
1. Checks that you are on Fedora.
2. Checks every required package with `rpm -q` and installs only the missing ones with `dnf`. If `hyprland` is not in your repos it enables the `solopasha/hyprland` COPR.
3. Enables `power-profiles-daemon`, `NetworkManager` and `bluetooth`.
4. Symlinks `hypr`, `waybar` and `kitty` into `~/.config`, and everything in `bin/` into `~/.local/bin`. Existing files are moved to `*.bak.<timestamp>`, nothing is deleted.
5. Verifies the Python GTK bindings, the available power profiles, the corner image and the wallpaper path, and prints a warning for anything that is off.
Options:
 
```bash
./install.sh --check          # only report what is missing, change nothing
./install.sh --no-packages    # only link configs and scripts
./install.sh --no-link        # only install packages
```
 
After it finishes, log out and choose Hyprland, or inside Hyprland run:
 
```bash
hyprctl reload; pkill waybar; waybar &
```
 
## Manual install
 
```bash
sudo dnf install hyprland waybar kitty swaybg \
  grim slurp wl-clipboard brightnessctl \
  power-profiles-daemon pulseaudio-utils \
  NetworkManager nm-connection-editor blueman \
  gtk3 gtk-layer-shell python3-gobject python3-cairo \
  jetbrains-mono-fonts
 
sudo systemctl enable --now power-profiles-daemon NetworkManager bluetooth
 
ln -s ~/dotfiles/hypr   ~/.config/hypr
ln -s ~/dotfiles/waybar ~/.config/waybar
ln -s ~/dotfiles/kitty  ~/.config/kitty
mkdir -p ~/.local/bin
ln -s ~/dotfiles/bin/* ~/.local/bin/
```
 
Make sure `~/.local/bin` is in your `PATH`.
 
## Customize
 
- **Wallpaper:** edit the `swaybg -i ...` line in `hypr/hyprland.conf`. Use a path inside the repo if you want it to survive a fresh install, for example `~/dotfiles/hypr/wallpaper.jpg`.
- **Corner image:** replace `hypr/corner-image.png` (`.jpg`, `.jpeg` and `.webp` also work), then `pkill -f corner-image; corner-image &`. Size, margin and border colour are the variables at the top of `bin/corner-image`.
- **Calendar background:** put `calendar-bg.png` (or `.jpg`, `.jpeg`, `.webp`) in `waybar/`. Without it the calendar uses the solid `#1e1e1e` background.
- **Palette:** background `#1e1e1e`, text `#d4d4d4`, accent red `#a55555`, border `#3a3a3a`.
## Troubleshooting
 
- **Calendar or corner image does not appear:** run `calendar-popup` or `corner-image` from a terminal to see the error. The usual cause is a missing `gtk-layer-shell` or `python3-gobject`.
- **Battery button does nothing:** check `powerprofilesctl get`. If it fails, `power-profiles-daemon` is not running. Other tools like TLP or auto-cpufreq conflict with it, so disable them.
- **No `performance` profile:** some hardware only exposes saver and balanced. The button then cycles between those two.
- **Waybar shows no custom battery module:** check that `~/.local/bin/battery-mode` exists, is executable and starts with `#!/usr/bin/env bash`.
- **Wallpaper is black:** the path in the `swaybg` line does not exist on this machine.

