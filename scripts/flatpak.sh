#!/bin/bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/utils.sh"

check_sudo

log_section "Flatpak 应用"

packages=(
    "com.calibre_ebook.calibre"
    "io.dbeaver.DBeaverCommunity"
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
# 优先使用与 install.sh 一致的 --user flathub；仅有系统级 remote 时回退，保证单独运行也可用
FLATPAK_SCOPE="--user"
if ! flatpak remotes --user 2>/dev/null | awk '$1 == "flathub" { found=1 } END { exit !found }'; then
    log_info "未检测到用户级 flathub，改用系统级 remote"
    FLATPAK_SCOPE="--system"
fi
if flatpak install "$FLATPAK_SCOPE" flathub -y --noninteractive "${packages[@]}"; then
    log_success "Flatpak 安装完成"
else
    record_failure "flatpak.sh" "部分包安装失败"
fi

finish || exit 1
