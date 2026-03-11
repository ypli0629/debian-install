# debian13-install

Debian 13 (trixie) 系统初始化脚本集合。

## 目录结构

```
debian13-install/
├── install.sh          # 主入口
├── lib/
│   └── utils.sh        # 公共工具函数（日志、git clone、zshrc 写入等）
└── scripts/
    ├── kernel.sh       # 安装 Ubuntu Mainline 6.6 最新内核并设为默认引导
    ├── brew.sh         # Homebrew + 开发工具
    ├── fcitx.sh        # fcitx5 中文输入法
    ├── flatpak.sh      # Flatpak 应用
    ├── gnome.sh        # GNOME 快捷键配置
    ├── theme.sh        # WhiteSur 主题
    └── zsh.sh          # oh-my-zsh + 插件 + 别名
```

## 使用方式

```bash
git clone <repo>
cd debian13-install
bash install.sh
```

`install.sh` 会完成系统更新、Docker、Clash Verge、SwitchHosts 安装后，
自动按顺序调用 `scripts/` 下的所有子脚本。

也可单独运行某个子脚本：

```bash
bash scripts/gnome.sh
```
