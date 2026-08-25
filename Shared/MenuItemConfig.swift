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
/// Uses getpwuid to find the real home directory, bypassing sandbox container paths.
struct MenuConfigStore {
    static let sharedDir: URL = {
        let home: String
        if let pw = getpwuid(getuid()) {
            home = String(cString: pw.pointee.pw_dir)
        } else {
            home = NSHomeDirectory()
        }
        let dir = URL(fileURLWithPath: home)
            .appendingPathComponent("Library/Application Support/OpenHere")
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }()

    static let configFile = sharedDir.appendingPathComponent("menuitems.json")
    static let pathPlaceholder = "{path}"

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

    /// Resolve the template by replacing {path} with the given directory path.
    static func resolveTemplate(_ template: String, path: String) -> String {
        template.replacingOccurrences(of: pathPlaceholder, with: path)
    }
}
