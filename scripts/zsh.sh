#!/bin/bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/utils.sh"

check_sudo

log_section "oh-my-zsh"

if [[ -d "$HOME/.oh-my-zsh" ]]; then
    log_info "oh-my-zsh 已安装，跳过"
else
    sh -c "$(gh_curl https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# --unattended 不会自动 chsh，需手动切换默认 shell
ZSH_BIN="$(command -v zsh 2>/dev/null || echo "")"
if [[ -n "$ZSH_BIN" && "$SHELL" != "$ZSH_BIN" ]]; then
    # 确保 zsh 在 /etc/shells 中
    grep -qF "$ZSH_BIN" /etc/shells || echo "$ZSH_BIN" | sudo tee -a /etc/shells > /dev/null
    sudo chsh -s "$ZSH_BIN" "$USER"
    log_success "默认 Shell 已切换为 $ZSH_BIN"
else
    log_info "默认 Shell 已是 zsh，跳过"
fi

log_section "zsh 插件"
git_clone_or_skip https://github.com/zsh-users/zsh-autosuggestions \
    "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
git_clone_or_skip https://github.com/zsh-users/zsh-syntax-highlighting \
    "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"

# 将插件加入 plugins=() 列表（幂等，兼容单行和多行写法）
for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
    # 用 grep -F 匹配完整插件名，避免子字符串误判
    if grep -qF "$plugin" ~/.zshrc 2>/dev/null; then
        log_info "插件已启用：$plugin，跳过"
    else
        # 仅替换单行 plugins=(...)；若 .zshrc 是多行格式，提示用户手动处理
        if grep -qE "^plugins=\(.*\)[[:space:]]*$" ~/.zshrc 2>/dev/null; then
            sed -i "s/^plugins=(\(.*\))/plugins=(\1 ${plugin})/" ~/.zshrc
            log_success "已启用插件：$plugin"
        else
            log_info "plugins=() 可能是多行格式，请手动将 ${plugin} 加入 ~/.zshrc 的 plugins 列表"
        fi
    fi
done

log_section "zshrc 配置"
append_zshrc_once "# >>> debian13-install >>>" "$(cat <<'EOF'
# >>> debian13-install >>>
alias szsh="source ~/.zshrc"
alias nzsh="nvim ~/.zshrc"
alias pon="export http_proxy=http://127.0.0.1:7890; export https_proxy=http://127.0.0.1:7890; export all_proxy=socks5://127.0.0.1:7890"
alias poff="unset http_proxy; unset https_proxy; unset all_proxy"

export PATH=~/.local/bin:~/go/bin:$PATH
___MY_VMOPTIONS_SHELL_FILE="${HOME}/.jetbrains.vmoptions.sh"; if [ -f "${___MY_VMOPTIONS_SHELL_FILE}" ]; then . "${___MY_VMOPTIONS_SHELL_FILE}"; fi

# fzf shell 集成：Ctrl+R 历史搜索 / Ctrl+T 文件搜索 / Alt+C 目录跳转
command -v fzf &>/dev/null && eval "$(fzf --zsh)"
# <<< debian13-install <<<
EOF
)"

log_success "zsh 完成"
