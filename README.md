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

Go to the [Releases page](https://github.com/yaoxinghuo/OpenInNyaTerm/releases), download the latest `OpenInNyaTerm.app.zip`, unzip it, and copy `OpenInNyaTerm.app` to `/Applications/`.

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

   Or open `OpenInNyaTerm.xcodeproj` in Xcode, choose **Product → Archive**, and export manually.

### Add to Finder toolbar

Hold **⌘ (Command)** and drag `/Applications/OpenInNyaTerm.app` into the Finder toolbar.

The first time you click the icon, macOS will show an Apple Events permission dialog — click **Allow** to grant Finder access.

### Reset permissions (if you accidentally denied)

```bash
tccutil reset AppleEvents com.local.OpenInNyaTerm
```

Then click the toolbar icon again to re-trigger the prompt.

---

## How It Works

The app is a single Swift file (`main.swift`) — no AppDelegate, no event loop.

```
Click toolbar icon
       │
       ▼
  finderPath()
  ┌─────────────────────────────────────────────────────────┐
  │ selection? → first item URL (file → parent dir)         │
  │ else FinderWindows → first window target URL            │
  │ else ~/Desktop                                          │
  └─────────────────────────────────────────────────────────┘
       │
       ▼
  resolve NyaTerm.app (bundle id → default path)
       │
       ▼
  open nyaterm://connect/local?cwd=<path>
       │
       ▼
  NyaTerm launches / activates at the given path
       │
       ▼
  Error? → NSAlert
       │
     exit
```

NyaTerm registers a `nyaterm://` URL Scheme. The app constructs a URL like `nyaterm://connect/local?cwd=/Users/Terry/Downloads` and asks `NSWorkspace` to open it, which launches or activates NyaTerm with the specified working directory.

**Why `perform(NSSelectorFromString:)` instead of a ScriptingBridge protocol?**

Swift's `@objc optional` protocol calls check `respondsToSelector:` first. ScriptingBridge's private `SBScriptableApplication` subclass returns `false` for dynamically-forwarded Apple Event methods, so every call silently returned `nil` — and critically, the TCC permission dialog never appeared. Using `perform()` bypasses the selector check and lets ScriptingBridge forward the message as a proper Apple Event.

---

## Project Structure

```
OpenInNyaTerm/
├── OpenInNyaTerm.xcodeproj/
│   └── project.pbxproj
├── OpenInNyaTerm/
│   ├── main.swift                  # All app logic
│   ├── Info.plist                  # LSUIElement=true, usage descriptions
│   ├── OpenInNyaTerm.entitlements  # Apple Events entitlement
│   └── Assets.xcassets/
│       └── AppIcon.appiconset/     # App icon
├── .github/
│   └── workflows/
│       └── build.yml               # CI: build & release on tag push
├── README.md                       # English (default)
└── README-zh.md                    # Chinese
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
