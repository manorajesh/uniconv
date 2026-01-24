//
//  FileQueueView.swift
//  UniConv
//
//  Created on 1/22/2026.
//

import SwiftUI

struct FileQueueView: View {
    @Binding var files: [FileItem]
    @StateObject private var conversionManager = ConversionManager.shared
    
    private var pendingFiles: [FileItem] {
        files.filter { $0.status == .pending }
    }
    
    private var hasFinished: Bool {
        files.contains { $0.status == .completed || $0.status == .cancelled || $0.status == .error }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("\(files.count) \(files.count == 1 ? "file" : "files")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if !pendingFiles.isEmpty {
                    Button("Convert All") {
                        convertAll()
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                if hasFinished {
                    Button("Clear Completed") {
                        clearCompleted()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .background(.regularMaterial)
            
            Divider()
                .overlay(Color.white.opacity(0.1))
            
            // File list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(files) { file in
                        FileRowView(file: file, onRemove: {
                            removeFile(file)
                        }, onRetry: {
                            retryConversion(file)
                        }, onCancel: {
                            cancelConversion(file)
                        })
                        
                        Divider()
                    }
                }
            }
        }
        .background(.thickMaterial)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.linearGradient(
                    colors: [Color.white.opacity(0.3), Color.white.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 10, y: 5)
    }
    
    private func convertAll() {
        for file in pendingFiles {
            Task {
                await conversionManager.startConversion(for: file)
            }
        }
    }
    
    private func clearCompleted() {
        files.removeAll { file in
            file.status == .completed || file.status == .cancelled || file.status == .error
        }
    }
    
    private func removeFile(_ file: FileItem) {
        if file.status == .converting {
            conversionManager.cancelConversion(for: file.id)
        }
        files.removeAll { $0.id == file.id }
    }
    
    private func retryConversion(_ file: FileItem) {
        Task {
            await conversionManager.startConversion(for: file)
        }
    }
    
    private func cancelConversion(_ file: FileItem) {
        conversionManager.cancelConversion(for: file.id)
        file.status = .cancelled
    }
}

struct FileRowView: View {
    @ObservedObject var file: FileItem
    let onRemove: () -> Void
    let onRetry: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // File type icon
            Image(systemName: FormatUtils.getFileTypeIcon(file.type))
                .font(.system(size: 18))
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            // File info
            VStack(alignment: .leading, spacing: 4) {
                Text(file.name)
                    .font(.system(size: 13))
                    .lineLimit(1)
                
                if file.status == .converting {
                    HStack(spacing: 8) {
                        ProgressBarView(progress: file.progress)
                            .frame(height: 6)
                        
                        Text(progressText)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                } else if file.status == .error {
                    Text(file.error ?? "Unknown error")
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                        .lineLimit(1)
                } else if file.status == .completed {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Completed")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                } else if file.status == .cancelled {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.orange)
                        Text("Cancelled")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Format selector
            if file.status == .pending || file.status == .error {
                FormatSelector(file: file)
            }
            
            // Action buttons
            HStack(spacing: 8) {
                if file.status == .pending {
                    Button(action: {
                        Task {
                            await ConversionManager.shared.startConversion(for: file)
                        }
                    }) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.borderless)
                    .help("Start conversion")
                } else if file.status == .converting {
                    Button(action: onCancel) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.borderless)
                    .help("Cancel conversion")
                } else if file.status == .error {
                    Button(action: onRetry) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.borderless)
                    .help("Retry conversion")
                }
                
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
                .help("Remove")
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial.opacity(0.3))
        )
        .padding(.horizontal, 1)
    }
    
    private var progressText: String {
        var parts: [String] = []
        
        // Percentage
        parts.append("\(Int(file.progress))%")
        
        // Speed
        if let speed = file.speed, speed > 0, speed.isFinite {
            parts.append("\(String(format: "%.1f", speed))x speed")
        }
        
        // ETA
        if let eta = formatEta(file.etaSeconds) {
            parts.append(eta)
        }
        
        return parts.joined(separator: " · ")
    }
    
    private func formatEta(_ seconds: Double?) -> String? {
        guard let seconds = seconds, seconds > 0, seconds.isFinite else {
            return nil
        }
        
        if seconds < 60 {
            return "\(Int(seconds))s remaining"
        } else if seconds < 3600 {
            let mins = Int(seconds / 60)
            let secs = Int(seconds.truncatingRemainder(dividingBy: 60))
            return "\(mins)m \(secs)s remaining"
        } else {
            let hours = Int(seconds / 3600)
            let mins = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(hours)h \(mins)m remaining"
        }
    }
}
