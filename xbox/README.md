# Xbox

万能工具集合。基于 GNOME Shell 的模块化扩展，把常用系统操作与自定义工具聚合到顶栏面板。

## 目录结构

```
xbox/
├── metadata.json       # 扩展元数据（UUID、名称、shell-version、settings-schema）
├── extension.js        # 入口：加载并启用各功能模块
├── prefs.js            # 首选项界面（Adw / GTK4）
├── stylesheet.css      # 样式
├── modules/            # 功能模块，每个模块实现 enable()/disable()
│   ├── base.js         # ExtensionModule 基类
│   ├── manager.js      # ModuleManager，统一启停与错误隔离
│   ├── i18n.js         # 运行时 gettext 封装（模块内使用 _()）
│   ├── i18nPrefs.js    # 首选项 gettext 封装
│   ├── quickActions.js # 模块：顶栏快速操作菜单
│   ├── statusBar.js    # 模块：状态栏（顶栏图标间距 / 时钟位置，移植自 Just Perfection）
│   ├── noOverview.js   # 模块：启动不显示总览（移植自 No overview at start-up）
│   ├── proxySwitcher.js# 模块：代理切换（移植自 Proxy Switcher）
│   ├── hideTopBar.js   # 模块：隐藏顶栏（移植自 Hide Top Bar，含边缘灵敏度修复）
│   ├── hideTopBar/     # 隐藏顶栏实现
│   │   ├── panelVisibilityManager.js
│   │   ├── intellihide.js
│   │   ├── desktopIconsIntegration.js
│   │   └── convenience.js
│   ├── tabbedWindows.js# 模块：标签窗口（由独立扩展 tabbed-windows 集成而来）
│   └── tabbed/         # 标签窗口实现
│       ├── controller.js  # 聚合控制器（原 extension.js）
│       ├── tabbar.js      # 标签栏控件
│       ├── placement.js   # 标签栏定位 / 自动隐藏 / 顶栏指示器
│       ├── overview.js    # 总览集成
│       ├── groupState.js  # 分组持久化
│       └── prefs.js       # 窗口聚合首选项页
├── schemas/
│   └── org.gnome.shell.extensions.xbox.gschema.xml
├── locale/             # gettext 翻译（zh_CN / zh）
│   ├── zh_CN.po        # 英文 msgid -> 中文译文
│   └── zh_CN/LC_MESSAGES/xbox.mo
├── tools/              # 构建与校验脚本
│   ├── po2mo.py        # .po -> .mo（无需 gettext 工具）
│   ├── extract-i18n.py # 扫描 _() 并校验翻译覆盖
│   └── check-i18n.sh   # 静态 + 可选运行时 i18n 校验
└── Makefile
```

## 标签窗口模块

标签窗口模块由独立的 `tabbed-windows` 扩展改造而来，提供 macOS 风格的标签页窗口管理。

- 开关：首选项「通用 → 功能模块 → 标签窗口」（`tabbed-windows-enabled`）
- 为避免重复注册快捷键与重复 patch `Workspace` 原型，请先停用独立的 Tabbed Windows 扩展：
  `gnome-extensions disable tabbed-windows`
  模块也会在检测到其仍在运行时自动跳过并记录日志。

## 状态栏模块

状态栏模块参考 Just Perfection，用于调整系统顶栏。

- 开关：首选项「通用 → 功能模块 → 状态栏」（`status-bar-enabled`）
- macOS Tahoe 风格：`macos-style` 一键套用（默认高度 30px、图标 16px、按钮内边距 8px、间距 8px、
  背景不透明度 60%、底部圆角 14px、时钟靠右），并叠加 Liquid Glass 半透明背景、底部圆角与阴影；
  开启时下方手动项由预设接管
- macOS Tahoe 预设可调项：`macos-panel-size`（高度）、`macos-icon-size`（图标）、
  `macos-button-padding-size`（按钮内边距）、`macos-icon-spacing`（间距）、
  `macos-clock-position` / `macos-clock-offset`（时钟）、
  `macos-panel-opacity`（背景不透明度，100 为不透明）、
  `macos-panel-radius`（底部圆角）、`macos-panel-margin`（左右外边距，>0 时悬浮）
