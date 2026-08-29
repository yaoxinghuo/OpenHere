# OpenHere

[English](./README.md) | [中文](./README-zh.md)

一个极简的 macOS Finder 工具栏应用，可以自定义菜单项，在任意终端或应用中打开当前目录。

> 灵感来自 [OpenInOtty](https://github.com/pintaste/OpenInOtty) 和 [OpenInTerminal-Lite](https://github.com/Ji4n1ng/OpenInTerminal)。

![macOS 12+](https://img.shields.io/badge/macOS-12%2B-blue) ![Swift 5](https://img.shields.io/badge/Swift-5-orange) ![License MIT](https://img.shields.io/badge/license-MIT-green)

> 轻量级：整个应用不到 2 MB。无后台进程，无菜单栏图标——只有一个 Finder 工具栏按钮。

<!-- 截图 -->

<p align="center">
  <img width="1746" height="662" alt="image" src="https://github.com/user-attachments/assets/59befc24-1d08-4425-b173-ca77b91abe14" />
  &nbsp;&nbsp;
  <img width="1040" height="776" alt="image" src="https://github.com/user-attachments/assets/4201359b-efb1-4fe2-a081-a088a15f76fd" />

</p>

---

## 功能

- **可配置菜单** — 添加任意多个菜单项，每项包含显示名称、动作类型和命令模板
- **两种动作类型**
  - **URL Scheme** — 打开 URL（如 `nyaterm://connect/local?cwd={path}`）
  - **Shell Command** — 执行 shell 命令（如 `open -a Terminal {path}`）
- **`{path}` 占位符** — 替换为当前 Finder 目录路径（选中文件时用父目录）
- **`{filePath}` 占位符** — 替换为选中项的完整路径（文件→文件路径，文件夹→文件夹路径）
- **智能路径检测**
  - 有选中项 → 用选中项（文件则用**父目录**）
  - 无选中 → 用当前 Finder 窗口的文件夹
  - 没有可用窗口 → 打开桌面
- **设置界面** — 基于 SwiftUI 的设置窗口，方便管理菜单项
- **Finder Sync 扩展** — 原生工具栏按钮 + 下拉菜单
- **轻量级** — 不到 2 MB，无后台进程，无菜单栏图标

---

## 环境要求

| 要求 | 版本 |
|---|---|
| macOS | 12.0 Monterey 或更高 |
| Xcode | 15+（App Store 免费安装即可） |

---

## 安装

### 方式 A — 下载预编译版本

1. 前往 [Releases 页面](https://github.com/yaoxinghuo/OpenHere/releases)，下载最新的 `OpenHere.app.tar.gz`。
2. 解压：
   ```bash
   tar xzf OpenHere.app.tar.gz
   ```
3. 将 `OpenHere.app` 拖到 `/Applications/`。
4. **移除隔离属性**（由于 app 使用 ad-hoc 签名，Finder Sync Extension 需要移除隔离属性才能加载）：
   ```bash
   xattr -cr /Applications/OpenHere.app
   ```
5. **启动 app**（双击打开）——设置窗口会出现，macOS 会在首次启动时注册 Finder Sync Extension。
6. 在 Finder 中，选择 **查看 → 自定义工具栏…**，将 OpenHere 图标拖到工具栏。
   > 如果自定义工具栏中看不到 OpenHere 图标，打开 **系统设置 → 扩展 → Finder 扩展**，确认 **OpenHere** 已启用。

### 方式 B — 从源码编译

1. 克隆仓库：
   ```bash
   git clone https://github.com/yaoxinghuo/OpenHere.git
   cd OpenHere
   ```

2. 编译 Release：
   ```bash
   xcodebuild -project OpenHere.xcodeproj \
              -scheme OpenHere \
              -configuration Release \
              -derivedDataPath build \
              build
   ```

3. 安装到 Applications：
   ```bash
   cp -R build/Build/Products/Release/OpenHere.app /Applications/
   ```

4. 启动 app，然后在 Finder 中选择 **查看 → 自定义工具栏…**，将 OpenHere 图标拖到工具栏。
   > 如果看不到 OpenHere 图标，打开 **系统设置 → 扩展 → Finder 扩展**，确认 **OpenHere** 已启用。

---

## 工作原理

项目包含两个组件：

1. **FinderSyncExtension** — Finder Sync 扩展，提供原生工具栏按钮和下拉菜单。菜单项根据你的配置动态生成。扩展通过 `FIFinderSyncController` 获取当前 Finder 目录并执行对应动作。

2. **OpenHere（主 app）** — 包含扩展的宿主 app，提供 SwiftUI 设置窗口用于配置菜单项。配置通过共享 JSON 文件存储在扩展的容器目录中。

```
点击工具栏按钮
       │
       ▼
  下拉菜单显示已配置的菜单项
       │
       ▼
  FinderSyncExtension 获取当前路径
  ┌─────────────────────────────────────────────────────────┐
  │ 有选中项？ → 用选中项（文件 → 父目录 for {path}）        │
  │                 （文件 → 文件路径 for {filePath}）       │
  │ 否则 targetedURL → 当前 Finder 窗口文件夹               │
  │ 否则 ~/Desktop                                          │
  └─────────────────────────────────────────────────────────┘
       │
       ▼
  替换模板中的 {path} / {filePath} → 执行动作
  ┌─────────────────────────────────────────────────────────┐
  │ URL Scheme → NSWorkspace.shared.open(url)               │
  │ Shell Command → /bin/sh -c "command"                    │
  └─────────────────────────────────────────────────────────┘
```

---

## 配置

启动 app 即可打开设置窗口。你可以：

- **添加** 菜单项（显示名称、动作类型、命令模板）
- **编辑** 菜单项（名称、类型、模板）
- **删除** 菜单项
- **上/下按钮排序** 菜单项

默认配置包含两项：**Open in Terminal**（`open -a Terminal {path}`）和 **Copy File Path**（`printf '%s' {filePath} | pbcopy`）。

### 示例

| 名称 | 类型 | 模板 |
|---|---|---|
| Open in Terminal | Shell Command | `open -a Terminal {path}` |
| Open in iTerm | Shell Command | `open -a iTerm {path}` |
| Open in VS Code | Shell Command | `code {path}` |
| Open in NyaTerm | URL Scheme | `nyaterm://connect/local?cwd={path}` |
| Copy File Path | Shell Command | `printf '%s' {filePath} \| pbcopy` |

---

## 项目结构

```
OpenHere/
├── OpenHere.xcodeproj/
│   └── project.pbxproj
├── OpenHere/                            # 主 app target
│   ├── main.swift                       # app 入口 + 设置窗口
│   ├── SettingsView.swift               # SwiftUI 设置界面
│   ├── Info.plist
│   ├── OpenHere.entitlements
│   └── Assets.xcassets/
│       └── AppIcon.appiconset/          # 彩色应用图标
├── Shared/                              # 跨 target 共享
│   └── MenuItemConfig.swift             # 数据模型 + 共享存储
├── FinderSyncExtension/                # Finder Sync 扩展 target
│   ├── FinderSync.swift                # 工具栏按钮 + 动态菜单
│   ├── Info.plist
│   ├── FinderSyncExtension.entitlements
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

**扩展未在 Finder 工具栏显示**

- 至少启动一次 app 以注册扩展
- 检查 **系统设置 → 扩展 → Finder 扩展** 中是否有 OpenHere
- 运行 `pluginkit -e use -i com.local.OpenHere.FinderSync` 强制启用

**Shell 命令不工作**

- Finder Sync Extension 在沙盒中运行，部分命令可能受限
- URL Scheme 动作通常更可靠

---

## 许可证

MIT — 见 [LICENSE](LICENSE)。
