#!/bin/bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/utils.sh"

check_sudo

# ── 启用 non-free 仓库 ────────────────────────────────────
log_section "启用 contrib / non-free / non-free-firmware 仓库"

# 同时检查 sources.list 和 sources.list.d/ 下的所有文件（含 DEB822 格式的 .sources）
_nonfree_enabled() {
    grep -qE '^deb[[:space:]].*trixie.*non-free-firmware' /etc/apt/sources.list 2>/dev/null && return 0
    grep -rlE 'trixie.*non-free-firmware' /etc/apt/sources.list.d/ 2>/dev/null | grep -q . && return 0
    # DEB822 格式：Components 行包含 non-free-firmware
    grep -rlE '^Components:.*non-free-firmware' /etc/apt/sources.list.d/ 2>/dev/null | grep -q . && return 0
    return 1
}

if _nonfree_enabled; then
    log_info "non-free 仓库已启用，跳过"
else
    SOURCES_FILE="/etc/apt/sources.list"
    if [[ -s "$SOURCES_FILE" ]] && grep -qE '^deb[[:space:]].*trixie' "$SOURCES_FILE"; then
        sudo sed -i -E '/^deb[[:space:]].*trixie/{/non-free-firmware/b; s/$/ contrib non-free non-free-firmware/}' "$SOURCES_FILE"
        log_success "已为 sources.list 中的 trixie 源行添加 contrib non-free non-free-firmware"
    else
        log_info "sources.list 中未找到 trixie 行，尝试写入 sources.list.d/nonfree.list"
        echo "deb http://deb.debian.org/debian trixie main contrib non-free non-free-firmware" \
            | sudo tee /etc/apt/sources.list.d/nonfree.list > /dev/null
        log_success "已写入 /etc/apt/sources.list.d/nonfree.list"
    fi
fi

sudo apt update

# ── 检查所有已安装的 6.6.x mainline 内核 headers ─────────
log_section "检查 6.6 内核头文件"

# 找出 /usr/src 下所有 6.6.x mainline headers 目录
mapfile -t MAINLINE_KERNELS < <(ls -1d /usr/src/linux-headers-6.6.*-generic 2>/dev/null | sed 's|/usr/src/linux-headers-||')

if [[ ${#MAINLINE_KERNELS[@]} -eq 0 ]]; then
    log_error "未找到 6.6.x mainline 内核头文件，请先运行 kernel.sh" fatal
fi

for k in "${MAINLINE_KERNELS[@]}"; do
    log_info "找到 mainline 内核头文件：$k"
done

# ── 检测 GPU（nvidia-detect 为可选包，trixie 中可能不存在）──
log_section "检测 NVIDIA GPU"
if apt-cache show nvidia-detect &>/dev/null 2>&1; then
    sudo apt install -y nvidia-detect
    DETECT_OUT=$(nvidia-detect 2>&1) || true
    log_info "$DETECT_OUT"
else
    log_info "nvidia-detect 在当前仓库中不可用，跳过 GPU 检测，继续安装驱动"
fi

# ── 安装驱动 ──────────────────────────────────────────────
log_section "安装 NVIDIA 驱动（proprietary + DKMS）"
sudo apt install -y nvidia-kernel-dkms nvidia-driver

# ── 为每个 6.6.x 内核显式触发 DKMS 编译 ──────────────────
log_section "为 6.6 内核编译 NVIDIA DKMS 模块"

# 兼容旧格式 "nvidia/xxx, ..." 和新格式 "nvidia/xxx: ..."
NVIDIA_VER=$(dkms status | grep -oP 'nvidia/\K[\d.]+' | head -1)
[[ -z "$NVIDIA_VER" ]] && log_error "无法获取 nvidia DKMS 版本" fatal
log_info "NVIDIA DKMS 版本：$NVIDIA_VER"

for KERNEL_VER in "${MAINLINE_KERNELS[@]}"; do
    # 检查该内核版本的模块是否已编译安装，避免每次重跑都耗时重新编译
    if dkms status "nvidia/${NVIDIA_VER}" -k "${KERNEL_VER}" 2>/dev/null | grep -q "installed"; then
        log_info "nvidia/${NVIDIA_VER} @ ${KERNEL_VER} 已安装，跳过编译"
        continue
    fi
    log_info "编译 nvidia/${NVIDIA_VER} for ${KERNEL_VER}"
    sudo dkms install "nvidia/${NVIDIA_VER}" -k "${KERNEL_VER}" --force || \
        log_error "DKMS 编译失败：${KERNEL_VER}，请检查日志 /var/lib/dkms/nvidia/${NVIDIA_VER}/build/make.log" fatal
    log_success "编译成功：${KERNEL_VER}"
done

# ── 屏蔽 nouveau ──────────────────────────────────────────
log_section "屏蔽 nouveau 驱动"
BLACKLIST_FILE="/etc/modprobe.d/blacklist-nouveau.conf"
if [[ ! -f "$BLACKLIST_FILE" ]]; then
    sudo tee "$BLACKLIST_FILE" > /dev/null <<'EOF'
blacklist nouveau
options nouveau modeset=0
EOF
    log_success "已写入 $BLACKLIST_FILE"
else
    log_info "nouveau 已屏蔽，跳过"
fi

# ── 更新 initramfs ────────────────────────────────────────
log_section "更新 initramfs"
sudo update-initramfs -u -k all
log_success "initramfs 已更新"

# ── 验证 ─────────────────────────────────────────────────
log_section "验证 DKMS 状态"
for KERNEL_VER in "${MAINLINE_KERNELS[@]}"; do
    STATUS=$(dkms status "nvidia/${NVIDIA_VER}" -k "${KERNEL_VER}" 2>/dev/null || true)
    if echo "$STATUS" | grep -q "installed"; then
        log_success "nvidia/${NVIDIA_VER} @ ${KERNEL_VER}：installed"
    else
        log_error "nvidia/${NVIDIA_VER} @ ${KERNEL_VER}：未就绪，状态：$STATUS" fatal
    fi
done

log_success "NVIDIA 驱动安装完成，请重启系统以加载驱动"
