# debian13-install

Debian 13 (trixie) 系统初始化脚本集合。

## 目录结构

```
debian13-install/
├── install.sh          # 主入口
├── fix.sh              # 修复旧版脚本遗留的环境变量/PATH 问题（按需手动执行）
├── lib/
│   └── utils.sh        # 公共工具函数（日志、git clone、zshrc 写入等）
├── xbox/               # 自研 GNOME Shell 扩展（由 gnome-extensions.sh 安装）
└── scripts/
    ├── kernel.sh       # 安装 Ubuntu Mainline 6.6 最新内核并设为默认引导
    ├── nvidia.sh       # NVIDIA 驱动（需重启进 mainline 内核后手动执行）
    ├── btrfs-timeshift.sh # Btrfs + Timeshift 快照（仅 btrfs 布局，需手动执行）
    ├── brew.sh         # Homebrew + 开发工具
    ├── fcitx.sh        # fcitx5 中文输入法
    ├── flatpak.sh      # Flatpak 应用
    ├── gnome.sh        # GNOME 快捷键配置
    ├── gnome-extensions.sh # GNOME Shell 扩展安装（extensions.gnome.org + 本仓库 xbox）
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
自动按顺序调用 `scripts/` 下的 kernel、brew、zsh、fcitx、gnome、
gnome-extensions、theme、flatpak 子脚本。

以下脚本**不会**自动执行，需手动运行：

- `scripts/nvidia.sh`：重启进入 mainline 6.6 内核后手动运行：

  ```bash
  bash scripts/nvidia.sh
  ```

- `scripts/btrfs-timeshift.sh`：仅当 `/` 为 btrfs 布局时手动运行。
- `fix.sh`：已运行过旧版脚本、环境变量未生效时用于修复
  （brew PATH、fcitx5 环境变量、`/usr/sbin` PATH）：

  ```bash
  bash fix.sh
  ```

也可单独运行某个子脚本：

```bash
bash scripts/gnome.sh
```
