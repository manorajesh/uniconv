//
//  FileInfoView.swift
//  UniConv
//
//  View for displaying file metadata information
//

import SwiftUI

struct FileInfoView: View {
    let file: FileItem
    @Environment(\.dismiss) var dismiss
    
    @State private var inputInfo: FileInfo?
    @State private var outputInfo: FileInfo?
    @State private var isLoading = true
    @State private var selectedTab = 0
    
    private var hasOutput: Bool {
        file.outputPath != nil && FileManager.default.fileExists(atPath: file.outputPath!)
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading file info...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 0) {
                        if hasOutput {
                            Picker("", selection: $selectedTab) {
                                Text("Input").tag(0)
                                Text("Output").tag(1)
                            }
                            .pickerStyle(.segmented)
                            .padding()
                        }
                        
                        ScrollView {
                            VStack(spacing: 16) {
                                if selectedTab == 0, let info = inputInfo {
                                    FileInfoContent(info: info, fileType: file.type)
                                } else if selectedTab == 1, let info = outputInfo {
                                    FileInfoContent(info: info, fileType: file.type)
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("File Info")
            .navigationSubtitle(file.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)
                }
            }
        }
        .frame(width: 450, height: 500)
        .task {
            await loadFileInfo()
        }
    }
    
    private func loadFileInfo() async {
        let service = FileInfoService.shared
        
        // Load input file info
        inputInfo = await service.getFileInfo(for: file.path, type: file.type)
        
        // Load output file info if available
        if let outputPath = file.outputPath,
           FileManager.default.fileExists(atPath: outputPath) {
            outputInfo = await service.getFileInfo(for: outputPath, type: file.type)
        }
        
        isLoading = false
    }
}

struct FileInfoContent: View {
    let info: FileInfo
    let fileType: FileType
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // General info
            InfoSection(title: "General") {
                InfoRow(label: "Filename", value: info.filename)
                InfoRow(label: "Size", value: info.formattedSize)
                if let format = info.format {
                    InfoRow(label: "Format", value: format)
                }
                if let created = info.creationDate {
                    InfoRow(label: "Created", value: formatDate(created))
                }
                if let modified = info.modificationDate {
                    InfoRow(label: "Modified", value: formatDate(modified))
                }
            }
            
            // Video info
            if fileType == .video {
                InfoSection(title: "Video") {
                    if let resolution = info.resolution {
                        InfoRow(label: "Resolution", value: resolution)
                    }
                    if let codec = info.codec {
                        InfoRow(label: "Codec", value: codec)
                    }
                    if let frameRate = info.frameRate {
                        InfoRow(label: "Frame Rate", value: frameRate)
                    }
                    if let duration = info.duration {
                        InfoRow(label: "Duration", value: duration)
                    }
                    if let bitrate = info.bitrate {
                        InfoRow(label: "Bitrate", value: bitrate)
                    }
                }
                
                if info.audioCodec != nil {
                    InfoSection(title: "Audio") {
                        if let codec = info.audioCodec {
                            InfoRow(label: "Codec", value: codec)
                        }
                        if let sampleRate = info.audioSampleRate {
                            InfoRow(label: "Sample Rate", value: sampleRate)
                        }
                        if let channels = info.audioChannels {
                            InfoRow(label: "Channels", value: channels)
                        }
                    }
                }
            }
            
            // Audio info
            if fileType == .audio {
                InfoSection(title: "Audio") {
                    if let duration = info.duration {
                        InfoRow(label: "Duration", value: duration)
                    }
                    if let codec = info.audioCodec ?? info.codec {
                        InfoRow(label: "Codec", value: codec)
                    }
                    if let bitrate = info.bitrate {
                        InfoRow(label: "Bitrate", value: bitrate)
                    }
                    if let sampleRate = info.audioSampleRate {
                        InfoRow(label: "Sample Rate", value: sampleRate)
                    }
                    if let channels = info.audioChannels {
                        InfoRow(label: "Channels", value: channels)
                    }
                }
            }
            
            // Image info
            if fileType == .image {
                InfoSection(title: "Image") {
                    if let dimensions = info.dimensions {
                        InfoRow(label: "Dimensions", value: dimensions)
                    }
                    if let colorSpace = info.colorSpace {
                        InfoRow(label: "Color Space", value: colorSpace)
                    }
                    if let depth = info.depth {
                        InfoRow(label: "Bit Depth", value: depth)
                    }
                }
            }
            
            // Path info
            InfoSection(title: "Location") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Path")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text(info.path)
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                        .lineLimit(3)
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct InfoSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 6) {
                content
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.background.secondary)
            }
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)
            
            Text(value)
                .font(.system(size: 12))
                .textSelection(.enabled)
            
            Spacer()
        }
    }
}

#Preview {
    FileInfoView(file: {
        let file = FileItem(
            path: "/test/video.mp4",
            name: "video.mp4",
            type: .video,
            selectedFormat: "mp4",
            availableFormats: ["mp4", "webm"]
        )
        file.status = .completed
        file.outputPath = "/test/video_output.webm"
        return file
    }())
}
