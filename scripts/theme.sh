#!/bin/bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/utils.sh"

check_sudo

THEMES_DIR="$HOME/.local/share/themes-src"
mkdir -p "$THEMES_DIR"

log_section "安装主题构建依赖"
if sudo apt-get install -y sassc optipng; then
    log_success "主题构建依赖安装完成"
else
    record_failure "主题构建依赖" "sassc/optipng 安装失败"
fi

log_section "WhiteSur GTK 主题"
if ! git_clone_or_skip https://github.com/vinceliuice/WhiteSur-gtk-theme.git "$THEMES_DIR/WhiteSur-gtk-theme"; then
    record_failure "WhiteSur GTK 主题" "克隆失败或目标目录非 git 仓库"
elif ls -d "$HOME/.local/share/themes/WhiteSur"* &>/dev/null 2>&1 \
    || ls -d "$HOME/.themes/WhiteSur"* &>/dev/null 2>&1; then
    log_info "WhiteSur GTK 主题已安装，跳过"
else
    if bash "$THEMES_DIR/WhiteSur-gtk-theme/install.sh"; then
        log_success "WhiteSur GTK 主题安装完成"
    else
        record_failure "WhiteSur GTK 主题" "install.sh 执行失败"
    fi
fi

log_section "WhiteSur 图标主题"
if ! git_clone_or_skip https://github.com/vinceliuice/WhiteSur-icon-theme.git "$THEMES_DIR/WhiteSur-icon-theme"; then
    record_failure "WhiteSur 图标主题" "克隆失败或目标目录非 git 仓库"
elif ls -d "$HOME/.local/share/icons/WhiteSur"* &>/dev/null 2>&1 \
    || ls -d "$HOME/.icons/WhiteSur"* &>/dev/null 2>&1; then
    log_info "WhiteSur 图标主题已安装，跳过"
else
    if bash "$THEMES_DIR/WhiteSur-icon-theme/install.sh"; then
        log_success "WhiteSur 图标主题安装完成"
    else
        record_failure "WhiteSur 图标主题" "install.sh 执行失败"
    fi
fi

log_section "WhiteSur 壁纸"
if ! git_clone_or_skip https://github.com/vinceliuice/WhiteSur-wallpapers.git "$THEMES_DIR/WhiteSur-wallpapers"; then
    record_failure "WhiteSur 壁纸" "克隆失败或目标目录非 git 仓库"
# 检查壁纸是否已安装（安装目录为 ~/.local/share/wallpapers/WhiteSur*）
elif ls -d "$HOME/.local/share/wallpapers/WhiteSur"* &>/dev/null 2>&1; then
    log_info "WhiteSur 壁纸已安装，跳过"
else
    if bash "$THEMES_DIR/WhiteSur-wallpapers/install-wallpapers.sh" \
        && sudo bash "$THEMES_DIR/WhiteSur-wallpapers/install-gnome-backgrounds.sh"; then
        log_success "WhiteSur 壁纸安装完成"
    else
        record_failure "WhiteSur 壁纸" "安装脚本执行失败"
    fi
fi

log_success "主题安装完成"
finish || exit 1
