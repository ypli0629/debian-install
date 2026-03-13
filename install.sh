#!/bin/bash
# 去掉 -e，让单步失败不中断整体流程；保留 -uo pipefail 捕获变量未定义和管道错误

# 必须用 bash 运行，不兼容 sh/dash
if [ -z "${BASH_VERSION:-}" ]; then
    echo "错误：请用 bash 运行此脚本：bash install.sh" >&2
    exit 1
fi

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/utils.sh"

check_sudo
progress_init 17

# ── 系统更新 ──────────────────────────────────────────────
log_section "系统更新"
sudo apt update
sudo apt upgrade -y && sudo apt dist-upgrade -y
sudo apt install -y zsh git curl wget ca-certificates flatpak gnome-software-plugin-flatpak \
    build-essential cmake pkg-config \
    fonts-noto-cjk fonts-noto-cjk-extra \
    default-jdk ncurses-bin
progress_tick

# ── 目录 ─────────────────────────────────────────────────
log_section "创建目录"
mkdir -p ~/Desktop/{source,work,caffe,learn}
progress_tick

# ── Git ──────────────────────────────────────────────────
log_section "Git 全局配置"
if [[ -z "$(git config --global user.email 2>/dev/null)" ]]; then
    git config --global user.email "liyapeng0629@gmail.com"
    git config --global user.name "ypli0629"
else
    log_info "Git 全局账户已配置（$(git config --global user.name) / $(git config --global user.email)），跳过"
fi
git config --global credential.helper store
progress_tick

# ── Flatpak 源 ────────────────────────────────────────────
log_section "Flatpak 初始化"
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo --user
flatpak remote-modify flathub --url=https://mirrors.ustc.edu.cn/flathub --user
progress_tick

# ── AstroNvim ────────────────────────────────────────────
log_section "AstroNvim 配置"
git_clone_or_skip https://github.com/ypli0629/astronvim_config.git ~/.config/nvim \
    || record_failure "AstroNvim 配置克隆"
progress_tick

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
progress_tick

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
progress_tick

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
progress_tick

# ── SwitchHosts ──────────────────────────────────────────
log_section "SwitchHosts"
if command -v switchhosts &>/dev/null || dpkg-query -W -f='${Status}' switchhosts 2>/dev/null | grep -q "install ok installed"; then
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
progress_tick

# ── JetBrains Toolbox ─────────────────────────────────────
log_section "JetBrains Toolbox"
TOOLBOX_BIN="$HOME/.local/bin/jetbrains-toolbox"
if [[ -x "$TOOLBOX_BIN" ]]; then
    log_info "JetBrains Toolbox 已安装，跳过"
else
    TOOLBOX_URL=$(curl -fsSL \
        "https://data.services.jetbrains.com/products/releases?code=TBA&latest=true&type=release" \
        | grep -oP 'https://download\.jetbrains\.com/toolbox/jetbrains-toolbox-[^"]+\.tar\.gz' \
        | head -1) || TOOLBOX_URL=""
    if [[ -n "$TOOLBOX_URL" ]]; then
        if wget --timeout=60 -q -O /tmp/jetbrains-toolbox.tar.gz "$TOOLBOX_URL"; then
            mkdir -p "$HOME/.local/bin"
            tar -xzf /tmp/jetbrains-toolbox.tar.gz -C /tmp/
            find /tmp -maxdepth 2 -name "jetbrains-toolbox" -type f \
                | head -1 | xargs -I{} mv {} "$TOOLBOX_BIN"
            chmod +x "$TOOLBOX_BIN"
            rm -f /tmp/jetbrains-toolbox.tar.gz
            log_success "JetBrains Toolbox 已安装至 $TOOLBOX_BIN，首次运行请在桌面环境执行"
        else
            record_failure "JetBrains Toolbox" "下载失败"
        fi
    else
        record_failure "JetBrains Toolbox" "获取下载链接失败"
    fi
fi
progress_tick

# ── 子脚本 ────────────────────────────────────────────────
# nvidia.sh 需重启进入新内核后手动执行
log_section "执行子脚本"
bash "$SCRIPT_DIR/scripts/kernel.sh"   || record_failure "kernel.sh"
progress_tick
bash "$SCRIPT_DIR/scripts/brew.sh"     || record_failure "brew.sh"
progress_tick
bash "$SCRIPT_DIR/scripts/zsh.sh"      || record_failure "zsh.sh"
progress_tick
bash "$SCRIPT_DIR/scripts/fcitx.sh"    || record_failure "fcitx.sh"
progress_tick
bash "$SCRIPT_DIR/scripts/gnome.sh"    || record_failure "gnome.sh"
progress_tick
bash "$SCRIPT_DIR/scripts/theme.sh"    || record_failure "theme.sh"
progress_tick
bash "$SCRIPT_DIR/scripts/flatpak.sh"  || record_failure "flatpak.sh"
progress_tick

# ── 安装报告 ──────────────────────────────────────────────
log_section "安装报告"
print_report
log_success "完成！请重启系统以使所有配置生效。"
echo ""
log_info "后续手动步骤："
log_info "  1. 重启进入 mainline 6.6 内核"
log_info "  2. bash scripts/nvidia.sh   # 安装 NVIDIA 驱动"
