//
//  DropZoneView.swift
//  UniConv
//
//  A native macOS Tahoe drop zone with Liquid Glass effects
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
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(.quaternary)
                    .frame(width: 80, height: 80)
                
                Image(systemName: "arrow.down.doc.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(.secondary)
                    .symbolEffect(.bounce, value: isTargeted)
            }
            .scaleEffect(isTargeted ? 1.1 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isTargeted)
            
            VStack(spacing: 6) {
                Text("Drop files here to convert")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text("Supports video, audio, and image files")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            // Action buttons
            HStack(spacing: 12) {
                Button(action: openFilePicker) {
                    Label("Choose Files", systemImage: "folder")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.glass)
                .controlSize(.large)
                
                Button(action: pasteFromClipboard) {
                    Label("Paste", systemImage: "doc.on.clipboard")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.glass)
                .controlSize(.large)
                .keyboardShortcut("v", modifiers: .command)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 260)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.background.secondary)
                .strokeBorder(
                    isTargeted ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.quaternary),
                    style: StrokeStyle(lineWidth: 2, dash: isTargeted ? [] : [8, 6])
                )
        }
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
        .shadow(color: isTargeted ? .accentColor.opacity(0.3) : .clear, radius: 20)
        .scaleEffect(isTargeted ? 1.02 : 1.0)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isTargeted)
        .focusable()
        .focused($isFocused)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
            return true
        }
        .onHover { hovering in
            isHovering = hovering
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
    
    private func pasteFromClipboard() {
        let pasteboard = NSPasteboard.general
        
        // Try to get file URLs from clipboard
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] {
            for url in urls {
                if url.isFileURL {
                    addFile(url: url)
                }
            }
            return
        }
        
        // Try to get image from clipboard and save it as temp file
        if let image = NSImage(pasteboard: pasteboard) {
            saveImageFromClipboard(image)
            return
        }
        
        // Try to get file path as string
        if let string = pasteboard.string(forType: .string) {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("/") || trimmed.hasPrefix("~") {
                let expandedPath = (trimmed as NSString).expandingTildeInPath
                let url = URL(fileURLWithPath: expandedPath)
                if FileManager.default.fileExists(atPath: url.path) {
                    addFile(url: url)
                }
            }
        }
    }
    
    private func saveImageFromClipboard(_ image: NSImage) {
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            return
        }
        
        let tempDir = FileManager.default.temporaryDirectory
        let timestamp = Date().timeIntervalSince1970
        let fileName = "clipboard-image-\(Int(timestamp)).png"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        do {
            try pngData.write(to: fileURL)
            addFile(url: fileURL)
        } catch {
            print("Failed to save clipboard image: \(error)")
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
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
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
