//
//  DropZoneView.swift
//  UniConv
//
//  A native macOS Tahoe drop zone with bold Liquid Glass effects
//

import SwiftUI
import UniformTypeIdentifiers

struct DropZoneView: View {
    @Binding var files: [FileItem]
    @State private var isTargeted = false
    @State private var isHovering = false
    @State private var showUnsupportedAlert = false
    @State private var unsupportedFileName = ""
    @State private var unsupportedFileExtension = ""
    @State private var pulseAnimation = false
    @State private var iconRotation: Double = 0
    
    var body: some View {
        VStack(spacing: 24) {
            // Animated icon container
            ZStack {
                // Outer glow ring
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.blue.opacity(0.4), .purple.opacity(0.4), .pink.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 110, height: 110)
                    .blur(radius: 4)
                    .scaleEffect(pulseAnimation ? 1.15 : 1.0)
                    .opacity(pulseAnimation ? 0.3 : 0.6)
                
                // Glass circle background
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 100, height: 100)
                    .overlay {
                        Circle()
                            .stroke(.white.opacity(0.3), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
                
                Image(systemName: isTargeted ? "arrow.down.circle.fill" : "arrow.down.doc.fill")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .symbolEffect(.bounce.byLayer, value: isTargeted)
                    .rotationEffect(.degrees(iconRotation))
            }
            .scaleEffect(isTargeted ? 1.12 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isTargeted)
            .onAppear {
                withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                    pulseAnimation = true
                }
            }
            
            VStack(spacing: 10) {
                Text("Drop files here")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.primary, .primary.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("Video • Audio • Images")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            
            // Glass button
            GlassButton(title: "Choose Files", icon: "folder.fill") {
                openFilePicker()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 300)
        .background {
            ZStack {
                // Gradient glow on target
                if isTargeted {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [.blue.opacity(0.3), .purple.opacity(0.2), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 200
                            )
                        )
                        .blur(radius: 30)
                }
                
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .strokeBorder(
                        LinearGradient(
                            colors: isTargeted 
                                ? [.blue.opacity(0.8), .purple.opacity(0.8), .pink.opacity(0.8)]
                                : [.white.opacity(0.3), .white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isTargeted ? 2.5 : 1.5
                    )
            }
        }
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 24))
        .shadow(color: isTargeted ? .blue.opacity(0.25) : .black.opacity(0.08), radius: isTargeted ? 30 : 15, x: 0, y: 10)
        .scaleEffect(isTargeted ? 1.015 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isTargeted)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
            return true
        }
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            for url in urls {
                addFile(url: url)
            }
            return true
        } isTargeted: { targeted in
            isTargeted = targeted
        }
        .alert("Oops! Unsupported File Type 🙈", isPresented: $showUnsupportedAlert) {
            Button("OK") { }
        } message: {
            Text("We can't convert \(unsupportedFileName) yet.\n\n📝 \"\(unsupportedFileExtension)\" files aren't supported at the moment.\n\n✨ We support: video, audio, and image files like mp4, mp3, png, jpg, and many more!")
        }
    }
    
    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [
            .movie, .video, .audio, .image,
            .mpeg4Movie, .mpeg4Audio, .mp3, .wav, .aiff,
            .png, .jpeg, .gif, .webP, .tiff, .bmp
        ]
        
        if panel.runModal() == .OK {
            for url in panel.urls {
                addFile(url: url)
            }
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                
                DispatchQueue.main.async {
                    addFile(url: url)
                }
            }
        }
    }
    
    private func addFile(url: URL) {
        let path = url.path
        let fileName = url.lastPathComponent
        let fileExtension = url.pathExtension.lowercased()
        let fileType = FormatUtils.getFileType(fileExtension)
        let availableFormats = FormatUtils.getOutputFormats(fileType)
        
        guard !availableFormats.isEmpty else { 
            unsupportedFileName = fileName
            unsupportedFileExtension = fileExtension.isEmpty ? "unknown" : ".\(fileExtension)"
            showUnsupportedAlert = true
            return
        }
        
        guard !files.contains(where: { $0.path == path }) else { return }
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
            let fileItem = FileItem(
                path: path,
                name: fileName,
                type: fileType,
                selectedFormat: availableFormats[0],
                availableFormats: availableFormats
            )
            files.append(fileItem)
        }
    }
}

// MARK: - Glass Button Component

struct GlassButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    @State private var isPressed = false
    @State private var isHovering = false
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isPressed = false
                }
            }
            action()
        }) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(
                LinearGradient(
                    colors: [.primary, .primary.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.ultraThinMaterial)
                    
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(isHovering ? 0.5 : 0.3), .white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            }
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
            .shadow(color: .black.opacity(0.1), radius: isHovering ? 15 : 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.95 : (isHovering ? 1.02 : 1.0))
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

