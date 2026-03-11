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

for package in "${packages[@]}"; do
    log_info "安装：$package"
    flatpak install flathub "$package" -y --noninteractive || log_error "跳过失败的包：$package"
done

log_success "Flatpak 安装完成"