- 手动项（非 macOS 风格时生效）：`panel-size`（高度）、`panel-icon-size`（图标）、
  `panel-button-padding-size`（按钮内边距）、`panel-icon-spacing`（间距）、
  `clock-position` / `clock-position-offset`（时钟）
- 通过内联样式覆盖主题（如 WhiteSur 的 `#panel .panel-button` 12px 内边距与 `#panel{height:28px !important}`）
- 停用模块时恢复图标间距、内边距、图标尺寸、顶栏高度与时钟的原始状态

## 启动不显示总览模块

移植自 No overview at start-up，登录后不进入总览界面。

- 开关：首选项「通用 → 功能模块 → 启动不显示总览」（`no-overview-enabled`）
- 监听 `startup-complete` 并调用 `Main.overview.hide()`

## 代理切换模块

移植自 Proxy Switcher，在系统快速设置中加入代理模式开关与菜单。

- 开关：首选项「通用 → 功能模块 → 代理切换」（`proxy-switcher-enabled`）
- 直接读写系统 schema `org.gnome.system.proxy` 的 `mode`（关闭 / 手动 / 自动）
- `active-mode` 记录最近一次启用模式，用于一键恢复
- 检测到独立扩展 `ProxySwitcher@flannaghan.com` 仍启用时自动跳过，避免重复

## 隐藏顶栏模块

移植自 Hide Top Bar，并在其基础上修复了「鼠标移到屏幕边缘显示顶栏不灵敏」的问题。

- 开关：首选项「通用 → 功能模块 → 隐藏顶栏」（`hide-top-bar-enabled`）
- 灵敏度修复：原实现只依赖 `Layout.PressureBarrier`，需持续顶住屏幕边缘约
  `pressure-timeout`（默认 1000ms）并越界 `pressure-threshold`（默认 100px）才触发。
  本模块新增基于 `PointerWatcher` 的「热边」触发：指针一旦进入屏幕顶边
  `edge-trigger-size`（默认 3px）范围即显示顶栏，`mouse-sensitive` 默认开启。
- 其余能力（智能隐藏 intellihide、总览显示、动画、快捷键、圆角）与原扩展一致
- 检测到独立扩展 `hidetopbar@mathieu.bidon.ca` 仍启用时自动跳过，避免冲突


## 国际化（中英文）

- 采用 gettext，英文为源（msgid），中文译文在 `locale/zh_CN.po`，编译为 `locale/zh_CN/LC_MESSAGES/xbox.mo`（并复制到 `locale/zh/` 作为 `LANGUAGE=zh` 的兜底）。
- `metadata.json` 中的 `gettext-domain` 为 `xbox`，名称/描述随系统语言切换。
- 代码内所有用户可见字符串使用 `_()`：运行时模块从 `modules/i18n.js`、首选项从 `modules/i18nPrefs.js` 导入。
- 修改文案后：

```bash
make locales            # .po -> .mo（zh_CN 与 zh）
make check-i18n         # 静态校验：_() 全部有非空且不同的中文译文
make check-i18n-runtime # 另起嵌套 GNOME Shell，实测 zh_CN / en_US 运行时切换
make verify             # schema + 翻译 + 全部 JS 语法
```

## 开发与安装

```bash
make link      # 编译 schema/翻译并软链到 ~/.local/share/gnome-shell/extensions/xbox
make schemas   # 仅重新编译 GSettings schema
make locales   # 仅编译翻译
make verify    # schema + 翻译 + JS 语法校验
make pack      # 打包为 xbox.shell-extension.zip
make unlink    # 移除软链
make clean
```

修改后需重启 GNOME Shell（X11: `Alt+F2` 输入 `r`；Wayland: 注销重登），
再执行 `gnome-extensions enable xbox`。

## 新增功能模块

1. 在 `modules/` 下新建文件，导出继承 `ExtensionModule` 的类；
2. 在 `extension.js` 中 `this._modules.add(new YourModule(this))`；
3. 如需配置项，在 `schemas/*.gschema.xml` 中新增 key，并在 `prefs.js` 中加界面。
