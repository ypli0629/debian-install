#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/utils.sh"

check_sudo

# ── 系统更新 ──────────────────────────────────────────────
log_section "系统更新"
sudo apt update
sudo apt upgrade -y && sudo apt dist-upgrade -y
sudo apt install -y zsh git curl wget ca-certificates flatpak gnome-software-plugin-flatpak

# ── 目录 ─────────────────────────────────────────────────
log_section "创建目录"
mkdir -p ~/Desktop/{source,work,caffe,learn}

# ── Git ──────────────────────────────────────────────────
log_section "Git 全局配置"
git config --global user.email "liyapeng0629@gmail.com"
git config --global user.name "ypli0629"
git config --global credential.helper store

# ── Flatpak 源 ────────────────────────────────────────────
log_section "Flatpak 初始化"
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo --user
# flatpak remote-modify flathub --url=https://mirror.sjtu.edu.cn/flathub --user

# ── AstroNvim ────────────────────────────────────────────
log_section "AstroNvim 配置"
git_clone_or_skip https://github.com/ypli0629/astronvim_config.git ~/.config/nvim

# ── Docker ───────────────────────────────────────────────
log_section "Docker Engine"
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

log_section "Docker Desktop"
wget -O /tmp/docker-desktop-amd64.deb https://desktop.docker.com/linux/main/amd64/docker-desktop-amd64.deb
sudo apt install -y /tmp/docker-desktop-amd64.deb

# ── Clash Verge Rev ──────────────────────────────────────
log_section "Clash Verge Rev"
wget -O /tmp/clash-verge.deb https://github.com/clash-verge-rev/clash-verge-rev/releases/download/v2.2.3/Clash.Verge_2.2.3_amd64.deb
sudo apt install -y /tmp/clash-verge.deb

# ── SwitchHosts ──────────────────────────────────────────
log_section "SwitchHosts"
wget -O /tmp/switchhosts.deb https://github.com/oldj/SwitchHosts/releases/download/v4.2.0-beta/SwitchHosts_linux_amd64_4.2.0.6105.deb
sudo apt install -y /tmp/switchhosts.deb

# ── 子脚本 ────────────────────────────────────────────────
log_section "执行子脚本"
bash "$SCRIPT_DIR/scripts/kernel.sh"
bash "$SCRIPT_DIR/scripts/brew.sh"
bash "$SCRIPT_DIR/scripts/zsh.sh"
bash "$SCRIPT_DIR/scripts/fcitx.sh"
bash "$SCRIPT_DIR/scripts/gnome.sh"
bash "$SCRIPT_DIR/scripts/theme.sh"
bash "$SCRIPT_DIR/scripts/flatpak.sh"

log_success "全部完成！请重启系统以使所有配置生效。"
