//
//  ContentView.swift
//  UniConv
//
//  A native macOS Tahoe application with bold Liquid Glass effects
//

import SwiftUI

struct ContentView: View {
    @State private var files: [FileItem] = []
    @State private var showMissingToolsAlert = false
    @State private var missingTools: [String] = []
    @State private var animateGradient = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Animated gradient background
                MeshGradient(
                    width: 3,
                    height: 3,
                    points: [
                        [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                        [0.0, 0.5], [animateGradient ? 0.6 : 0.4, 0.5], [1.0, 0.5],
                        [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
                    ],
                    colors: [
                        .purple.opacity(0.15), .blue.opacity(0.1), .cyan.opacity(0.15),
                        .pink.opacity(0.1), .clear, .blue.opacity(0.1),
                        .orange.opacity(0.1), .purple.opacity(0.1), .pink.opacity(0.15)
                    ]
                )
                .ignoresSafeArea()
                .onAppear {
                    withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                        animateGradient.toggle()
                    }
                }
                
                ScrollView {
                    VStack(spacing: 24) {
                        DropZoneView(files: $files)
                            .padding(.top, 12)
                        
                        if !files.isEmpty {
                            FileQueueView(files: $files)
                                .transition(
                                    .asymmetric(
                                        insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .center)),
                                        removal: .opacity.combined(with: .scale(scale: 0.95, anchor: .center))
                                    )
                                )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                    .animation(.spring(response: 0.5, dampingFraction: 0.75, blendDuration: 0.3), value: files.isEmpty)
                }
                .scrollContentBackground(.hidden)
            }
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
        .frame(width: 660, height: 780)
}
