//
//  UniConvApp.swift
//  UniConv
//
//  A native macOS Tahoe application with bold Liquid Glass effects
//

import SwiftUI

@main
struct UniConvApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 560, idealWidth: 660, minHeight: 480, idealHeight: 780)
        }
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 660, height: 780)
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
