//
//  UniConvApp.swift
//  UniConv
//
//  A native macOS Tahoe application with Liquid Glass effects
//

import SwiftUI

enum LaunchMode: String, CaseIterable {
    case appOnly = "appOnly"
    case menuBarOnly = "menuBarOnly"
    case both = "both"
    
    var displayName: String {
        switch self {
        case .appOnly: return "Application Only"
        case .menuBarOnly: return "Menu Bar Only"
        case .both: return "Both"
        }
    }
}

@main
struct UniConvApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 520, idealWidth: 620, minHeight: 450, idealHeight: 720)
        }
        .windowStyle(.automatic)
        .windowToolbarStyle(.unifiedCompact)
        .defaultSize(width: 620, height: 720)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
        
        Settings {
            SettingsView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarManager: MenuBarManager?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        let launchModeRaw = UserDefaults.standard.string(forKey: "launchMode") ?? LaunchMode.both.rawValue
        let launchMode = LaunchMode(rawValue: launchModeRaw) ?? .both
        
        applyLaunchMode(launchMode)
        
        // Listen for settings changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(launchModeChanged),
            name: .launchModeDidChange,
            object: nil
        )
    }
    
    private func applyLaunchMode(_ mode: LaunchMode) {
        switch mode {
        case .appOnly:
            NSApp.setActivationPolicy(.regular)
            menuBarManager = nil
            
        case .menuBarOnly:
            NSApp.setActivationPolicy(.accessory)
            NSApp.windows.filter { $0.title == "UniConv" }.forEach { $0.close() }
            if menuBarManager == nil {
                menuBarManager = MenuBarManager()
            }
            
        case .both:
            NSApp.setActivationPolicy(.regular)
            if menuBarManager == nil {
                menuBarManager = MenuBarManager()
            }
        }
    }
    
    @objc private func launchModeChanged() {
        let launchModeRaw = UserDefaults.standard.string(forKey: "launchMode") ?? LaunchMode.both.rawValue
        let launchMode = LaunchMode(rawValue: launchModeRaw) ?? .both
        applyLaunchMode(launchMode)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        let launchModeRaw = UserDefaults.standard.string(forKey: "launchMode") ?? LaunchMode.both.rawValue
        let launchMode = LaunchMode(rawValue: launchModeRaw) ?? .both
        // Don't quit if menu bar is enabled, even if settings window closes
        return launchMode == .appOnly
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // When clicking app in Dock, show main window
        if !flag {
            if let window = NSApp.windows.first(where: { $0.title == "UniConv" }) {
                window.makeKeyAndOrderFront(nil)
            }
        }
        return true
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        ConversionManager.shared.cancelAllConversions()
    }
}

extension Notification.Name {
    static let launchModeDidChange = Notification.Name("launchModeDidChange")
}

class MenuBarManager: NSObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    
    override init() {
        super.init()
        setupMenuBar()
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath.circle", accessibilityDescription: "UniConv")
            button.action = #selector(handleClick)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 500, height: 600)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: MenuBarContentView())
    }
    
    @objc private func handleClick(_ sender: AnyObject?) {
        guard let event = NSApp.currentEvent else { return }
        
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover(sender)
        }
    }
    
    private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem?.button else { return }
        
        if popover?.isShown == true {
            popover?.performClose(sender)
        } else {
            popover?.contentViewController = NSHostingController(rootView: MenuBarContentView())
            popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover?.contentViewController?.view.window?.makeKey()
        }
    }
    
    private func showContextMenu() {
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "Open UniConv", action: #selector(openMainWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit UniConv", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }
    
    @objc private func openMainWindow() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        // Create new window if none exists
        if NSApp.windows.filter({ $0.title == "UniConv" && $0.isVisible }).isEmpty {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 620, height: 720),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "UniConv"
            window.contentView = NSHostingView(rootView: ContentView())
            window.center()
            window.makeKeyAndOrderFront(nil)
        }
    }
    
    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        if #available(macOS 14, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else if #available(macOS 13, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
