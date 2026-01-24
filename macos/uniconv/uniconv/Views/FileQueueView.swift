//
//  FileQueueView.swift
//  UniConv
//
//  A native macOS Tahoe file queue with Liquid Glass effects
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
            // Header with actions
            HStack(spacing: 12) {
                if !pendingFiles.isEmpty {
                    Button(action: convertAll) {
                        Label("Convert All", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }
                
                if hasFinished {
                    Button(action: clearCompleted) {
                        Label("Clear Done", systemImage: "xmark.circle")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
                .padding(.horizontal, 16)
            
            // File list
            LazyVStack(spacing: 8) {
                ForEach(files) { file in
                    FileRowView(file: file, onRemove: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            removeFile(file)
                        }
                    }, onRetry: {
                        retryConversion(file)
                    }, onCancel: {
                        cancelConversion(file)
                    })
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.9).combined(with: .opacity),
                        removal: .scale(scale: 0.9).combined(with: .opacity)
                    ))
                }
            }
            .padding(16)
        }
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.background.secondary)
        }
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }
    
    private func convertAll() {
        for file in pendingFiles {
            Task {
                await conversionManager.startConversion(for: file)
            }
        }
    }
    
    private func clearCompleted() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            files.removeAll { file in
                file.status == .completed || file.status == .cancelled || file.status == .error
            }
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
    
    @State private var isHovering = false
    @State private var showOptionsSheet = false
    @State private var showLogSheet = false
    
    var body: some View {
        HStack(spacing: 12) {
            // File type icon with background
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(iconBackgroundColor)
                    .frame(width: 36, height: 36)
                
                Image(systemName: FormatUtils.getFileTypeIcon(file.type))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(iconColor)
                    .symbolEffect(.pulse, isActive: file.status == .converting)
            }
            
            // File info
            VStack(alignment: .leading, spacing: 4) {
                Text(file.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                statusView
            }
            
            Spacer(minLength: 8)
            
            // Format selector or status indicator
            if file.status == .pending || file.status == .error {
                FormatSelector(file: file)
                
                // Options button
                Button(action: {
                    showOptionsSheet = true
                }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Conversion options")
            }
            
            // Action buttons
            actionButtons
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isHovering ? Color.secondary.opacity(0.1) : Color.clear)
        }
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .sheet(isPresented: $showOptionsSheet) {
            ConversionOptionsView(file: file)
        }
        .sheet(isPresented: $showLogSheet) {
            ConversionLogView(file: file)
        }
    }
    
    @ViewBuilder
    private var statusView: some View {
        switch file.status {
        case .converting:
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: file.progress, total: 100)
                    .progressViewStyle(.linear)
                    .tint(Color.accentColor)
                
                Text(progressText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        case .error:
            Label(file.error ?? "Unknown error", systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundStyle(.red)
                .lineLimit(1)
        case .completed:
            Label("Completed", systemImage: "checkmark.circle.fill")
                .font(.system(size: 11))
                .foregroundStyle(.green)
        case .cancelled:
            Label("Cancelled", systemImage: "xmark.circle.fill")
                .font(.system(size: 11))
                .foregroundStyle(.orange)
        case .pending:
            Text("Ready to convert")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }
    
    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 4) {
            switch file.status {
            case .pending:
                Button(action: {
                    Task {
                        await ConversionManager.shared.startConversion(for: file)
                    }
                }) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 22))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.tint)
                }
                .buttonStyle(.plain)
                .help("Start conversion")
                
            case .converting:
                Button(action: onCancel) {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 22))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
                .help("Cancel conversion")
                
            case .error:
                Button(action: onRetry) {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .font(.system(size: 22))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.tint)
                }
                .buttonStyle(.plain)
                .help("Retry conversion")
                
            case .completed, .cancelled:
                EmptyView()
            }
            
            // Log viewer button (show for converting, error, and completed states)
            if file.status == .converting || file.status == .error || file.status == .completed {
                Button(action: {
                    showLogSheet = true
                }) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 18))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("View conversion log")
            }
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(isHovering || file.status == .completed || file.status == .cancelled || file.status == .error ? 1 : 0.5)
            .help("Remove")
        }
    }
    
    private var iconBackgroundColor: Color {
        switch file.type {
        case .video: return .purple.opacity(0.15)
        case .audio: return .pink.opacity(0.15)
        case .image: return .blue.opacity(0.15)
        case .unknown: return .gray.opacity(0.15)
        }
    }
    
    private var iconColor: Color {
        switch file.type {
        case .video: return .purple
        case .audio: return .pink
        case .image: return .blue
        case .unknown: return .gray
        }
    }
    
    private var progressText: String {
        var parts: [String] = ["\(Int(file.progress))%"]
        
        if let speed = file.speed, speed > 0, speed.isFinite {
            parts.append("\(String(format: "%.1f", speed))×")
        }
        
        if let eta = formatEta(file.etaSeconds) {
            parts.append(eta)
        }
        
        return parts.joined(separator: " · ")
    }
    
    private func formatEta(_ seconds: Double?) -> String? {
        guard let seconds = seconds, seconds > 0, seconds.isFinite else { return nil }
        
        if seconds < 60 {
            return "\(Int(seconds))s left"
        } else if seconds < 3600 {
            let mins = Int(seconds / 60)
            let secs = Int(seconds.truncatingRemainder(dividingBy: 60))
            return "\(mins)m \(secs)s left"
        } else {
            let hours = Int(seconds / 3600)
            let mins = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(hours)h \(mins)m left"
        }
    }
}

