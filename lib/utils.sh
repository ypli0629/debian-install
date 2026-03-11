#!/bin/bash

# ── 颜色 ──────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# ── 日志 ──────────────────────────────────────────────────
log_section() { echo -e "\n${BOLD}${BLUE}══ $1 ══${NC}"; }
log_info()    { echo -e "${YELLOW}  → $1${NC}"; }
log_success() { echo -e "${GREEN}  ✓ $1${NC}"; }
log_error()   { echo -e "${RED}  ✗ $1${NC}" >&2; [[ "${2:-}" == "fatal" ]] && exit 1; }

# ── sudo 预热 ─────────────────────────────────────────────
check_sudo() {
    if ! sudo -v 2>/dev/null; then
        log_error "需要 sudo 权限" fatal
    fi
    # 保持 sudo 会话不过期
    ( while true; do sudo -v; sleep 50; done ) &
    SUDO_KEEP_ALIVE_PID=$!
    trap 'kill "$SUDO_KEEP_ALIVE_PID" 2>/dev/null' EXIT
}

# ── Git clone（已存在则跳过）──────────────────────────────
git_clone_or_skip() {
    local repo="$1"
    local dest="$2"
    if [[ -d "$dest/.git" ]]; then
        log_info "已存在，跳过：$dest"
    else
        git clone "$repo" "$dest"
    fi
}

# ── 安全追加 ~/.zshrc（避免重复写入）─────────────────────
append_zshrc_once() {
    local marker="$1"   # 用于判断是否已写入的标识字符串
    local content="$2"
    if ! grep -qF "$marker" ~/.zshrc 2>/dev/null; then
        printf '\n%s\n' "$content" >> ~/.zshrc
    else
        log_info "zshrc 中已存在：$marker，跳过"
    fi
}
