import SwiftUI

struct SettingsView: View {
    @State private var items: [MenuItemConfig] = []
    @State private var showAddSheet = false
    @State private var selectedItemID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selectedItemID) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    MenuItemRow(item: item, onUpdate: { updated in
                        if let idx = items.firstIndex(where: { $0.id == item.id }) {
                            items[idx] = updated
                            MenuConfigStore.save(items)
                        }
                    }, onDelete: {
                        items.removeAll { $0.id == item.id }
                        MenuConfigStore.save(items)
                    })
                    .tag(item.id)
                    .listRowBackground(
                        index % 2 == 0
                            ? Color(nsColor: .windowBackgroundColor)
                            : Color(nsColor: .unemphasizedSelectedContentBackgroundColor).opacity(0.3)
                    )
                }
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)

            Divider()

            HStack {
                Button(action: { showAddSheet = true }) {
                    Label("Add", systemImage: "plus")
                }
                // Move up / down buttons for reordering (macOS has no EditMode)
                Button(action: { moveSelected(by: -1) }) {
                    Image(systemName: "arrow.up")
                }
                .buttonStyle(.borderless)
                .disabled(!canMove(by: -1))
                Button(action: { moveSelected(by: 1) }) {
                    Image(systemName: "arrow.down")
                }
                .buttonStyle(.borderless)
                .disabled(!canMove(by: 1))
                Spacer()
                Text("\(items.count) item\(items.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
        }
        .frame(minWidth: 520, minHeight: 360)
        .onAppear {
            items = MenuConfigStore.load()
        }
        .onDisappear {
            MenuConfigStore.save(items)
        }
        .sheet(isPresented: $showAddSheet) {
            AddItemSheet(
                onAdd: { newItem in
                    items.append(newItem)
                    MenuConfigStore.save(items)
                    showAddSheet = false
                },
                onCancel: {
                    showAddSheet = false
                }
            )
        }
    }

    // MARK: - Reordering

    private func canMove(by offset: Int) -> Bool {
        guard let id = selectedItemID,
              let idx = items.firstIndex(where: { $0.id == id }) else { return false }
        let target = idx + offset
        return target >= 0 && target < items.count
    }

    private func moveSelected(by offset: Int) {
        guard let id = selectedItemID,
              let idx = items.firstIndex(where: { $0.id == id }) else { return }
        let target = idx + offset
        guard target >= 0, target < items.count else { return }
        items.swapAt(idx, target)
        MenuConfigStore.save(items)
    }
}

struct MenuItemRow: View {
    let item: MenuItemConfig
    let onUpdate: (MenuItemConfig) -> Void
    let onDelete: () -> Void

    @State private var name: String
    @State private var actionType: MenuItemActionType
    @State private var template: String

    init(item: MenuItemConfig, onUpdate: @escaping (MenuItemConfig) -> Void, onDelete: @escaping () -> Void) {
        self.item = item
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        _name = State(initialValue: item.name)
        _actionType = State(initialValue: item.actionType)
        _template = State(initialValue: item.template)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Display Name", text: $name)
                    .textFieldStyle(.roundedBorder)
                Picker("", selection: $actionType) {
                    ForEach(MenuItemActionType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .labelsHidden()
                .frame(width: 140)
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(actionType == .urlScheme ? "URL Template" : "Command Template")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField(
                    actionType == .urlScheme
                        ? "myapp://open?path={path}"
                        : "open -a Terminal {path}",
                    text: $template
                )
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                Text("Use {path} as placeholder for current Finder directory.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
        .onChange(of: name) { _ in commit() }
        .onChange(of: actionType) { _ in commit() }
        .onChange(of: template) { _ in commit() }
    }

    private func commit() {
        let updated = MenuItemConfig(id: item.id, name: name, actionType: actionType, template: template)
        onUpdate(updated)
    }
}

struct AddItemSheet: View {
    @State private var name = ""
    @State private var actionType: MenuItemActionType = .urlScheme
    @State private var template = ""
    let onAdd: (MenuItemConfig) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("New Menu Item")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                TextField("Display Name", text: $name)
                    .textFieldStyle(.roundedBorder)

                Picker("Action Type", selection: $actionType) {
                    ForEach(MenuItemActionType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }

                TextField(
                    actionType == .urlScheme
                        ? "myapp://open?path={path}"
                        : "open -a Terminal {path}",
                    text: $template
                )
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))

                Text("Use {path} as placeholder for current Finder directory.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Add") {
                    let item = MenuItemConfig(
                        name: name.isEmpty ? "Untitled" : name,
                        actionType: actionType,
                        template: template
                    )
                    onAdd(item)
                }
                .keyboardShortcut(.return)
                .disabled(template.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 440)
    }
}
