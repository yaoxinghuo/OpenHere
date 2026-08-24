# OpenInNyaTerm

[English](./README.md) | [中文](./README-zh.md)

A minimal macOS Finder toolbar app that opens the current directory in [NyaTerm](https://github.com/nyakang/nyaterm) with a single click.

> Inspired by [OpenInOtty](https://github.com/pintaste/OpenInOtty) and [OpenInTerminal-Lite](https://github.com/Ji4n1ng/OpenInTerminal).

![macOS 12+](https://img.shields.io/badge/macOS-12%2B-blue) ![Swift 5](https://img.shields.io/badge/Swift-5-orange) ![License MIT](https://img.shields.io/badge/license-MIT-green)

---

## Features

- **One click** — toolbar icon opens NyaTerm at the current Finder path
- **Smart path**
  - Selection → use selected item (if it's a **file**, use the **parent folder**)
  - No selection → current Finder window folder
  - No usable window → Desktop
- **URL Scheme integration** — opens NyaTerm via `nyaterm://connect/local?cwd=<path>`
- **Find NyaTerm by bundle id** — not hard-coded to `/Applications` only (Launch Services first, then default path)
- **Error alerts** — failures show an `NSAlert` instead of failing silently
- **No menu bar / Dock icon** — `LSUIElement = true`; quits right after dispatch

---

## Requirements

| Requirement | Version |
|---|---|
| macOS | 12.0 Monterey or later |
| Xcode | 15+ (free from the App Store) |
| [NyaTerm](https://github.com/nyakang/nyaterm) | Any recent version |

NyaTerm is usually at `/Applications/NyaTerm.app`. Any location Launch Services can find is fine.

---

## Installation

### Option A — Download pre-built app

1. Go to the [Releases page](https://github.com/yaoxinghuo/OpenInNyaTerm/releases), download the latest `OpenInNyaTerm.app.tar.gz`.
2. Extract it:
   ```bash
   tar xzf OpenInNyaTerm.app.tar.gz
   ```
3. Copy `OpenInNyaTerm.app` to `/Applications/`.
4. **Remove quarantine** (required for Finder Sync Extension to load, since the app is ad-hoc signed):
   ```bash
   xattr -cr /Applications/OpenInNyaTerm.app
   ```
5. **Launch the app** (double-click it) — macOS registers the Finder Sync Extension on first launch.
6. Open **System Settings → Extensions → Finder Extensions** and enable **OpenInNyaTerm**.
7. In Finder, go to **View → Customize Toolbar…** and drag the OpenInNyaTerm icon into your toolbar.

### Option B — Build from source

1. Clone the repo:
   ```bash
   git clone https://github.com/yaoxinghuo/OpenInNyaTerm.git
   cd OpenInNyaTerm
   ```

2. Build a Release binary:
   ```bash
   xcodebuild -project OpenInNyaTerm.xcodeproj \
              -scheme OpenInNyaTerm \
              -configuration Release \
              -derivedDataPath build \
              build
   ```

3. Copy to Applications:
   ```bash
   cp -R build/Build/Products/Release/OpenInNyaTerm.app /Applications/
   ```

4. Launch the app, then enable the extension in **System Settings → Extensions → Finder Extensions**.
5. In Finder, go to **View → Customize Toolbar…** and drag the OpenInNyaTerm icon into your toolbar.

---

## How It Works

The project has two components:

1. **FinderSyncExtension** — a Finder Sync Extension that provides a native toolbar button (monochrome template icon, adapts to light/dark mode). When clicked, it shows a menu with "Open in NyaTerm". The extension gets the current Finder directory via `FIFinderSyncController`.

2. **OpenInNyaTerm (main app)** — the host app that contains the extension. Also usable standalone by dragging to the toolbar.

```
Click toolbar button
       │
       ▼
  FinderSyncExtension gets current path
  ┌─────────────────────────────────────────────────────────┐
  │ selected item? → use it (file → parent dir)             │
  │ else targetedURL → current Finder window folder         │
  │ else ~/Desktop                                          │
  └─────────────────────────────────────────────────────────┘
       │
       ▼
  open nyaterm://connect/local?cwd=<path>
       │
       ▼
  NyaTerm launches / activates at the given path
```

NyaTerm registers a `nyaterm://` URL Scheme. The extension constructs a URL like `nyaterm://connect/local?cwd=/Users/Terry/Downloads` and asks `NSWorkspace` to open it.

---

## Project Structure

```
OpenInNyaTerm/
├── OpenInNyaTerm.xcodeproj/
│   └── project.pbxproj
├── OpenInNyaTerm/                       # Main app target
│   ├── main.swift                       # App logic (standalone mode)
│   ├── Info.plist
│   ├── OpenInNyaTerm.entitlements
│   └── Assets.xcassets/
│       └── AppIcon.appiconset/          # Colorful app icon (LaunchPad)
├── FinderSyncExtension/                # Finder Sync Extension target
│   ├── FinderSync.swift                # Toolbar button + path detection
│   ├── Info.plist
│   └── Assets.xcassets/
│       └── ToolbarIcon.imageset/       # Monochrome template icon
├── .github/
│   └── workflows/
│       └── build.yml                   # CI: build & release on tag push
├── README.md                            # English (default)
└── README-zh.md                         # Chinese
```

---

## Troubleshooting

**Nothing happens when I click the icon**

- Make sure NyaTerm is installed (Spotlight / Launchpad is enough; `/Applications` is not required)
- Check **System Settings → Privacy & Security → Automation** (OpenInNyaTerm → Finder)
- If the permission entry is missing: `tccutil reset AppleEvents com.local.OpenInNyaTerm`, then click again

**Opens Desktop instead of the current folder**

- You need at least one non-minimized Finder window, or a selected file/folder

---

## License

MIT — see [LICENSE](LICENSE).
