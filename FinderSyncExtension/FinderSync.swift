import FinderSync
import Cocoa

class FinderSync: FIFinderSync {

    override init() {
        super.init()
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
    }

    // MARK: - Toolbar Item

    override var toolbarItemName: String {
        return "OpenInNyaTerm"
    }

    override var toolbarItemToolTip: String {
        return "Open current directory in NyaTerm"
    }

    override var toolbarItemImage: NSImage {
        return NSImage(named: "ToolbarIcon")!
    }

    // Clicking the toolbar button directly opens NyaTerm (no dropdown menu).
    // We still provide menu(for:) for context menus (right-click / ctrl-click).
    override func toolbarItemAction(_ sender: AnyObject?) {
        openInNyaTerm(sender)
    }

    // MARK: - Menu

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        let menu = NSMenu(title: "")
        menu.addItem(withTitle: "Open in NyaTerm", action: #selector(openInNyaTerm(_:)), keyEquivalent: "")
        return menu
    }

    // MARK: - Actions

    @IBAction func openInNyaTerm(_ sender: AnyObject?) {
        var path: String

        if let selected = FIFinderSyncController.default().selectedItemURLs()?.first {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: selected.path, isDirectory: &isDir), isDir.boolValue {
                path = selected.path
            } else {
                path = selected.deletingLastPathComponent().path
            }
        } else if let target = FIFinderSyncController.default().targetedURL() {
            path = target.path
        } else {
            path = NSHomeDirectory()
        }

        var components = URLComponents()
        components.scheme = "nyaterm"
        components.host = "connect"
        components.path = "/local"
        components.queryItems = [URLQueryItem(name: "cwd", value: path)]

        if let url = components.url {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Required Overrides

    override func beginObservingDirectory(at url: URL) {}

    override func endObservingDirectory(at url: URL) {}

    override func requestBadgeIdentifier(for url: URL) {}
}
