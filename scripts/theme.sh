#!/bin/bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/utils.sh"

check_sudo

THEMES_DIR="$HOME/.local/share/themes-src"
mkdir -p "$THEMES_DIR"

log_section "WhiteSur GTK 主题"
git_clone_or_skip https://github.com/vinceliuice/WhiteSur-gtk-theme.git "$THEMES_DIR/WhiteSur-gtk-theme"
if ls -d "$HOME/.local/share/themes/WhiteSur"* &>/dev/null 2>&1; then
    log_info "WhiteSur GTK 主题已安装，跳过"
else
    bash "$THEMES_DIR/WhiteSur-gtk-theme/install.sh"
    log_success "WhiteSur GTK 主题安装完成"
fi

log_section "WhiteSur 图标主题"
git_clone_or_skip https://github.com/vinceliuice/WhiteSur-icon-theme.git "$THEMES_DIR/WhiteSur-icon-theme"
if ls -d "$HOME/.local/share/icons/WhiteSur"* &>/dev/null 2>&1; then
    log_info "WhiteSur 图标主题已安装，跳过"
else
    bash "$THEMES_DIR/WhiteSur-icon-theme/install.sh"
    log_success "WhiteSur 图标主题安装完成"
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
