// main.swift
// OpenHere — Configurable Finder toolbar app

import Cocoa
import SwiftUI

// MARK: - Main

let app = NSApplication.shared
private let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()

// MARK: - App Delegate

private final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var launchedViaURL = false
    private var didFinishLaunching = false

    /// application(_:open:) is delivered AFTER applicationDidFinishLaunching(_:) completes,
    /// so a flag set there arrives too late to influence the finishLaunching branch below.
    /// Intercept the raw "get URL" Apple Event instead, registered here (before launch
    /// finishes) so `launchedViaURL` is already correct by the time finishLaunching runs.
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if launchedViaURL {
            // URL handler already processed the command; just register extension and quit
            registerExtension()
            NSApp.terminate(nil)
            return
        }

        showSettingsWindow()
        registerExtension()
        didFinishLaunching = true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    /// Handle openhere:// URL scheme — used by the FinderSyncExtension to delegate
    /// shell command execution. The app launches, executes the command, and quits.
    @objc private func handleGetURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: urlString),
              url.scheme == "openhere" else { return }

        launchedViaURL = true

        switch url.host {
        case "shell":
            if let cmd = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "cmd" })?.value,
               let data = Data(base64Encoded: cmd),
               let command = String(data: data, encoding: .utf8) {
                executeShellCommand(command)
            }
        default:
            break
        }

        // If we're already past finishLaunching (app was already running, e.g. Settings
        // window open), applicationDidFinishLaunching won't fire again to terminate us —
        // do it here once the command has run.
        if didFinishLaunching {
            registerExtension()
            NSApp.terminate(nil)
        }
    }

    private func executeShellCommand(_ command: String) {
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", command]
        try? task.run()
        task.waitUntilExit()
    }

    private func showSettingsWindow() {
        NSApp.setActivationPolicy(.regular)
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
