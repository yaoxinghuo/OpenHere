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

前往 [Releases 页面](https://github.com/yaoxinghuo/OpenInNyaTerm/releases)，下载最新的 `OpenInNyaTerm.app.zip`，解压后将 `OpenInNyaTerm.app` 拖到 `/Applications/`。

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

   或用 Xcode 打开 `OpenInNyaTerm.xcodeproj`，选择 **Product → Archive** 后导出。

### 添加到 Finder 工具栏

按住 **⌘ (Command)**，把 `/Applications/OpenInNyaTerm.app` 拖到 Finder 工具栏。

第一次点击图标时，macOS 会弹出 Apple Events 权限对话框——点 **允许** 以授予 Finder 访问。

### 重置权限（如果不小心点了拒绝）

```bash
tccutil reset AppleEvents com.local.OpenInNyaTerm
```

然后再次点击工具栏图标以重新触发提示。

---

## 工作原理

整个 app 就是一个 Swift 文件（`main.swift`）——没有 AppDelegate，也没有常驻事件循环。

```
点击工具栏图标
       │
       ▼
  finderPath()
  ┌─────────────────────────────────────────────────────────┐
  │ selection? → 第一项 URL（文件 → 父目录）                │
  │ else FinderWindows → 第一个窗口 target URL              │
  │ else ~/Desktop                                          │
  └─────────────────────────────────────────────────────────┘
       │
       ▼
  解析 NyaTerm.app（bundle id → 默认路径）
       │
       ▼
  打开 nyaterm://connect/local?cwd=<path>
       │
       ▼
  NyaTerm 启动 / 激活并切换到指定目录
       │
       ▼
  出错？ → NSAlert
       │
     exit
```

NyaTerm 注册了 `nyaterm://` URL Scheme。本 app 构造一个类似 `nyaterm://connect/local?cwd=/Users/Terry/Downloads` 的 URL，然后通过 `NSWorkspace` 打开它，系统会启动或激活 NyaTerm 并切换到指定的工作目录。

**为什么用 `perform(NSSelectorFromString:)` 而不是 ScriptingBridge 协议？**

Swift 的 `@objc optional` 协议调用会先检查 `respondsToSelector:`。ScriptingBridge 的私有 `SBScriptableApplication` 对动态转发的方法会返回 `false`，于是调用静默得到 `nil`——更关键的是，TCC 权限对话框永远不会弹出。使用 `perform()` 可以绕过 selector 检查，让 ScriptingBridge 真正发出 Apple Event。

---

## 项目结构

```
OpenInNyaTerm/
├── OpenInNyaTerm.xcodeproj/
│   └── project.pbxproj
├── OpenInNyaTerm/
│   ├── main.swift                  # 全部逻辑
│   ├── Info.plist                  # LSUIElement=true、用途说明
│   ├── OpenInNyaTerm.entitlements  # Apple Events 权限
│   └── Assets.xcassets/
│       └── AppIcon.appiconset/     # 应用图标
├── .github/
│   └── workflows/
│       └── build.yml               # CI：tag 推送时构建并发布
├── README.md                       # 英文（默认）
└── README-zh.md                    # 中文
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
