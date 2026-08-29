import FinderSync
import Cocoa

class FinderSync: FIFinderSync {

    /// Cached menu items for the current menu invocation.
    /// Finder Sync extensions are XPC services: the menu is shown by the Finder
    /// process and the action is sent back via XPC. representedObject (a Swift
    /// struct boxed as __SwiftValue) does NOT survive this round-trip because it
    /// doesn't conform to NSSecureCoding. So we cache the items here and use the
    /// menu item's tag as an index.
    private var cachedMenuItems: [MenuItemConfig] = []

    override init() {
        super.init()
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
    }

    // MARK: - Toolbar Item

    override var toolbarItemName: String {
        return "OpenHere"
    }

    override var toolbarItemToolTip: String {
        return "Open current directory with configured apps"
    }

    override var toolbarItemImage: NSImage {
        return NSImage(named: "ToolbarIcon")!
    }

    // MARK: - Menu

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        let items = MenuConfigStore.load()
        guard !items.isEmpty else { return nil }

        cachedMenuItems = items

        let menu = NSMenu(title: "")
        for (index, item) in items.enumerated() {
            let menuItem = NSMenuItem(
                title: item.name,
                action: #selector(menuItemAction(_:)),
                keyEquivalent: ""
            )
            menuItem.tag = index
            menu.addItem(menuItem)
        }
        // Add a separator and Settings item at the bottom
        menu.addItem(NSMenuItem.separator())
        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettings(_:)),
            keyEquivalent: ""
        )
        menu.addItem(settingsItem)
        return menu
    }

    // MARK: - Actions

    @IBAction func menuItemAction(_ sender: NSMenuItem) {
        let index = sender.tag
        guard index >= 0, index < cachedMenuItems.count else {
            NSLog("[OpenHere] menuItemAction: invalid tag %d, cached count %d", index, cachedMenuItems.count)
            return
        }
        let config = cachedMenuItems[index]

        let path = currentPath()
        let filePath = currentFilePath()
        NSLog("[OpenHere] menuItemAction: name=%@ type=%@ path=%@ filePath=%@", config.name, config.actionType.rawValue, path, filePath)

        switch config.actionType {
        case .urlScheme:
            // Percent-encode the path for safe URL substitution (handles spaces,
            // non-ASCII characters like CJK, etc. — matching what URLComponents
            // would do automatically, which the original hardcoded version used).
            let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
            let encodedFilePath = filePath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? filePath
            let resolved = MenuConfigStore.resolveTemplate(config.template, path: encodedPath, filePath: encodedFilePath)
            NSLog("[OpenHere] urlScheme resolved: %@", resolved)
            if let url = URL(string: resolved) {
                NSWorkspace.shared.open(url)
            } else {
                NSLog("[OpenHere] URL(string:) returned nil for: %@", resolved)
            }
        case .shellCommand:
            // Shell commands cannot run in a sandboxed extension.
            // Delegate to the main app via openhere:// URL scheme.
            // The main app will execute the command and quit immediately.
            let quotedPath = "'\(path.replacingOccurrences(of: "'", with: "'\\''"))'"
            let quotedFilePath = "'\(filePath.replacingOccurrences(of: "'", with: "'\\''"))'"
            let resolved = MenuConfigStore.resolveTemplate(config.template, path: quotedPath, filePath: quotedFilePath)
            let encoded = Data(resolved.utf8).base64EncodedString()
            NSLog("[OpenHere] shellCommand resolved: %@", resolved)
            if let url = URL(string: "openhere://shell?cmd=\(encoded)") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    /// Open the host app's Settings window.
    /// The extension lives inside the host app bundle at
    ///   OpenHere.app/Contents/PlugIns/FinderSyncExtension.appex
    /// so we navigate up two levels to find the host app URL —
    /// no hardcoded path needed.
    @IBAction func openSettings(_ sender: NSMenuItem) {
        let hostAppURL = Bundle.main.bundleURL
            .deletingLastPathComponent()  // → PlugIns/
            .deletingLastPathComponent()  // → Contents/
            .deletingLastPathComponent()  // → OpenHere.app/
        NSLog("[OpenHere] openSettings: hostAppURL=%@", hostAppURL.path)
        NSWorkspace.shared.openApplication(at: hostAppURL, configuration: NSWorkspace.OpenConfiguration())
    }

    // MARK: - Path Resolution

    /// Returns the directory path for {path} placeholder.
    /// If a file is selected, returns its parent directory; if a directory is selected, returns it directly.
    private func currentPath() -> String {
        let controller = FIFinderSyncController.default()

        if let selected = controller.selectedItemURLs()?.first {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: selected.path, isDirectory: &isDir), isDir.boolValue {
                return selected.path
            } else {
                return selected.deletingLastPathComponent().path
            }
        }

        if let target = controller.targetedURL() {
            return target.path
        }

        return NSHomeDirectory()
    }

    /// Returns the full path of the selected item for {filePath} placeholder.
    /// If a file is selected, returns the file path; if a directory is selected, returns the directory path.
    private func currentFilePath() -> String {
        let controller = FIFinderSyncController.default()

        if let selected = controller.selectedItemURLs()?.first {
            return selected.path
        }

        if let target = controller.targetedURL() {
            return target.path
        }

        return NSHomeDirectory()
    }

    // MARK: - Required Overrides

    override func beginObservingDirectory(at url: URL) {}
    override func endObservingDirectory(at url: URL) {}
    override func requestBadgeIdentifier(for url: URL) {}
}
