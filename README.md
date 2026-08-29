# OpenHere

[English](./README.md) | [中文](./README-zh.md)

A minimal macOS Finder toolbar app that lets you open the current directory in any terminal or app — fully customizable.

> Inspired by [OpenInOtty](https://github.com/pintaste/OpenInOtty) and [OpenInTerminal-Lite](https://github.com/Ji4n1ng/OpenInTerminal).

![macOS 12+](https://img.shields.io/badge/macOS-12%2B-blue) ![Swift 5](https://img.shields.io/badge/Swift-5-orange) ![License MIT](https://img.shields.io/badge/license-MIT-green)

> Lightweight: the entire app is under 2 MB. No background processes, no menu bar item — just a Finder toolbar button.

<!-- Screenshots -->

<p align="center">
  <img width="1736" height="608" alt="image" src="https://github.com/user-attachments/assets/fa66d004-6d57-421f-90cd-bd842453047e" />
  &nbsp;&nbsp;
  <img width="1040" height="776" alt="image" src="https://github.com/user-attachments/assets/4201359b-efb1-4fe2-a081-a088a15f76fd" />

</p>

---

## Features

- **Configurable menu** — add unlimited menu items, each with a display name, action type, and command template
- **Two action types**
  - **URL Scheme** — open a URL (e.g. `nyaterm://connect/local?cwd={path}`)
  - **Shell Command** — execute a shell command (e.g. `open -a Terminal {path}`)
- **`{path}` placeholder** — replaced with the current Finder directory (file selection → parent folder)
- **`{filePath}` placeholder** — replaced with the selected item's full path (file → file path, folder → folder path)
- **Smart path detection**
  - Selection → use selected item (if it's a **file**, use the **parent folder**)
  - No selection → current Finder window folder
  - No usable window → Desktop
- **Settings UI** — SwiftUI-based settings window to manage your menu items
- **Finder Sync Extension** — native toolbar button with dropdown menu
- **Lightweight** — under 2 MB, no background processes, no menu bar item

---

## Requirements

| Requirement | Version |
|---|---|
| macOS | 12.0 Monterey or later |
| Xcode | 15+ (free from the App Store) |

---

## Installation

### Option A — Download pre-built app

1. Go to the [Releases page](https://github.com/yaoxinghuo/OpenHere/releases), download the latest `OpenHere.app.tar.gz`.
2. Extract it:
   ```bash
   tar xzf OpenHere.app.tar.gz
   ```
3. Copy `OpenHere.app` to `/Applications/`.
4. **Remove quarantine** (required for Finder Sync Extension to load, since the app is ad-hoc signed):
   ```bash
   xattr -cr /Applications/OpenHere.app
   ```
5. **Launch the app** (double-click it) — the settings window appears, and macOS registers the Finder Sync Extension on first launch.
6. In Finder, go to **View → Customize Toolbar…** and drag the OpenHere icon into your toolbar.
   > If the icon doesn't appear in the customize sheet, open **System Settings → Extensions → Finder Extensions** and make sure **OpenHere** is enabled.

### Option B — Build from source

1. Clone the repo:
   ```bash
   git clone https://github.com/yaoxinghuo/OpenHere.git
   cd OpenHere
   ```

2. Build a Release binary:
   ```bash
   xcodebuild -project OpenHere.xcodeproj \
              -scheme OpenHere \
              -configuration Release \
              -derivedDataPath build \
              build
   ```

3. Copy to Applications:
   ```bash
   cp -R build/Build/Products/Release/OpenHere.app /Applications/
   ```

4. Launch the app, then in Finder go to **View → Customize Toolbar…** and drag the OpenHere icon into your toolbar.
   > If the icon doesn't appear, open **System Settings → Extensions → Finder Extensions** and make sure **OpenHere** is enabled.

---

## How It Works

The project has two components:

1. **FinderSyncExtension** — a Finder Sync Extension that provides a native toolbar button with a dropdown menu. Menu items are dynamically generated from your configuration. The extension gets the current Finder directory via `FIFinderSyncController` and executes the corresponding action.

2. **OpenHere (main app)** — the host app that contains the extension and provides a SwiftUI settings window for configuring menu items. Configurations are stored in a shared JSON file inside the extension's container directory.

```
Click toolbar button
       │
       ▼
  Dropdown menu shows configured items
       │
       ▼
  FinderSyncExtension gets current path
  ┌─────────────────────────────────────────────────────────┐
  │ selected item? → use it (file → parent dir for {path})  │
  │                   (file → file path for {filePath})     │
  │ else targetedURL → current Finder window folder         │
  │ else ~/Desktop                                          │
  └─────────────────────────────────────────────────────────┘
       │
       ▼
  Replace {path} / {filePath} in template → execute action
  ┌─────────────────────────────────────────────────────────┐
  │ URL Scheme → NSWorkspace.shared.open(url)               │
  │ Shell Command → /bin/sh -c "command"                    │
  └─────────────────────────────────────────────────────────┘
```

---

## Configuration

Launch the app to open the settings window. You can:

- **Add** menu items with a display name, action type, and command template
- **Edit** items inline (name, type, template)
- **Delete** items
- **Reorder** items via up/down buttons

The default configuration includes two items: **Open in Terminal** (`open -a Terminal {path}`) and **Copy File Path** (`printf '%s' {filePath} | pbcopy`).

### Examples

| Name | Type | Template |
|---|---|---|
| Open in Terminal | Shell Command | `open -a Terminal {path}` |
| Open in iTerm | Shell Command | `open -a iTerm {path}` |
| Open in VS Code | Shell Command | `code {path}` |
| Open in NyaTerm | URL Scheme | `nyaterm://connect/local?cwd={path}` |
| Copy File Path | Shell Command | `printf '%s' {filePath} \| pbcopy` |

---

## Project Structure

```
OpenHere/
├── OpenHere.xcodeproj/
│   └── project.pbxproj
├── OpenHere/                            # Main app target
│   ├── main.swift                       # App entry point + settings window
│   ├── SettingsView.swift               # SwiftUI settings UI
│   ├── Info.plist
│   ├── OpenHere.entitlements
│   └── Assets.xcassets/
│       └── AppIcon.appiconset/          # Colorful app icon
├── Shared/                              # Shared between targets
│   └── MenuItemConfig.swift             # Data model + shared storage
├── FinderSyncExtension/                # Finder Sync Extension target
│   ├── FinderSync.swift                # Toolbar button + dynamic menu
│   ├── Info.plist
│   ├── FinderSyncExtension.entitlements
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

**Extension not showing in Finder toolbar**

- Launch the app at least once to register the extension
- Check **System Settings → Extensions → Finder Extensions** for OpenHere
- Run `pluginkit -e use -i com.local.OpenHere.FinderSync` to force-enable

**Shell command not working**

- Finder Sync Extension runs in a sandbox; some commands may be restricted
- URL Scheme actions are generally more reliable for app launching

---

## License

MIT — see [LICENSE](LICENSE).
