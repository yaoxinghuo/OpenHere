import Foundation

enum MenuItemActionType: String, Codable, CaseIterable {
    case urlScheme = "URL Scheme"
    case shellCommand = "Shell Command"
}

struct MenuItemConfig: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var actionType: MenuItemActionType
    var template: String

    init(id: UUID = UUID(), name: String, actionType: MenuItemActionType, template: String) {
        self.id = id
        self.name = name
        self.actionType = actionType
        self.template = template
    }
}

/// Manages menu item configurations stored in a shared JSON file
/// accessible by both the main app and the Finder Sync Extension.
///
/// Key insight: the FinderSync extension is sandboxed and can only access its own
/// container directory. The main app is non-sandboxed and can write anywhere.
/// So we store the config file inside the extension's container:
///   ~/Library/Containers/com.local.OpenHere.FinderSync/Data/Library/Application Support/OpenHere/
/// The main app writes there (it has full filesystem access), and the extension
/// reads from there (it's within its sandbox boundary). No special entitlements needed.
struct MenuConfigStore {
    static let extensionBundleId = "com.local.OpenHere.FinderSync"

    static let sharedDir: URL = {
        let isExtension = Bundle.main.bundleIdentifier == extensionBundleId

        if isExtension {
            // Inside the sandboxed extension, NSHomeDirectory() returns the container root.
            let dir = URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent("Library/Application Support/OpenHere")
            if !FileManager.default.fileExists(atPath: dir.path) {
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            }
            return dir
        } else {
            // Main app (non-sandboxed): write directly into the extension's container
            // so the sandboxed extension can read it without any file-access entitlements.
            let home: String
            if let pw = getpwuid(getuid()) {
                home = String(cString: pw.pointee.pw_dir)
            } else {
                home = NSHomeDirectory()
            }
            let dir = URL(fileURLWithPath: home)
                .appendingPathComponent("Library/Containers/\(extensionBundleId)/Data/Library/Application Support/OpenHere")
            if !FileManager.default.fileExists(atPath: dir.path) {
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            }
            return dir
        }
    }()

    static let configFile = sharedDir.appendingPathComponent("menuitems.json")
    static let pathPlaceholder = "{path}"
    static let filePathPlaceholder = "{filePath}"

    static func load() -> [MenuItemConfig] {
        guard let data = try? Data(contentsOf: configFile) else {
            return defaultItems()
        }
        return (try? JSONDecoder().decode([MenuItemConfig].self, from: data)) ?? defaultItems()
    }

    static func save(_ items: [MenuItemConfig]) {
        if let data = try? JSONEncoder().encode(items) {
            try? data.write(to: configFile, options: .atomic)
        }
    }

    static func defaultItems() -> [MenuItemConfig] {
        return [
            MenuItemConfig(
                name: "Open in Terminal",
                actionType: .shellCommand,
                template: "open -a Terminal {path}"
            )
        ]
    }

    /// Resolve the template by replacing {filePath} and {path} placeholders.
    /// {filePath} is replaced first so that {path} only matches the directory placeholder,
    /// not a substring of {filePath}.
    static func resolveTemplate(_ template: String, path: String, filePath: String) -> String {
        template
            .replacingOccurrences(of: filePathPlaceholder, with: filePath)
            .replacingOccurrences(of: pathPlaceholder, with: path)
    }
}
