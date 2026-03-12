#!/bin/bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/utils.sh"

log_section "Flatpak 应用"

packages=(
    "com.calibre_ebook.calibre"
    "com.discordapp.Discord"
    "com.getpostman.Postman"
    "com.obsproject.Studio"
    "com.qq.QQ"
    "com.qq.QQmusic"
    "com.tencent.WeChat"
    "com.visualstudio.code"
    "io.github.shiftey.Desktop"
    "org.blender.Blender"
    "org.gimp.GIMP"
    "org.telegram.desktop"
    "com.termius.Termius"
    "io.typora.Typora"
    "net.xmind.XMind"
)

log_info "批量安装 ${#packages[@]} 个包..."
flatpak install flathub -y --noninteractive "${packages[@]}" \
    || log_error "部分 Flatpak 包安装失败，请手动重试"

log_success "Flatpak 安装完成"
