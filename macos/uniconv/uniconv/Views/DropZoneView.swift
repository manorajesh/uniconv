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
            
            // Or choose files button
            Button(action: openFilePicker) {
                Label("Choose Files", systemImage: "folder")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
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
        
        guard !availableFormats.isEmpty else { return }
        
        // Avoid duplicates
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

