// main.swift
// OpenInNyaTerm — Finder toolbar app that opens current directory in NyaTerm

import Cocoa
import ScriptingBridge

// MARK: - Constants

private let nyaTermBundleId = "com.nyakang.nyaterm"
private let defaultNyaTermAppPath = "/Applications/NyaTerm.app"
private let nyaTermUrlScheme = "nyaterm"

// MARK: - Finder path
//
// ScriptingBridge returns SBScriptableApplication (a private subclass of SBApplication).
// Swift's @objc optional protocol calls use respondsToSelector: first, which returns
// false for ScriptingBridge's dynamically-forwarded methods. We bypass this by using
// perform(_:) to send the ObjC message directly, letting ScriptingBridge forward it
// as an Apple Event — which is what triggers the TCC permission dialog.

func desktopPath() -> String {
    FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)
        .first?.path ?? NSHomeDirectory() + "/Desktop"
}

/// If the URL is a file, return its parent directory; if a folder, return itself.
func directoryPath(from url: URL) -> String {
    var isDirectory: ObjCBool = false
    if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
       !isDirectory.boolValue {
        return url.deletingLastPathComponent().path
    }
    return url.path
}

func urlFromFinderItem(_ item: NSObject) -> URL? {
    if let urlStr = item.value(forKey: "URL") as? String, let url = URL(string: urlStr) {
        return url
    }
    // Some items need an extra get() to resolve the SBObject proxy.
    if let resolved = (item as? SBObject)?.get() as? NSObject,
       let urlStr = resolved.value(forKey: "URL") as? String,
       let url = URL(string: urlStr) {
        return url
    }
    return nil
}

func finderItems(from raw: Any?) -> [NSObject] {
    if let arr = raw as? [NSObject] { return arr }
    if let nsa = raw as? NSArray { return nsa.compactMap { $0 as? NSObject } }
    if let sb = raw as? SBElementArray {
        return (0..<sb.count).compactMap { sb.object(at: $0) as? NSObject }
    }
    return []
}

/// Selection first (file → parent), then front Finder window, then Desktop.
func finderPath() -> String {
    let desktop = desktopPath()
    guard let app = SBApplication(bundleIdentifier: "com.apple.Finder") else { return desktop }

    // 1) Selected items (OpenInTerminal-style)
    if let selection = app.perform(NSSelectorFromString("selection"))?
        .takeUnretainedValue() as? SBObject {
        let items = finderItems(from: selection.get())
        if let first = items.first, let url = urlFromFinderItem(first) {
            return directoryPath(from: url)
        }
    }

    // 2) Frontmost Finder window target
    if let windows = app.perform(NSSelectorFromString("FinderWindows"))?
        .takeUnretainedValue() as? SBElementArray,
       windows.count > 0,
       let firstWindow = windows.firstObject as? NSObject,
       let target = firstWindow.value(forKey: "target") as? SBObject,
       let item = target.get() as? NSObject,
       let url = urlFromFinderItem(item) {
        return directoryPath(from: url)
    }

    return desktop
}

// MARK: - NyaTerm location

/// Prefer Launch Services (bundle id), then the default install path.
func resolveNyaTermAppURL() -> URL? {
    if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: nyaTermBundleId) {
        return url
    }
    let fallback = URL(fileURLWithPath: defaultNyaTermAppPath)
    return FileManager.default.fileExists(atPath: fallback.path) ? fallback : nil
}

// MARK: - NyaTerm launch via URL Scheme

/// Build a nyaterm:// URL that tells NyaTerm to open a local session at the given cwd.
/// Example: nyaterm://connect/local?cwd=/Users/Terry/Downloads
func buildNyaTermURL(cwd: String) -> URL? {
    var components = URLComponents()
    components.scheme = nyaTermUrlScheme
    components.host = "connect"
    components.path = "/local"
    components.queryItems = [URLQueryItem(name: "cwd", value: cwd)]
    return components.url
}

/// Open NyaTerm at the given path via URL Scheme.
/// Returns true if the `open` command succeeded.
func openPathInNyaTerm(path: String) -> Bool {
    guard let nyaTermURL = buildNyaTermURL(cwd: path) else {
        return false
    }
    // Use NSWorkspace to open the URL — this triggers the system URL handler,
    // which launches NyaTerm (or activates it if already running) with the cwd.
    return NSWorkspace.shared.open(nyaTermURL)
}

// MARK: - Errors

func notifyError(_ message: String) {
    let alert = NSAlert()
    alert.messageText = "OpenInNyaTerm"
    alert.informativeText = message
    alert.alertStyle = .warning
    alert.runModal()
}

// MARK: - Main

let path = finderPath()

guard resolveNyaTermAppURL() != nil else {
    notifyError("找不到 NyaTerm。请从 https://github.com/nyakang/nyaterm 安装后重试（支持 /Applications 或其它 Launch Services 可发现的位置）。")
    exit(1)
}

if openPathInNyaTerm(path: path) {
    exit(0)
}

let detail = "无法在 NyaTerm 中打开：\n\(path)\n\n请确认 NyaTerm 已正确安装并注册了 nyaterm:// URL Scheme。"
notifyError(detail)
exit(1)
