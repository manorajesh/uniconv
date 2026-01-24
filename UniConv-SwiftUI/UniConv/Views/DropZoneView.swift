//
//  DropZoneView.swift
//  UniConv
//
//  Created on 1/22/2026.
//

import SwiftUI
import UniformTypeIdentifiers

struct DropZoneView: View {
    @Binding var files: [FileItem]
    @State private var isTargeted = false
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.down.doc")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("Drop files here to convert")
                .font(.headline)
                .foregroundColor(.gray)
            
            Text("Supports video, audio, and image files")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .background(
            ZStack {
                if isTargeted {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.accentColor.opacity(0.15))
                        )
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial.opacity(0.5))
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [10]))
                .foregroundStyle(
                    isTargeted ? AnyShapeStyle(.linearGradient(colors: [.accentColor, .accentColor.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyShapeStyle(.tertiary)
                )
        )
        .shadow(color: isTargeted ? Color.accentColor.opacity(0.3) : .clear, radius: 10)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
            return true
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else {
                    return
                }
                
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
            return // Skip unsupported files
        }
        
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

