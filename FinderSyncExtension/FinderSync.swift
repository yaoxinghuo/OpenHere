import FinderSync
import Cocoa

class FinderSync: FIFinderSync {

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

        let menu = NSMenu(title: "")
        for item in items {
            let menuItem = NSMenuItem(
                title: item.name,
                action: #selector(menuItemAction(_:)),
                keyEquivalent: ""
            )
            menuItem.representedObject = item
            menu.addItem(menuItem)
        }
        return menu
    }

    // MARK: - Actions

    @IBAction func menuItemAction(_ sender: NSMenuItem) {
        guard let config = sender.representedObject as? MenuItemConfig else { return }

        let path = currentPath()

        switch config.actionType {
        case .urlScheme:
            // Open URL schemes directly from the extension
            let resolved = MenuConfigStore.resolveTemplate(config.template, path: path)
            if let url = URL(string: resolved) {
                NSWorkspace.shared.open(url)
            }
        case .shellCommand:
            // Shell commands must be delegated to the main app via openhere:// URL scheme,
            // because the FinderSync extension is sandboxed and cannot use Process.
            // Path is single-quoted to handle spaces and special characters.
            let quotedPath = "'\(path.replacingOccurrences(of: "'", with: "'\\''"))'"
            let resolved = MenuConfigStore.resolveTemplate(config.template, path: quotedPath)
            let encoded = Data(resolved.utf8).base64EncodedString()
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
