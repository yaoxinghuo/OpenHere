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
        let resolved = MenuConfigStore.resolveTemplate(config.template, path: path)

        switch config.actionType {
        case .urlScheme:
            if let url = URL(string: resolved) {
                NSWorkspace.shared.open(url)
            }
        case .shellCommand:
            executeShellCommand(resolved)
        }
    }

    // MARK: - Path Resolution

    /// Get the current Finder directory: selection (file → parent) > target > home.
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

    // MARK: - Shell Command Execution

    /// Execute a shell command. The command is split into arguments by whitespace,
    /// with {path} already replaced. Uses Process for direct execution.
    private func executeShellCommand(_ command: String) {
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", command]
        try? task.run()
    }

    // MARK: - Required Overrides

    override func beginObservingDirectory(at url: URL) {}
    override func endObservingDirectory(at url: URL) {}
    override func requestBadgeIdentifier(for url: URL) {}
}
