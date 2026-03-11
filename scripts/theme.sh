#!/bin/bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/utils.sh"

THEMES_DIR="$HOME/.local/share/themes-src"
mkdir -p "$THEMES_DIR"

log_section "MacTahoe GTK 主题"
git_clone_or_skip https://github.com/vinceliuice/MacTahoe-gtk-theme.git "$THEMES_DIR/MacTahoe-gtk-theme"
bash "$THEMES_DIR/MacTahoe-gtk-theme/install.sh" -l -b --silent-mode

log_section "MacTahoe 图标主题"
git_clone_or_skip https://github.com/vinceliuice/MacTahoe-icon-theme.git "$THEMES_DIR/MacTahoe-icon-theme"
bash "$THEMES_DIR/MacTahoe-icon-theme/install.sh"

log_section "WhiteSur 壁纸"
git_clone_or_skip https://github.com/vinceliuice/WhiteSur-wallpapers.git "$THEMES_DIR/WhiteSur-wallpapers"
bash "$THEMES_DIR/WhiteSur-wallpapers/install-wallpapers.sh"
sudo bash "$THEMES_DIR/WhiteSur-wallpapers/install-gnome-backgrounds.sh"

log_success "主题安装完成"
