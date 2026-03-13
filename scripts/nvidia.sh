#!/bin/bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/utils.sh"

check_sudo

# ── 启用 non-free 仓库 ────────────────────────────────────
log_section "启用 contrib / non-free / non-free-firmware 仓库"

# 检查 non-free（不含 non-free-firmware）是否已启用
# Debian 13 默认可能只有 non-free-firmware，NVIDIA 驱动需要 non-free
_nonfree_enabled() {
    # 旧格式 sources.list / .list：non-free 后跟空格或行尾（排除 non-free-firmware）
    grep -hE '^deb[[:space:]].*trixie' /etc/apt/sources.list \
        /etc/apt/sources.list.d/*.list 2>/dev/null \
        | grep -qE '(^|[[:space:]])non-free($|[[:space:]])' && return 0
    # DEB822 格式 .sources：Components 行含独立的 non-free 词
    grep -hE '^Components:' /etc/apt/sources.list.d/*.sources 2>/dev/null \
        | grep -qE '(^|[[:space:]])non-free($|[[:space:]])' && return 0
    return 1
}

if _nonfree_enabled; then
    log_info "non-free 仓库已启用，跳过"
else
    # 优先更新 DEB822 格式（Debian 13 默认）
    DEB822_FILE=$(grep -rlE '^Suites:.*trixie' /etc/apt/sources.list.d/*.sources 2>/dev/null | head -1) || true
    if [[ -n "$DEB822_FILE" ]]; then
        log_info "更新 DEB822 源文件：$DEB822_FILE"
        # 在 Components 行追加 contrib non-free non-free-firmware（避免重复）
        sudo sed -i -E \
            '/^Components:/{/ non-free /!{ / non-free$/!s/$/ contrib non-free non-free-firmware/}}' \
            "$DEB822_FILE"
        log_success "已在 $DEB822_FILE 中添加 contrib non-free non-free-firmware"
    elif [[ -s "/etc/apt/sources.list" ]] && grep -qE '^deb[[:space:]].*trixie' /etc/apt/sources.list; then
        sudo sed -i -E \
            '/^deb[[:space:]].*trixie/{/non-free-firmware/b; s/$/ contrib non-free non-free-firmware/}' \
            /etc/apt/sources.list
        log_success "已为 sources.list 中的 trixie 源行添加 contrib non-free non-free-firmware"
    else
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
# nvidia-open-kernel-dkms：Turing/Ampere/Ada 架构推荐（官方开源内核模块）
# nvidia-kernel-dkms：Maxwell/Pascal/Volta 等旧架构使用 proprietary 版本
log_section "安装 NVIDIA 驱动"
if apt-cache show nvidia-open-kernel-dkms &>/dev/null 2>&1; then
    log_info "检测到 nvidia-open-kernel-dkms 可用，使用开源内核模块（推荐 Turing+）"
    sudo apt install -y nvidia-open-kernel-dkms nvidia-driver
else
    log_info "使用 proprietary 内核模块"
    sudo apt install -y nvidia-kernel-dkms nvidia-driver
fi

# ── 为每个 6.6.x 内核显式触发 DKMS 编译 ──────────────────
log_section "为 6.6 内核编译 NVIDIA DKMS 模块"

# 兼容旧格式 "nvidia/xxx, ..." 和新格式 "nvidia/xxx: ..."
NVIDIA_VER=$(dkms status | grep -oP 'nvidia/\K[\d.]+' | head -1) || true
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

# ── 更新 initramfs ────────────────────────────────────────
# nouveau 由 nvidia-driver 安装时自动黑名单化（/etc/modprobe.d/nvidia.conf）
# 无需手动写入，更新 initramfs 使黑名单生效即可
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
