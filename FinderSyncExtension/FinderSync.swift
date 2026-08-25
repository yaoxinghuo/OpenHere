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
        NSLog("[OpenHere] menuItemAction: name=%@ type=%@ path=%@", config.name, config.actionType.rawValue, path)

        switch config.actionType {
        case .urlScheme:
            // Percent-encode the path for safe URL substitution (handles spaces,
            // non-ASCII characters like CJK, etc. — matching what URLComponents
            // would do automatically, which the original hardcoded version used).
            let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
            let resolved = MenuConfigStore.resolveTemplate(config.template, path: encodedPath)
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
            let resolved = MenuConfigStore.resolveTemplate(config.template, path: quotedPath)
            let encoded = Data(resolved.utf8).base64EncodedString()
            NSLog("[OpenHere] shellCommand resolved: %@", resolved)
            if let url = URL(string: "openhere://shell?cmd=\(encoded)") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    // MARK: - Path Resolution

    /// Resolve the template by replacing {path} with the given directory path.
    /// The path is single-quoted to handle spaces and special characters.
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

    // MARK: - Required Overrides

    override func beginObservingDirectory(at url: URL) {}
    override func endObservingDirectory(at url: URL) {}
    override func requestBadgeIdentifier(for url: URL) {}
}
