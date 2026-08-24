// main.swift
// OpenHere — Configurable Finder toolbar app

import Cocoa
import SwiftUI

// MARK: - Main

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()

// MARK: - App Delegate

private final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        showSettingsWindow()

        // Register and enable the FinderSyncExtension on launch
        registerExtension()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    private func showSettingsWindow() {
        let settingsView = SettingsView()
        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window

        NSApp.activate(ignoringOtherApps: true)
    }

    private func registerExtension() {
        let extURL = Bundle.main.bundleURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("PlugIns")
            .appendingPathComponent("FinderSyncExtension.appex")

        guard FileManager.default.fileExists(atPath: extURL.path) else { return }

        // Register the extension
        let registerTask = Process()
        registerTask.launchPath = "/usr/bin/pluginkit"
        registerTask.arguments = ["-a", extURL.path]
        try? registerTask.run()
        registerTask.waitUntilExit()

        // Enable the extension (ad-hoc signed extensions need explicit enable)
        let enableTask = Process()
        enableTask.launchPath = "/usr/bin/pluginkit"
        enableTask.arguments = ["-e", "use", "-i", "com.local.OpenHere.FinderSync"]
        try? enableTask.run()
        enableTask.waitUntilExit()
    }
}
