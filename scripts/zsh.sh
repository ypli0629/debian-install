#!/bin/bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/utils.sh"

log_section "oh-my-zsh"

if [[ -d "$HOME/.oh-my-zsh" ]]; then
    log_info "oh-my-zsh 已安装，跳过"
else
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

log_section "zsh 插件"
git_clone_or_skip https://github.com/zsh-users/zsh-autosuggestions \
    "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
git_clone_or_skip https://github.com/zsh-users/zsh-syntax-highlighting \
    "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"

# 将插件加入 plugins=() 列表（幂等）
for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
    if grep -qE "^plugins=\([^)]*${plugin}" ~/.zshrc; then
        log_info "插件已启用：$plugin，跳过"
    else
        sed -i "s/^plugins=(\(.*\))/plugins=(\1 ${plugin})/" ~/.zshrc
        log_success "已启用插件：$plugin"
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
# <<< debian13-install <<<
EOF
)"

log_success "zsh 完成"
