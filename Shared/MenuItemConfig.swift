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

/// Manages menu item configurations stored in a shared UserDefaults suite
/// accessible by both the main app and the Finder Sync Extension.
struct MenuConfigStore {
    static let suiteName = "com.local.OpenHere.shared"
    static let key = "menuItems"
    static let pathPlaceholder = "{path}"

    static func load() -> [MenuItemConfig] {
        let defaults = UserDefaults(suiteName: suiteName)
        guard let data = defaults?.data(forKey: key) else {
            return defaultItems()
        }
        return (try? JSONDecoder().decode([MenuItemConfig].self, from: data)) ?? defaultItems()
    }

    static func save(_ items: [MenuItemConfig]) {
        let defaults = UserDefaults(suiteName: suiteName)
        if let data = try? JSONEncoder().encode(items) {
            defaults?.set(data, forKey: key)
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
