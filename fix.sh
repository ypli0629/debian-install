#!/bin/bash
# 修复旧版 install.sh 遗留的 /etc/environment.d/ 环境变量不生效问题
# 适用于已运行过旧版 install.sh 的 Debian 13 系统

if [ -z "${BASH_VERSION:-}" ]; then
    echo "错误：请用 bash 运行：bash fix.sh" >&2
    exit 1
fi

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/utils.sh"
check_sudo

# ── brew PATH ────────────────────────────────────────────────────────────────
log_section "修复 brew PATH（/etc/environment.d → /etc/profile.d）"

BREW_BIN="/home/linuxbrew/.linuxbrew/bin/brew"

if [[ ! -x "$BREW_BIN" ]]; then
    log_info "未检测到 brew，跳过 brew 修复"
else
    # 1. 清理旧文件
    if [[ -f /etc/environment.d/brew.conf ]]; then
        sudo rm -f /etc/environment.d/brew.conf
        log_success "已删除 /etc/environment.d/brew.conf"
    fi

    # 2. 写入 /etc/profile.d/（login shell 通用：终端、SSH）
    if [[ ! -f /etc/profile.d/linuxbrew.sh ]]; then
        echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' \
            | sudo tee /etc/profile.d/linuxbrew.sh > /dev/null
        sudo chmod +x /etc/profile.d/linuxbrew.sh
        log_success "已写入 /etc/profile.d/linuxbrew.sh"
    else
        log_info "/etc/profile.d/linuxbrew.sh 已存在，跳过"
    fi

    # 3. 写入 ~/.zshrc（GNOME Terminal 默认是 non-login interactive shell）
    if ! grep -qF '# linuxbrew shellenv' ~/.zshrc 2>/dev/null; then
        printf '\n# linuxbrew shellenv\neval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"\n' \
            >> ~/.zshrc
        log_success "已写入 ~/.zshrc：brew shellenv"
    else
        log_info "~/.zshrc 中已有 brew shellenv，跳过"
    fi
fi

# ── fcitx5 IM 变量 ───────────────────────────────────────────────────────────
log_section "修复 fcitx5 环境变量（/etc/environment.d → /etc/environment）"

if ! dpkg-query -W fcitx5 2>/dev/null | grep -qv '^$'; then
    log_info "未检测到 fcitx5，跳过 fcitx5 修复"
else
    # 1. 清理旧文件
    if [[ -f /etc/environment.d/fcitx5.conf ]]; then
        sudo rm -f /etc/environment.d/fcitx5.conf
        log_success "已删除 /etc/environment.d/fcitx5.conf"
    fi

    # 2. 逐项写入 /etc/environment（PAM 读取，适用所有 session 类型）
    for _var in "INPUT_METHOD=fcitx" "GTK_IM_MODULE=fcitx" "QT_IM_MODULE=fcitx" "XMODIFIERS=@im=fcitx"; do
        _key="${_var%%=*}"
        if sudo grep -q "^${_key}=" /etc/environment 2>/dev/null; then
            log_info "${_key} 已存在于 /etc/environment，跳过"
        else
            echo "$_var" | sudo tee -a /etc/environment > /dev/null
            log_success "已写入 /etc/environment：$_var"
        fi
    done
    unset _var _key
fi

# ── /usr/sbin PATH ───────────────────────────────────────────────────────────
log_section "添加 /usr/sbin 到系统 PATH"

# /etc/profile.d/：login shell 通用
if [[ ! -f /etc/profile.d/sbin-path.sh ]]; then
    sudo tee /etc/profile.d/sbin-path.sh > /dev/null <<'EOF'
# Ensure /usr/local/sbin and /usr/sbin are in PATH for all users
for _sbin_dir in /usr/local/sbin /usr/sbin; do
    case ":${PATH}:" in
        *:"${_sbin_dir}":*) ;;
        *) export PATH="${PATH}:${_sbin_dir}" ;;
    esac
done
unset _sbin_dir
EOF
    sudo chmod +x /etc/profile.d/sbin-path.sh
    log_success "已写入 /etc/profile.d/sbin-path.sh"
else
    log_info "/etc/profile.d/sbin-path.sh 已存在，跳过"
fi

# ~/.zshrc：non-login interactive shell（GNOME Terminal）
if ! grep -qF '# sbin path' ~/.zshrc 2>/dev/null; then
    printf '\n# sbin path\nexport PATH="$PATH:/usr/local/sbin:/usr/sbin"\n' >> ~/.zshrc
    log_success "已写入 ~/.zshrc：sbin path"
else
    log_info "~/.zshrc 中已有 sbin path，跳过"
fi

# ── 完成 ─────────────────────────────────────────────────────────────────────
echo ""
log_success "修复完成，请重新登录（注销后重新登录）使配置生效"
log_info "验证方法："
log_info "  echo \$PATH           # 应包含 /home/linuxbrew/.linuxbrew/bin"
log_info "  echo \$GTK_IM_MODULE  # 应为 fcitx"
