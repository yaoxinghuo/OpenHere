# OpenInNyaTerm

[English](./README.md) | [中文](./README-zh.md)

点一下 Finder 工具栏图标，就在 [NyaTerm](https://github.com/nyakang/nyaterm) 里打开当前目录。

> 灵感来自 [OpenInOtty](https://github.com/pintaste/OpenInOtty) 和 [OpenInTerminal-Lite](https://github.com/Ji4n1ng/OpenInTerminal)。

![macOS 12+](https://img.shields.io/badge/macOS-12%2B-blue) ![Swift 5](https://img.shields.io/badge/Swift-5-orange) ![License MIT](https://img.shields.io/badge/license-MIT-green)

---

## 功能

- **一键打开** — 点工具栏图标，NyaTerm 打开到当前 Finder 路径
- **智能路径**
  - 有选中项 → 用选中项（文件则用**父目录**）
  - 无选中 → 用当前 Finder 窗口的文件夹
  - 没有可用窗口 → 打开桌面
- **URL Scheme 集成** — 通过 `nyaterm://connect/local?cwd=<path>` 调用 NyaTerm
- **按 bundle id 查找 NyaTerm** — 不硬编码只认 `/Applications`（先走 Launch Services，再试默认路径）
- **错误提示** — 失败弹 `NSAlert`，不静默退出
- **无菜单栏 / Dock 图标** — `LSUIElement = true`，点完即退

---

## 环境要求

| 要求 | 版本 |
|---|---|
| macOS | 12.0 Monterey 或更高 |
| Xcode | 15+（App Store 免费安装即可） |
| [NyaTerm](https://github.com/nyakang/nyaterm) | 较新版本 |

NyaTerm 通常装在 `/Applications/NyaTerm.app`。装在 Launch Services 能扫到的其它位置也可以。

---

## 安装

### 方式 A — 下载预编译版本

1. 前往 [Releases 页面](https://github.com/yaoxinghuo/OpenInNyaTerm/releases)，下载最新的 `OpenInNyaTerm.app.tar.gz`。
2. 解压：
   ```bash
   tar xzf OpenInNyaTerm.app.tar.gz
   ```
3. 将 `OpenInNyaTerm.app` 拖到 `/Applications/`。
4. **移除隔离属性**（由于 app 使用 ad-hoc 签名，Finder Sync Extension 需要移除隔离属性才能加载）：
   ```bash
   xattr -cr /Applications/OpenInNyaTerm.app
   ```
5. **启动 app**（双击打开）——macOS 会在首次启动时注册 Finder Sync Extension。
6. 打开 **系统设置 → 扩展 → Finder 扩展**，启用 **OpenInNyaTerm**。
7. 在 Finder 中，选择 **查看 → 自定义工具栏…**，将 OpenInNyaTerm 图标拖到工具栏。

### 方式 B — 从源码编译

1. 克隆仓库：
   ```bash
   git clone https://github.com/yaoxinghuo/OpenInNyaTerm.git
   cd OpenInNyaTerm
   ```

2. 编译 Release：
   ```bash
   xcodebuild -project OpenInNyaTerm.xcodeproj \
              -scheme OpenInNyaTerm \
              -configuration Release \
              -derivedDataPath build \
              build
   ```

3. 安装到 Applications：
   ```bash
   cp -R build/Build/Products/Release/OpenInNyaTerm.app /Applications/
   ```

4. 启动 app，然后在 **系统设置 → 扩展 → Finder 扩展** 中启用 OpenInNyaTerm。
5. 在 Finder 中，选择 **查看 → 自定义工具栏…**，将 OpenInNyaTerm 图标拖到工具栏。

---

## 工作原理

项目包含两个组件：

1. **FinderSyncExtension** — Finder Sync 扩展，提供原生工具栏按钮（单色模板图标，自动适配深色/浅色模式）。点击后显示"Open in NyaTerm"菜单项。扩展通过 `FIFinderSyncController` 获取当前 Finder 目录。

2. **OpenInNyaTerm（主 app）** — 包含扩展的宿主 app。也可独立使用（拖到工具栏）。

```
点击工具栏按钮
       │
       ▼
  FinderSyncExtension 获取当前路径
  ┌─────────────────────────────────────────────────────────┐
  │ 有选中项？ → 用选中项（文件 → 父目录）                  │
  │ 否则 targetedURL → 当前 Finder 窗口文件夹               │
  │ 否则 ~/Desktop                                          │
  └─────────────────────────────────────────────────────────┘
       │
       ▼
  打开 nyaterm://connect/local?cwd=<path>
       │
       ▼
  NyaTerm 启动 / 激活并切换到指定目录
```

NyaTerm 注册了 `nyaterm://` URL Scheme。扩展构造一个类似 `nyaterm://connect/local?cwd=/Users/Terry/Downloads` 的 URL，然后通过 `NSWorkspace` 打开它。

---

## 项目结构

```
OpenInNyaTerm/
├── OpenInNyaTerm.xcodeproj/
│   └── project.pbxproj
├── OpenInNyaTerm/                       # 主 app target
│   ├── main.swift                       # app 逻辑（独立模式）
│   ├── Info.plist
│   ├── OpenInNyaTerm.entitlements
│   └── Assets.xcassets/
│       └── AppIcon.appiconset/          # 彩色应用图标（LaunchPad）
├── FinderSyncExtension/                # Finder Sync 扩展 target
│   ├── FinderSync.swift                 # 工具栏按钮 + 路径检测
│   ├── Info.plist
│   └── Assets.xcassets/
│       └── ToolbarIcon.imageset/       # 单色模板图标
├── .github/
│   └── workflows/
│       └── build.yml                   # CI：tag 推送时构建并发布
├── README.md                            # 英文（默认）
└── README-zh.md                         # 中文
```

---

## 排查

**点图标没反应**

- 确认已安装 NyaTerm（Spotlight / Launchpad 能搜到即可，不必须在 `/Applications`）
- 检查 **系统设置 → 隐私与安全性 → 自动化**（OpenInNyaTerm → Finder）
- 若没有权限条目：运行 `tccutil reset AppleEvents com.local.OpenInNyaTerm` 后再点一次

**打开的是桌面而不是当前文件夹**

- 至少要有一个未最小化的 Finder 窗口，或先选中某个文件/文件夹

---

## 许可证

MIT — 见 [LICENSE](LICENSE)。
