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
    @Namespace private var dropZoneNamespace
    @State private var iconPhase: CGFloat = 0
    
    // Get default image engine from settings
    @AppStorage("imageEngine") private var defaultImageEngine = ImageConversionEngine.auto.rawValue
    
    var body: some View {
        GlassEffectContainer(spacing: 20) {
            VStack(spacing: 16) {
                // Animated icon with liquid glass
                ZStack {
                    // Animated background circles
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(.quaternary.opacity(0.3))
                            .frame(width: 80 + CGFloat(index) * 20, height: 80 + CGFloat(index) * 20)
                            .scaleEffect(isTargeted ? 1.2 : 1.0)
                            .opacity(isTargeted ? 0.5 - Double(index) * 0.15 : 0)
                    }
                    
                    Image(systemName: isTargeted ? "arrow.down.circle.fill" : "arrow.down.doc.fill")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundStyle(isTargeted ? .primary : .secondary)
                        .symbolEffect(.bounce, value: isTargeted)
                        .symbolEffect(.pulse.wholeSymbol, options: .repeating, isActive: isTargeted)
                        .contentTransition(.symbolEffect(.replace.magic(fallback: .replace)))
                        .frame(width: 80, height: 80)
                }
                .glassEffectID("dropIcon", in: dropZoneNamespace)
                .scaleEffect(isTargeted ? 1.15 : 1.0)
                
                VStack(spacing: 6) {
                    Text(isTargeted ? "Release to add files" : "Drop files here to convert")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                    
                    Text("Supports video, audio, and image files")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isTargeted)
                
                // Action buttons with liquid glass morphing
                HStack(spacing: 12) {
                    Button(action: openFilePicker) {
                        Label("Choose Files", systemImage: "folder.fill")
                            .font(.system(size: 14, weight: .medium))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.tint(.accentColor).interactive(), in: .capsule)
                    .glassEffectID("chooseButton", in: dropZoneNamespace)
                    
                    Button(action: pasteFromClipboard) {
                        Label("Paste", systemImage: "doc.on.clipboard.fill")
                            .font(.system(size: 14, weight: .medium))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .glassEffectID("pasteButton", in: dropZoneNamespace)
                    .keyboardShortcut("v", modifiers: .command)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 260)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.background.secondary.opacity(0.5))
                .strokeBorder(
                    isTargeted ? AnyShapeStyle(Color.accentColor.opacity(0.8)) : AnyShapeStyle(.quaternary.opacity(0.5)),
                    style: StrokeStyle(lineWidth: 2, dash: isTargeted ? [] : [8, 6])
                )
        }
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .shadow(color: isTargeted ? .accentColor.opacity(0.4) : .clear, radius: 30, y: 10)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isTargeted)
        .focusable(false)
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
        .alert("Unsupported File Type :(", isPresented: $showUnsupportedAlert) {
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
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] {
            for url in urls {
                if url.isFileURL {
                    addFile(url: url)
                }
            }
            if !urls.isEmpty { return }
        }
        
        // Try to get image data directly from clipboard (handles copied images better)
        // Check for common image pasteboard types
        let imageTypes: [NSPasteboard.PasteboardType] = [
            .png,
            .tiff,
            NSPasteboard.PasteboardType("public.jpeg"),
            NSPasteboard.PasteboardType("public.heic")
        ]
        
        for imageType in imageTypes {
            if let imageData = pasteboard.data(forType: imageType) {
                if let image = NSImage(data: imageData) {
                    saveImageFromClipboard(image)
                    return
                }
            }
        }
        
        // Fallback: Try NSImage initializer with pasteboard
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
            
            // Apply default image engine from settings
            if fileType == .image, let engine = ImageConversionEngine(rawValue: defaultImageEngine) {
                fileItem.options.image.engine = engine
            }
            
            files.append(fileItem)
        }
    }
}

#Preview {
    DropZoneView(files: .constant([]))
        .frame(width: 600, height: 300)
        .padding()
}
