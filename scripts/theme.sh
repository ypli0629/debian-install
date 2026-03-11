#!/bin/bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/utils.sh"

THEMES_DIR="$HOME/.local/share/themes-src"
mkdir -p "$THEMES_DIR"

log_section "WhiteSur GTK 主题"
git_clone_or_skip https://github.com/vinceliuice/WhiteSur-gtk-theme.git "$THEMES_DIR/WhiteSur-gtk-theme"
bash "$THEMES_DIR/WhiteSur-gtk-theme/install.sh" -l -N stable

log_section "WhiteSur 图标主题"
git_clone_or_skip https://github.com/vinceliuice/WhiteSur-icon-theme.git "$THEMES_DIR/WhiteSur-icon-theme"
bash "$THEMES_DIR/WhiteSur-icon-theme/install.sh" -b

log_section "WhiteSur 壁纸"
git_clone_or_skip https://github.com/vinceliuice/WhiteSur-wallpapers.git "$THEMES_DIR/WhiteSur-wallpapers"
bash "$THEMES_DIR/WhiteSur-wallpapers/install-wallpapers.sh"
sudo bash "$THEMES_DIR/WhiteSur-wallpapers/install-gnome-backgrounds.sh"

log_success "主题安装完成"
