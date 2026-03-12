#!/bin/bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/utils.sh"

check_sudo

THEMES_DIR="$HOME/.local/share/themes-src"
mkdir -p "$THEMES_DIR"

log_section "MacTahoe GTK 主题"
git_clone_or_skip https://github.com/vinceliuice/MacTahoe-gtk-theme.git "$THEMES_DIR/MacTahoe-gtk-theme"
# 检查主题是否已安装（安装目录为 ~/.local/share/themes/MacTahoe*）
if ls -d "$HOME/.local/share/themes/MacTahoe"* &>/dev/null 2>&1; then
    log_info "MacTahoe GTK 主题已安装，跳过"
else
    bash "$THEMES_DIR/MacTahoe-gtk-theme/install.sh" -l -b --silent-mode
    log_success "MacTahoe GTK 主题安装完成"
fi

log_section "MacTahoe 图标主题"
git_clone_or_skip https://github.com/vinceliuice/MacTahoe-icon-theme.git "$THEMES_DIR/MacTahoe-icon-theme"
# 检查图标主题是否已安装（安装目录为 ~/.local/share/icons/MacTahoe*）
if ls -d "$HOME/.local/share/icons/MacTahoe"* &>/dev/null 2>&1; then
    log_info "MacTahoe 图标主题已安装，跳过"
else
    bash "$THEMES_DIR/MacTahoe-icon-theme/install.sh"
    log_success "MacTahoe 图标主题安装完成"
fi

log_section "WhiteSur 壁纸"
git_clone_or_skip https://github.com/vinceliuice/WhiteSur-wallpapers.git "$THEMES_DIR/WhiteSur-wallpapers"
# 检查壁纸是否已安装（安装目录为 ~/.local/share/wallpapers/WhiteSur*）
if ls -d "$HOME/.local/share/wallpapers/WhiteSur"* &>/dev/null 2>&1; then
    log_info "WhiteSur 壁纸已安装，跳过"
else
    bash "$THEMES_DIR/WhiteSur-wallpapers/install-wallpapers.sh"
    sudo bash "$THEMES_DIR/WhiteSur-wallpapers/install-gnome-backgrounds.sh"
    log_success "WhiteSur 壁纸安装完成"
fi

log_success "主题安装完成"
