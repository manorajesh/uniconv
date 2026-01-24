//
//  UniConvApp.swift
//  UniConv
//
//  A native macOS Tahoe application with Liquid Glass effects
//

import SwiftUI

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
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        ConversionManager.shared.cancelAllConversions()
    }
}
