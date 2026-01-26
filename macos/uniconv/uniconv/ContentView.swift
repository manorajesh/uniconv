//
//  ContentView.swift
//  UniConv
//
//  A native macOS Tahoe application with Liquid Glass effects
//

import SwiftUI

struct ContentView: View {
    @State private var files: [FileItem] = []
    @State private var showMissingToolsAlert = false
    @State private var missingTools: [String] = []
    @Namespace private var mainNamespace
    
    var body: some View {
        NavigationStack {
            ScrollView {
                GlassEffectContainer(spacing: 16) {
                    VStack(spacing: 20) {
                        DropZoneView(files: $files)
                            .padding(.top, 8)
                            .glassEffectID("dropZone", in: mainNamespace)
                        
                        if !files.isEmpty {
                            FileQueueView(files: $files)
                                .glassEffectID("fileQueue", in: mainNamespace)
                                .transition(
                                    .asymmetric(
                                        insertion: .scale(scale: 0.95).combined(with: .opacity).combined(with: .move(edge: .bottom)),
                                        removal: .scale(scale: 0.9).combined(with: .opacity)
                                    )
                                )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: files.isEmpty)
                .animation(.spring(response: 0.4, dampingFraction: 0.75), value: files.count)
            }
            .scrollContentBackground(.hidden)
            .background(.background)
            .navigationTitle("UniConv")
            .onAppear {
                checkForRequiredTools()
            }
            .alert("Missing Required Tools", isPresented: $showMissingToolsAlert) {
                Button("OK") { }
                Button("Install Instructions") {
                    if let url = URL(string: "https://formulae.brew.sh/formula/ffmpeg") {
                        NSWorkspace.shared.open(url)
                    }
                }
            } message: {
                Text("The following tools are required but not found:\n\n\(missingTools.joined(separator: "\n"))\n\nInstall them using Homebrew:\nbrew install ffmpeg imagemagick")
            }
        }
    }
    
    private func checkForRequiredTools() {
        var missing: [String] = []
        
        // Check for ffmpeg
        let commonPaths = ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg", "/usr/bin/ffmpeg"]
        let ffmpegExists = commonPaths.contains { FileManager.default.isExecutableFile(atPath: $0) }
        if !ffmpegExists {
            missing.append("• FFmpeg (for video/audio conversion)")
        }
        
        // Check for ImageMagick
        let magickPaths = ["/opt/homebrew/bin/magick", "/usr/local/bin/magick", "/usr/bin/magick"]
        let magickExists = magickPaths.contains { FileManager.default.isExecutableFile(atPath: $0) }
        if !magickExists {
            missing.append("• ImageMagick (for image conversion)")
        }
        
        if !missing.isEmpty {
            missingTools = missing
            showMissingToolsAlert = true
        }
    }
}

#Preview {
    ContentView()
        .frame(width: 620, height: 720)
}
