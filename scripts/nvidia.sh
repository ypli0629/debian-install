#!/bin/bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/utils.sh"

check_sudo

# ── 启用 non-free 仓库 ────────────────────────────────────
log_section "启用 non-free 仓库"

# 检查所有源文件（含镜像）是否已有独立的 non-free 组件
_nonfree_enabled() {
    grep -rh '^deb ' /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null \
        | grep -vE '^#' \
        | grep -qE '[[:space:]]non-free([[:space:]]|$)'
}

NONFREE_LIST="/etc/apt/sources.list.d/nonfree.list"
if _nonfree_enabled; then
    log_info "non-free 已在现有源中启用，跳过"
    # 如果之前误写了 nonfree.list 导致重复，自动清除
    if [[ -f "$NONFREE_LIST" ]]; then
        sudo rm -f "$NONFREE_LIST"
        log_info "已删除重复的 $NONFREE_LIST"
    fi
elif [[ -f "$NONFREE_LIST" ]]; then
    log_info "non-free 源已存在（$NONFREE_LIST），跳过"
else
    sudo tee "$NONFREE_LIST" > /dev/null <<'EOF'
deb http://deb.debian.org/debian trixie main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security trixie-security main contrib non-free non-free-firmware
EOF
    log_success "已写入 $NONFREE_LIST"
fi

sudo apt update

# ── 安装 NVIDIA 驱动 ──────────────────────────────────────
# 使用 proprietary 内核模块（nvidia-open-kernel-dkms 与 mainline 内核兼容性差）
log_section "安装 NVIDIA 驱动"
if dpkg-query -W -f='${Status}' nvidia-driver 2>/dev/null | grep -q "install ok installed"; then
    log_info "NVIDIA 驱动已安装，跳过"
else
    sudo apt install -y nvidia-kernel-dkms nvidia-driver
    log_success "NVIDIA 驱动安装完成，请重启系统以加载驱动"
fi
