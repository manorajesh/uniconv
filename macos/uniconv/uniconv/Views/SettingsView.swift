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
        .frame(minWidth: 480, idealWidth: 520, maxWidth: 600, minHeight: 300, idealHeight: 340, maxHeight: 450)
    }
}

struct GeneralSettingsView: View {
    @AppStorage("launchMode") private var launchMode = LaunchMode.both.rawValue
    @AppStorage("defaultOutputFolder") private var defaultOutputFolder = ""
    @AppStorage("keepOriginalFiles") private var keepOriginalFiles = true
    @AppStorage("showNotifications") private var showNotifications = true
    @AppStorage("imageEngine") private var imageEngine = ImageConversionEngine.auto.rawValue
    @Namespace private var settingsNamespace
    
    private let labelWidth: CGFloat = 180
    
    var body: some View {
        GlassEffectContainer(spacing: 12) {
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
                    .buttonStyle(.glass)
                    .glassEffectID("chooseFolder", in: settingsNamespace)
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
            
            Divider()
                .padding(.leading, labelWidth + 8)
            
            // Image Conversion Engine
            HStack(alignment: .top, spacing: 0) {
                Text("Image engine:")
                    .frame(width: labelWidth, alignment: .trailing)
                    .padding(.trailing, 8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Picker("", selection: $imageEngine) {
                        ForEach(ImageConversionEngine.allCases, id: \.rawValue) { engine in
                            Text(engine.rawValue).tag(engine.rawValue)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()
                    
                    Text(ImageConversionEngine(rawValue: imageEngine)?.description ?? "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            }
            .padding(.vertical, 12)
            
            Spacer()
            }
            .padding(20)
        }
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
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            ZStack {
                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.blue.gradient)
                    .symbolEffect(.rotate, options: .repeating.speed(0.3), isActive: isAnimating)
            }
            .frame(width: 100, height: 100)
            .glassEffect(.regular.tint(.blue.opacity(0.2)), in: .circle)
            .onAppear { isAnimating = true }
            
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
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .capsule)
            
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
    @Namespace private var menuBarNamespace
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with glass effects
            GlassEffectContainer(spacing: 12) {
                HStack {
                    Text("UniConv")
                        .font(.headline)
                    
                    Spacer()
                    
                    SettingsLink {
                        Image(systemName: "gear")
                            .foregroundColor(.secondary)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .circle)
                    .glassEffectID("settings", in: menuBarNamespace)
                    .help("Settings")
                    
                    Button(action: quitApp) {
                        Image(systemName: "xmark")
                            .foregroundColor(.secondary)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .circle)
                    .glassEffectID("quit", in: menuBarNamespace)
                    .help("Quit UniConv")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
            
            // Content with glass container
            ScrollView {
                GlassEffectContainer(spacing: 12) {
                    VStack(spacing: 12) {
                        // Drop zone (compact)
                        DropZoneView(files: $files)
                            .frame(height: files.isEmpty ? 200 : 120)
                            .glassEffectID("menuDropZone", in: menuBarNamespace)
                        
                        // File queue
                        if !files.isEmpty {
                            FileQueueView(files: $files)
                                .glassEffectID("menuFileQueue", in: menuBarNamespace)
                                .transition(
                                    .scale(scale: 0.95)
                                    .combined(with: .opacity)
                                )
                        }
                    }
                    .padding(12)
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: files.isEmpty)
            }
        }
        .frame(minWidth: 450, idealWidth: 500, maxWidth: 550, minHeight: files.isEmpty ? 280 : 500, idealHeight: files.isEmpty ? 300 : 600, maxHeight: 700)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.background.opacity(0.8))
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: files.isEmpty)
    }
    
    private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

#Preview {
    SettingsView()
}
