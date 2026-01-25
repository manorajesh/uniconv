//
//  SettingsView.swift
//  UniConv
//
//  Settings window for UniConv
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            
            AboutSettingsView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 500, height: 320)
    }
}

struct GeneralSettingsView: View {
    @AppStorage("launchMode") private var launchMode = LaunchMode.both.rawValue
    @AppStorage("defaultOutputFolder") private var defaultOutputFolder = ""
    @AppStorage("keepOriginalFiles") private var keepOriginalFiles = true
    @AppStorage("showNotifications") private var showNotifications = true
    
    private let labelWidth: CGFloat = 180
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Launch Mode
            HStack(alignment: .top, spacing: 0) {
                Text("Launch mode:")
                    .frame(width: labelWidth, alignment: .trailing)
                    .padding(.trailing, 8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Picker("", selection: $launchMode) {
                        Text("Application Only").tag(LaunchMode.appOnly.rawValue)
                        Text("Menu Bar Only").tag(LaunchMode.menuBarOnly.rawValue)
                        Text("Both").tag(LaunchMode.both.rawValue)
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()
                    .onChange(of: launchMode) { _, _ in
                        NotificationCenter.default.post(name: .launchModeDidChange, object: nil)
                    }
                    
                    Text("Changes may require restart to fully apply.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            }
            .padding(.vertical, 12)
            
            Divider()
                .padding(.leading, labelWidth + 8)
            
            // Output Folder
            HStack(alignment: .center, spacing: 0) {
                Text("Default output folder:")
                    .frame(width: labelWidth, alignment: .trailing)
                    .padding(.trailing, 8)
                
                HStack(spacing: 8) {
                    TextField("Same as source", text: $defaultOutputFolder)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 180)
                    
                    Button("Choose...") {
                        selectOutputFolder()
                    }
                }
            }
            .padding(.vertical, 12)
            
            // Keep Original Files
            HStack(alignment: .center, spacing: 0) {
                Text("")
                    .frame(width: labelWidth, alignment: .trailing)
                    .padding(.trailing, 8)
                
                Toggle("Keep original files after conversion", isOn: $keepOriginalFiles)
                    .toggleStyle(.checkbox)
            }
            .padding(.vertical, 6)
            
            // Show Notifications
            HStack(alignment: .center, spacing: 0) {
                Text("")
                    .frame(width: labelWidth, alignment: .trailing)
                    .padding(.trailing, 8)
                
                Toggle("Show notifications when conversion completes", isOn: $showNotifications)
                    .toggleStyle(.checkbox)
            }
            .padding(.vertical, 6)
            
            Spacer()
        }
        .padding(20)
    }
    
    private func selectOutputFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                defaultOutputFolder = url.path
            }
        }
    }
}

struct AboutSettingsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue.gradient)
            
            Text("UniConv")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Universal File Converter")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("Version 1.0.0")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Link(destination: URL(string: "https://github.com/manorajesh/uniconv")!) {
                Label("GitHub", systemImage: "link")
            }
            .buttonStyle(.link)
            
            Spacer()
            
            Text("© 2026 UniConv. All rights reserved.")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// Condensed view for menu bar popover
struct MenuBarContentView: View {
    @State private var files: [FileItem] = []
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("UniConv")
                    .font(.headline)
                
                Spacer()
                
                SettingsLink {
                    Image(systemName: "gear")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Settings")
                
                Button(action: quitApp) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Quit UniConv")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
            
            // Content
            ScrollView {
                VStack(spacing: 12) {
                    // Drop zone (compact)
                    DropZoneView(files: $files)
                        .frame(height: files.isEmpty ? 200 : 120)
                    
                    // File queue
                    if !files.isEmpty {
                        FileQueueView(files: $files)
                    }
                }
                .padding(12)
            }
        }
        .frame(width: 500, height: files.isEmpty ? 300 : 600)
        .background(.background)
        .animation(.easeInOut(duration: 0.2), value: files.isEmpty)
    }
    
    private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

#Preview {
    SettingsView()
}
