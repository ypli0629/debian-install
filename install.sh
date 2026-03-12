#!/bin/bash
# 去掉 -e，让单步失败不中断整体流程；保留 -uo pipefail 捕获变量未定义和管道错误
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/utils.sh"

check_sudo

# ── 系统更新 ──────────────────────────────────────────────
log_section "系统更新"
sudo apt update
sudo apt upgrade -y && sudo apt dist-upgrade -y
sudo apt install -y zsh git curl wget ca-certificates flatpak gnome-software-plugin-flatpak \
    build-essential cmake pkg-config \
    fonts-noto-cjk fonts-noto-cjk-extra \
    timeshift

# ── 目录 ─────────────────────────────────────────────────
log_section "创建目录"
mkdir -p ~/Desktop/{source,work,caffe,learn}

# ── Git ──────────────────────────────────────────────────
log_section "Git 全局配置"
if [[ -z "$(git config --global user.email 2>/dev/null)" ]]; then
    git config --global user.email "liyapeng0629@gmail.com"
    git config --global user.name "ypli0629"
else
    log_info "Git 全局账户已配置（$(git config --global user.name) / $(git config --global user.email)），跳过"
fi
git config --global credential.helper store

# ── Flatpak 源 ────────────────────────────────────────────
log_section "Flatpak 初始化"
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo --user
# flatpak remote-modify flathub --url=https://mirror.sjtu.edu.cn/flathub --user

# ── AstroNvim ────────────────────────────────────────────
log_section "AstroNvim 配置"
git_clone_or_skip https://github.com/ypli0629/astronvim_config.git ~/.config/nvim \
    || record_failure "AstroNvim 配置克隆"

# ── Docker Engine ─────────────────────────────────────────
log_section "Docker Engine"
if dpkg-query -W -f='${Status}' docker-ce 2>/dev/null | grep -q "install ok installed"; then
    log_info "Docker Engine 已安装，跳过"
else
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
        | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo usermod -aG docker "$USER"
fi

# ── Docker Desktop ────────────────────────────────────────
log_section "Docker Desktop"
if dpkg-query -W -f='${Status}' docker-desktop 2>/dev/null | grep -q "install ok installed"; then
    log_info "Docker Desktop 已安装，跳过"
else
    if gh_wget "https://desktop.docker.com/linux/main/amd64/docker-desktop-amd64.deb" \
            /tmp/docker-desktop-amd64.deb; then
        sudo apt install -y /tmp/docker-desktop-amd64.deb \
            && log_success "Docker Desktop 安装完成" \
            || record_failure "Docker Desktop" "apt install 失败"
    else
        record_failure "Docker Desktop" "下载失败"
    fi
fi

# ── Clash Verge Rev ──────────────────────────────────────
log_section "Clash Verge Rev"
if dpkg-query -W -f='${Status}' clash-verge 2>/dev/null | grep -q "install ok installed"; then
    log_info "Clash Verge 已安装，跳过"
else
    CLASH_VERGE_URL=$(gh_curl "https://api.github.com/repos/clash-verge-rev/clash-verge-rev/releases/latest" \
        | grep -oP '"browser_download_url":\s*"\K[^"]+amd64\.deb' | head -1) || CLASH_VERGE_URL=""
    if [[ -n "$CLASH_VERGE_URL" ]]; then
        if gh_wget "$CLASH_VERGE_URL" /tmp/clash-verge.deb; then
            sudo apt install -y /tmp/clash-verge.deb \
                && log_success "Clash Verge 安装完成" \
                || record_failure "Clash Verge Rev" "apt install 失败"
        else
            record_failure "Clash Verge Rev" "下载失败"
        fi
    else
        record_failure "Clash Verge Rev" "获取 GitHub Release 链接失败"
    fi
fi

# ── SwitchHosts ──────────────────────────────────────────
log_section "SwitchHosts"
if command -v switchhosts &>/dev/null || dpkg -l switchhosts &>/dev/null 2>&1; then
    log_info "SwitchHosts 已安装，跳过"
else
    SWITCHHOSTS_URL=$(gh_curl "https://api.github.com/repos/oldj/SwitchHosts/releases/latest" \
        | grep -oP '"browser_download_url":\s*"\K[^"]+linux_amd64[^"]+\.deb' | head -1) || SWITCHHOSTS_URL=""
    if [[ -n "$SWITCHHOSTS_URL" ]]; then
        if gh_wget "$SWITCHHOSTS_URL" /tmp/switchhosts.deb; then
            sudo apt install -y /tmp/switchhosts.deb \
                && log_success "SwitchHosts 安装完成" \
                || record_failure "SwitchHosts" "apt install 失败"
        else
            record_failure "SwitchHosts" "下载失败"
        fi
    else
        record_failure "SwitchHosts" "获取 GitHub Release 链接失败"
    fi
fi

# ── 子脚本 ────────────────────────────────────────────────
log_section "执行子脚本"
bash "$SCRIPT_DIR/scripts/kernel.sh"   || record_failure "kernel.sh"
bash "$SCRIPT_DIR/scripts/nvidia.sh"   || record_failure "nvidia.sh"
bash "$SCRIPT_DIR/scripts/brew.sh"     || record_failure "brew.sh"
bash "$SCRIPT_DIR/scripts/zsh.sh"      || record_failure "zsh.sh"
bash "$SCRIPT_DIR/scripts/fcitx.sh"    || record_failure "fcitx.sh"
bash "$SCRIPT_DIR/scripts/gnome.sh"    || record_failure "gnome.sh"
bash "$SCRIPT_DIR/scripts/theme.sh"    || record_failure "theme.sh"
bash "$SCRIPT_DIR/scripts/flatpak.sh"  || record_failure "flatpak.sh"

# ── 安装报告 ──────────────────────────────────────────────
log_section "安装报告"
print_report
log_success "完成！请重启系统以使所有配置生效。"
